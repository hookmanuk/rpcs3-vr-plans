"""callers.py ELF TARGET...: every `bl`/`b` (relative branch) in the executable's code to each target address (hex)."""
import sys, struct
from ps3elf import Elf
e = Elf(sys.argv[1])
targets = {int(a, 16) for a in sys.argv[2:]}
va, fs, ms, off, fl = e.text
data = e.d[off:off + fs]
for i in range(0, len(data) - 3, 4):
    w = struct.unpack_from('>I', data, i)[0]
    if (w >> 26) != 18:
        continue
    li = w & 0x03fffffc
    if li & 0x02000000:
        li -= 0x04000000
    pc = va + i
    t = li if (w & 2) else pc + li
    if t in targets:
        print('%08x: %s 0x%x' % (pc, 'bl' if (w & 1) else 'b', t))
