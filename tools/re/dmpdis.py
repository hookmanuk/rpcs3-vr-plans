"""dmpdis.py DUMPBASE START END: disassemble guest memory from a RPCS3_VR_MEMDUMP dump; 'rd ADDR' words with -w."""
import sys, struct, numpy as np, capstone
b = sys.argv[1]; idx = np.fromfile(b + '.idx', dtype='<u4'); raw = np.memmap(b + '.bin', dtype=np.uint8, mode='r')
pm = {int(p): k for k, p in enumerate(idx)}
def mem(a, n):
    out = b''
    while n > 0:
        p = a & ~0xffff; k = pm[p]; o = a - p; c = min(n, 0x10000 - o)
        out += bytes(raw[k * 0x10000 + o:k * 0x10000 + o + c]); a += c; n -= c
    return out
s, e = int(sys.argv[2], 16), int(sys.argv[3], 16)
if len(sys.argv) > 4 and sys.argv[4] == '-w':
    d = mem(s, e - s)
    for i in range(0, len(d), 16): print(hex(s + i), ' '.join(d[i + j:i + j + 4].hex() for j in range(0, 16, 4)))
else:
    md = capstone.Cs(capstone.CS_ARCH_PPC, capstone.CS_MODE_64 | capstone.CS_MODE_BIG_ENDIAN)
    for ins in md.disasm(mem(s, e - s), s): print(f'{ins.address:08x}: {ins.bytes.hex()}  {ins.mnemonic} {ins.op_str}')
