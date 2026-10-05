"""ppcdis.py ELF START END: capstone PPC64 BE disassembly of an executable dump (vaddr range, hex)."""
import struct, sys, capstone
d = open(sys.argv[1], 'rb').read()
ph, n, sz = struct.unpack('>Q', d[0x20:0x28])[0], struct.unpack('>H', d[0x38:0x3a])[0], struct.unpack('>H', d[0x36:0x38])[0]
segs = []
for i in range(n):
    t, f, off, va, pa, fs, ms = struct.unpack('>IIQQQQQ', d[ph + i * sz:ph + i * sz + 48])
    if t == 1: segs.append((va, off, fs))
a, b = int(sys.argv[2], 16), int(sys.argv[3], 16)
for va, off, fs in segs:
    if va <= a < va + fs:
        md = capstone.Cs(capstone.CS_ARCH_PPC, capstone.CS_MODE_64 | capstone.CS_MODE_BIG_ENDIAN)
        for ins in md.disasm(d[off + a - va:off + b - va], a):
            print(f'{ins.address:08x}: {ins.bytes.hex()}  {ins.mnemonic} {ins.op_str}')
