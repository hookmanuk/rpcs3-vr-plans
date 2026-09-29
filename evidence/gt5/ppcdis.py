import sys
from capstone import *
base=0x10000
data=open('mem_a.bin','rb')
def dis(addr,n):
    data.seek(addr-base); code=data.read(n*4)
    md=Cs(CS_ARCH_PPC,CS_MODE_64|CS_MODE_BIG_ENDIAN)
    for i in md.disasm(code,addr): print(hex(i.address),i.mnemonic,i.op_str)
if __name__=='__main__': dis(int(sys.argv[1],16),int(sys.argv[2]))
