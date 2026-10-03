"""memberstores.py ELF OFFSET [SIZE]: code storing to [reg + OFFSET .. OFFSET + SIZE) (default a 4x4 matrix, 0x40 bytes):
stfs/stw with those displacements, or stvx through an li/addi of those offsets, from one base register within 64 instructions.
Prints the sites with the share of the member written and the function start."""
import sys, struct
from ps3elf import Elf

e = Elf(sys.argv[1])
OFF = int(sys.argv[2], 16)
SIZE = int(sys.argv[3], 16) if len(sys.argv) > 3 else 0x40
va, filesz, memsz, foff, flags = e.text
n = filesz // 4
W = struct.unpack('>%dI' % n, e.d[foff:foff + n * 4])
hits = {}
for i, w in enumerate(W):
    op = w >> 26
    ra = (w >> 16) & 31
    d = w & 0xffff
    if op in (52, 36) and OFF <= d < OFF + SIZE:  # stfs, stw
        hits.setdefault((i // 64, ra), set()).add(d)
    elif op == 31 and ((w >> 1) & 0x3ff) in (231, 487):  # stvx, stvxl
        rb = (w >> 11) & 31
        ra_ = (w >> 16) & 31
        for j in range(max(0, i - 24), i):
            w2 = W[j]
            if (w2 >> 26) == 14 and ((w2 >> 21) & 31) in (rb, ra_):  # li/addi
                imm = w2 & 0xffff
                if OFF <= imm < OFF + SIZE and (imm - OFF) % 16 == 0:
                    for k in range(4):
                        hits.setdefault((i // 64, -1), set()).add(imm + 4 * k)
res = []
for (blk, ra), ds in hits.items():
    if len(ds) >= SIZE // 4 * 3 // 4:
        a = va + blk * 64 * 4
        res.append((a, ra, len(ds)))
for a, ra, k in sorted(res):
    print('0x%08x %s %d/%d  func 0x%08x' % (a, 'vmx' if ra < 0 else 'r%d' % ra, k, SIZE // 4, e.func_start(a + 0x80) or 0))
