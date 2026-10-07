# ddis.py DUMPBASE START END: disassemble a memory dump
import sys, struct, capstone
sys.path.insert(0, r'F:/rpsc3/source/plans/tools/re')
from dmem import Dump
d = Dump(sys.argv[1]); a, b = int(sys.argv[2], 16), int(sys.argv[3], 16)
md = capstone.Cs(capstone.CS_ARCH_PPC, capstone.CS_MODE_64 | capstone.CS_MODE_BIG_ENDIAN)
for x in range(a, b, 4):
    w = d.u(x)[0]; ins = list(md.disasm(struct.pack('>I', w), x))
    print(f'{x:08x}: {w:08x}  ' + (f'{ins[0].mnemonic} {ins[0].op_str}' if ins else '?'))
