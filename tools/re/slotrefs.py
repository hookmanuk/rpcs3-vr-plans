"""slotrefs.py SLOT...: code that loads a module pointer slot via lwz rB,d(r2) ; lwz rX,d2(rB)."""
import sys, struct
from ps3elf import Elf
e = Elf('elf/BLUS30443.elf')
targets = {int(a, 16) for a in sys.argv[1:]}
va, fs, ms, off, fl = e.text
d = e.d[off:off + fs]
n = len(d) // 4
W = struct.unpack('>%dI' % n, d[:n * 4])
out = set()
for i in range(n):
    w = W[i]
    if (w >> 26) == 32 and ((w >> 16) & 31) == 2:
        disp = w & 0xffff; disp = disp - 0x10000 if disp & 0x8000 else disp
        try: b = e.u32(e.toc + disp)
        except Exception: continue
        rt = (w >> 21) & 31
        for k in range(1, 800):
            if i + k >= n: break
            w2 = W[i + k]
            if w2 == 0x4e800020: break
            if ((w2 >> 16) & 31) == rt and (w2 >> 26) in (32, 14):
                dd = w2 & 0xffff; dd = dd - 0x10000 if dd & 0x8000 else dd
                if b + dd in targets:
                    a = va + 4 * (i + k)
                    out.add((e.func_start(a) or 0, a, b + dd))
for f, a, t in sorted(out):
    print('func %x  at %x  slot %x' % (f, a, t))
