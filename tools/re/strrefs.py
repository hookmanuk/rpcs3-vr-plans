"""strrefs.py ELF STRING [STRING...]: the virtual address of each NUL-terminated string in the ELF and every 32-bit
big-endian word in the loaded segments holding that address (pointer tables, descriptor records), with the 8 words
around each pointer. For reflection/property tables that name struct members."""
import sys, struct
from ps3elf import Elf
e = Elf(sys.argv[1])
segs = e.segs
def vaddr_of(off):
    for v, fs, ms, o, f in segs:
        if o <= off < o + fs:
            return v + off - o
    return None
for s in sys.argv[2:]:
    needle = s.encode() + b'\0'
    pos = -1
    while True:
        pos = e.d.find(needle, pos + 1)
        if pos < 0: break
        if pos and e.d[pos - 1] != 0 and not s.startswith('/'): continue  # whole string only
        va = vaddr_of(pos)
        print('"%s" at file %x -> %s' % (s, pos, ('%08x' % va) if va is not None else 'unmapped'))
        if va is None: continue
        pat = struct.pack('>I', va)
        for v, fs, ms, o, f in segs:
            data = e.d[o:o + fs]
            i = -1
            while True:
                i = data.find(pat, i + 1)
                if i < 0: break
                if i % 4: continue
                pva = v + i
                ctx = struct.unpack('>16I', data[max(0, i - 32):max(0, i - 32) + 64]) if i >= 32 and i + 32 <= len(data) else ()
                print('   ptr at %08x%s: %s' % (pva, ' (text)' if f & 1 else '', ' '.join('%08x' % w for w in ctx)))
