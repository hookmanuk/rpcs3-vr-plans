"""absrange.py ELF LO HI [--gaps N]: every absolute address in [LO, HI) that code builds from lis rX,hi plus a
D-form displacement (loads, stores, addi, addic, ori), with the number of sites; --gaps N lists the gaps of at least N
bytes between referenced addresses instead. One forward pass: a lis value lives until its register is overwritten
or 64 instructions pass. Heuristic: catches the usual compiler patterns, not pointers kept in structs."""
import sys, struct, collections
from ps3elf import Elf

e = Elf(sys.argv[1])
lo, hi = int(sys.argv[2], 16), int(sys.argv[3], 16)
gaps = int(sys.argv[sys.argv.index('--gaps') + 1], 16) if '--gaps' in sys.argv else 0
v, fs, ms, o, f = e.text
n = fs // 4
W = struct.unpack('>%dI' % n, e.d[o:o + n * 4])
STORES = (36, 37, 38, 39, 44, 45, 52, 53, 54, 55, 62)
MEM = (32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 48, 49, 50, 51, 52, 53, 54, 55, 58, 62)
refs = collections.Counter()
live = {}  # register -> (hi << 16, index)
for i, w in enumerate(W):
    op = w >> 26
    rt = (w >> 21) & 31
    ra = (w >> 16) & 31
    if op == 15 and ra == 0:  # lis
        live[rt] = ((w & 0xffff) << 16, i)
        continue
    base = ra if op != 24 else rt  # ori: rA = rS | imm, source is rS
    if op in MEM or op in (12, 13, 14, 24):
        entry = live.get(base)
        if entry and i - entry[1] <= 64 and base != 0:
            d = w & 0xffff
            if op != 24 and d >= 0x8000:
                d -= 0x10000
            a = (entry[0] + d) & 0xffffffff
            if lo <= a < hi:
                refs[a] += 1
    # Invalidate the register this instruction writes (approximate: rT for most forms, rA for ori/andi/rlw*).
    written = None
    if op in (24, 25, 26, 27, 28, 29, 20, 21, 23):
        written = ra
    elif op not in STORES and op not in (16, 17, 18, 19, 10, 11, 31, 63, 59, 4):
        written = rt
    elif op == 31:
        written = rt if ((w >> 1) & 0x3ff) not in (151, 183, 215, 247, 407, 439, 663, 695, 727, 759, 983, 149, 181, 150, 214) else None
    if written is not None and written in live and not (op == 15 and ra == 0):
        del live[written]

addrs = sorted(refs)
if gaps:
    for a, b in sorted(zip(addrs, addrs[1:]), key=lambda g: g[1] - g[0], reverse=True):
        if b - a < gaps:
            break
        print('%08x .. %08x  gap %x' % (a, b, b - a))
else:
    for a in addrs:
        print('%08x %d' % (a, refs[a]))
