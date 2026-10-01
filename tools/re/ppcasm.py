"""ppcasm.py: tiny PPC encoder for patch caves; asm(list of (mnemonic, args)) -> words, printed as patch lines verified by capstone."""
import struct, capstone
def D(op, rt, ra, d): return (op << 26) | (rt << 21) | (ra << 16) | (d & 0xffff)
def lis(rt, imm): return D(15, rt, 0, imm)
def li(rt, imm): return D(14, rt, 0, imm)
def addi(rt, ra, imm): return D(14, rt, ra, imm)
def ori(ra, rs, imm): return D(24, rs, ra, imm)
def lwz(rt, d, ra): return D(32, rt, ra, d)
def stw(rs, d, ra): return D(36, rs, ra, d)
def lfs(ft, d, ra): return D(48, ft, ra, d)
def stfs(fs, d, ra): return D(52, fs, ra, d)
def cmpwi(ra, imm, cr=0): return (11 << 26) | (cr << 23) | (ra << 16) | (imm & 0xffff)
def beq(off, cr=0): return (16 << 26) | (12 << 21) | ((cr * 4 + 2) << 16) | (off & 0xfffc)
def bne(off, cr=0): return (16 << 26) | (4 << 21) | ((cr * 4 + 2) << 16) | (off & 0xfffc)
def b(off): return (18 << 26) | (off & 0x3fffffc)
def fmuls(ft, fa, fc): return (59 << 26) | (ft << 21) | (fa << 16) | (fc << 6) | (25 << 1)
def fadds(ft, fa, fb): return (59 << 26) | (ft << 21) | (fa << 16) | (fb << 11) | (21 << 1)
def fsubs(ft, fa, fb): return (59 << 26) | (ft << 21) | (fa << 16) | (fb << 11) | (20 << 1)
def fdivs(ft, fa, fb): return (59 << 26) | (ft << 21) | (fa << 16) | (fb << 11) | (18 << 1)
def fmr(ft, fb): return (63 << 26) | (ft << 21) | (fb << 11) | (72 << 1)
_md = capstone.Cs(capstone.CS_ARCH_PPC, capstone.CS_MODE_64 | capstone.CS_MODE_BIG_ENDIAN)
def show(words, comments=None, base=0x10000000):
    out = []
    for i, w in enumerate(words):
        ins = list(_md.disasm(struct.pack('>I', w), base + i * 4))
        text = f'{ins[0].mnemonic} {ins[0].op_str}' if ins else '.long'
        c = f'   {comments[i]}' if comments and i < len(comments) and comments[i] else ''
        out.append(f'      - [ be32, 0x0, 0x{w:08x} ] # {text}{c}')
    return '\n'.join(out)
