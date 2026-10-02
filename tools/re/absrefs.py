"""absrefs.py ELF ADDR [ADDR...]: code that loads/stores an absolute address built as lis rX,hi + d(rX) (or addi/ori), within
32 instructions. Prints each site with the instruction. Heuristic: catches the usual compiler pattern only."""
import sys, struct
from ps3elf import Elf
e = Elf(sys.argv[1])
targets = [int(a, 16) for a in sys.argv[2:]]
v, fs, ms, o, f = e.text
code = e.d[o:o + fs]
n = len(code) // 4
W = struct.unpack('>%dI' % n, code[:n * 4])
LS = {32: 'lwz', 33: 'lwzu', 34: 'lbz', 36: 'stw', 37: 'stwu', 38: 'stb', 40: 'lhz', 44: 'sth', 48: 'lfs', 50: 'lfd', 52: 'stfs', 54: 'stfd', 14: 'addi', 58: 'ld', 62: 'std'}
for i, w in enumerate(W):
    op = w >> 26
    if op not in LS: continue
    ra = (w >> 16) & 31
    d = w & 0xffff
    if d >= 0x8000: d -= 0x10000
    if ra == 0: continue
    for j in range(i - 1, max(-1, i - 32), -1):
        p = W[j]
        if (p >> 26) == 15 and ((p >> 21) & 31) == ra and ((p >> 16) & 31) == 0:
            a = ((p & 0xffff) << 16) + d
            a &= 0xffffffff
            if a in targets:
                print('%08x -> %08x  %s %s' % (v + i * 4, a, LS[op], e.dis(v + i * 4, 1).split('  ', 1)[1]))
            break
        if ((p >> 21) & 31) == ra and (p >> 26) not in (36, 38, 44, 52, 54, 62): break
