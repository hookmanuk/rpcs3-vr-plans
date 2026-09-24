"""Tiny PS3 PPU ELF helper: load segments, disassemble, find call sites and address references.
usage (import):  from ps3elf import Elf; e = Elf('elf/BLUS30295.elf')
"""
import struct, sys, re, os
import capstone

HERE = os.path.dirname(os.path.abspath(__file__))


class Elf:
    def __init__(self, path):
        self.path = path
        d = open(path, 'rb').read()
        self.d = d
        assert d[:4] == b'\x7fELF'
        self.entry = struct.unpack('>Q', d[0x18:0x20])[0]
        phoff = struct.unpack('>Q', d[0x20:0x28])[0]
        phentsize, phnum = struct.unpack('>HH', d[0x36:0x3a])
        self.segs = []
        for i in range(phnum):
            o = phoff + i * phentsize
            p_type, p_flags, p_offset, p_vaddr, p_paddr, p_filesz, p_memsz = struct.unpack('>IIQQQQQ', d[o:o + 48])
            if p_type == 1:
                self.segs.append((p_vaddr, p_filesz, p_memsz, p_offset, p_flags))
        self.md = capstone.Cs(capstone.CS_ARCH_PPC, capstone.CS_MODE_64 | capstone.CS_MODE_BIG_ENDIAN)
        self.md.detail = False
        # text = first executable segment
        self.text = [s for s in self.segs if s[4] & 1][0]
        # TOC from the entry descriptor (OPD)
        self.toc = self.u32(self.entry + 4)
        imp = os.path.splitext(path)[0] + '.imports'
        self.stubs = {}
        if os.path.exists(imp):
            for line in open(imp):
                m = re.search(r'\[(\w+)\] \(0x[0-9a-f]+\) -> (0x[0-9a-f]+)', line)
                if m:
                    self.stubs[int(m.group(2), 16)] = m.group(1)

    def off(self, va):
        for v, fs, ms, o, f in self.segs:
            if v <= va < v + fs:
                return o + va - v
        return None

    def read(self, va, n):
        o = self.off(va)
        return self.d[o:o + n] if o is not None else None

    def u32(self, va):
        b = self.read(va, 4)
        return struct.unpack('>I', b)[0] if b else None

    def f32(self, va):
        b = self.read(va, 4)
        return struct.unpack('>f', b)[0] if b else None

    def f64(self, va):
        b = self.read(va, 8)
        return struct.unpack('>d', b)[0] if b else None

    def dis(self, va, n=40):
        out = []
        code = self.read(va, n * 4)
        for i in range(n):
            w = code[i * 4:i * 4 + 4]
            ins = list(self.md.disasm(w, va + i * 4))
            a = va + i * 4
            if ins:
                s = f'{a:08x}: {struct.unpack(">I", w)[0]:08x}  {ins[0].mnemonic} {ins[0].op_str}'
                t = self.branch_target(struct.unpack('>I', w)[0], a)
                if t is not None and t in self.stubs:
                    s += f'    ; {self.stubs[t]}'
            else:
                s = f'{a:08x}: {struct.unpack(">I", w)[0]:08x}  .long'
            out.append(s)
        return '\n'.join(out)

    @staticmethod
    def branch_target(w, a):
        if (w >> 26) == 18:  # b/bl
            li = w & 0x03fffffc
            if li & 0x02000000:
                li -= 0x04000000
            return (li if (w & 2) else a + li) & 0xffffffff
        return None

    def words(self):
        v, fs, ms, o, f = self.text
        return v, self.d[o:o + fs]

    def calls_to(self, target):
        v, b = self.words()
        res = []
        for i in range(0, len(b) - 3, 4):
            w = struct.unpack('>I', b[i:i + 4])[0]
            if (w >> 26) == 18 and (w & 1):
                if self.branch_target(w, v + i) == target:
                    res.append(v + i)
        return res

    def stub(self, name):
        return [a for a, n in self.stubs.items() if n == name]

    def calls_to_name(self, name):
        r = []
        for s in self.stub(name):
            r += self.calls_to(s)
        return sorted(r)

    def func_start(self, va, limit=0x4000):
        """Walk back to a likely function start (after blr / before mflr/stdu prologue)."""
        a = va
        while a > va - limit:
            w = self.u32(a - 4)
            if w == 0x4e800020 or w == 0:  # blr
                return a
            a -= 4
        return None

    def toc_refs(self, target, reg_toc=2):
        """Find loads 'lwz/lfs/ld rX, d(r2)' whose TOC slot holds target, and addi rX,r2,d == target."""
        v, b = self.words()
        res = []
        for i in range(0, len(b) - 3, 4):
            w = struct.unpack('>I', b[i:i + 4])[0]
            op = w >> 26
            ra = (w >> 16) & 31
            d = w & 0xffff
            if d & 0x8000:
                d -= 0x10000
            if ra != reg_toc:
                continue
            if op == 14 and (self.toc + d) & 0xffffffff == target:  # addi rX, r2, d
                res.append((v + i, 'addi'))
            elif op in (32, 58, 48, 50):  # lwz, ld, lfs, lfd
                slot = (self.toc + d) & 0xffffffff
                if op == 32 and self.u32(slot) == target:
                    res.append((v + i, 'lwz-slot'))
                if (op in (48, 50, 32)) and slot == target:
                    res.append((v + i, 'direct'))
        return res

    def abs_refs(self, target):
        """lis rX,hi ; (addi|ori|lwz|lfs|stw ...) rY,rX,lo pairs within 8 instructions."""
        v, b = self.words()
        hi = (target + 0x8000) >> 16 & 0xffff
        hi_u = target >> 16 & 0xffff
        lo = target & 0xffff
        res = []
        n = len(b) // 4
        W = struct.unpack('>%dI' % n, b[:n * 4])
        for i in range(n):
            w = W[i]
            if (w >> 26) == 15 and ((w >> 16) & 31) == 0 and (w & 0xffff) in (hi, hi_u):
                rd = (w >> 21) & 31
                for j in range(i + 1, min(n, i + 12)):
                    w2 = W[j]
                    if ((w2 >> 16) & 31) == rd and (w2 & 0xffff) == lo and (w2 >> 26) != 15:
                        res.append(v + i)
                        break
        return res

    def find_bytes(self, pat):
        res = []
        for vv, fs, ms, o, f in self.segs:
            seg = self.d[o:o + fs]
            k = seg.find(pat)
            while k >= 0:
                res.append(vv + k)
                k = seg.find(pat, k + 1)
        return res

    def find_float(self, x):
        return self.find_bytes(struct.pack('>f', x))


if __name__ == '__main__':
    e = Elf(sys.argv[1])
    print('entry %x toc %x' % (e.entry, e.toc))
    for s in e.segs:
        print('seg %08x filesz %x memsz %x flags %x' % (s[0], s[1], s[2], s[4]))
