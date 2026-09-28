"""remo_lerp.py: build the Demon's Souls cutscene-track interpolation cave (calloc at 0x614e30) and print patch lines."""
import struct, capstone

def D(op, rt, ra, d):  return (op << 26) | (rt << 21) | (ra << 16) | (d & 0xffff)
def DS(op, rt, ra, d, xo): return (op << 26) | (rt << 21) | (ra << 16) | (d & 0xfffc) | xo
def X(op, rt, ra, rb, xo, rc=0): return (op << 26) | (rt << 21) | (ra << 16) | (rb << 11) | (xo << 1) | rc
def A(op, frt, fra, frb, frc, xo): return (op << 26) | (frt << 21) | (fra << 16) | (frb << 11) | (frc << 6) | (xo << 1)

stdu = lambda rs, d, ra: DS(62, rs, ra, d, 1)
std  = lambda rs, d, ra: DS(62, rs, ra, d, 0)
ld   = lambda rt, d, ra: DS(58, rt, ra, d, 0)
lwz  = lambda rt, d, ra: D(32, rt, ra, d)
stw  = lambda rs, d, ra: D(36, rs, ra, d)
lfs  = lambda ft, d, ra: D(48, ft, ra, d)
stfs = lambda fs, d, ra: D(52, fs, ra, d)
lfd  = lambda ft, d, ra: D(50, ft, ra, d)
stfd = lambda fs, d, ra: D(54, fs, ra, d)
addi = lambda rt, ra, si: D(14, rt, ra, si)
lis  = lambda rt, si: D(15, rt, 0, si)
ori  = lambda ra, rs, ui: D(24, rs, ra, ui)
li   = lambda rt, si: D(14, rt, 0, si)
fmuls = lambda ft, fa, fc: A(59, ft, fa, 0, fc, 25)
fsubs = lambda ft, fa, fb: A(59, ft, fa, fb, 0, 20)
fadds = lambda ft, fa, fb: A(59, ft, fa, fb, 0, 21)
fdivs = lambda ft, fa, fb: A(59, ft, fa, fb, 0, 18)
fmadds = lambda ft, fa, fc, fb: A(59, ft, fa, fb, fc, 29)
fctiwz = lambda ft, fb: X(63, ft, 0, fb, 15)
fcfid = lambda ft, fb: X(63, ft, 0, fb, 846)
frsp = lambda ft, fb: X(63, ft, 0, fb, 12)
extsw = lambda ra, rs: X(31, rs, ra, 0, 986)
mtctr = lambda rs: (31 << 26) | (rs << 21) | (0x120 << 11) | (467 << 1)
bctrl = lambda: 0x4e800421
def bdnz(off): return (16 << 26) | (16 << 21) | (off & 0xfffc)

TARGET = 0x5f71d0
code = [
    stdu(1, -0x100, 1),
    std(3, 0x70, 1), std(4, 0x78, 1), std(5, 0x80, 1),
    lis(12, 0x41f0), stw(12, 0x88, 1), lfs(13, 0x88, 1),        # f13 = 30.0
    fmuls(0, 1, 13),                                             # f0 = t*30
    fctiwz(12, 0), stfd(12, 0x90, 1), lwz(12, 0x94, 1), extsw(12, 12),
    std(12, 0x98, 1), lfd(12, 0x98, 1), fcfid(12, 12), frsp(12, 12),  # f12 = k
    fsubs(11, 0, 12), stfs(11, 0xa0, 1),                          # frac
    lis(12, 0x3f80), stw(12, 0x88, 1), lfs(10, 0x88, 1),          # 1.0
    fadds(10, 12, 10), fdivs(10, 10, 13), stfs(10, 0xa4, 1),      # tB = (k+1)/30
    fdivs(1, 12, 13),                                             # f1 = tA = k/30
    lis(12, TARGET >> 16), ori(12, 12, TARGET & 0xffff), mtctr(12), bctrl(),   # sample A into out (r3..r5 intact)
    addi(3, 1, 0xb0), ld(4, 0x78, 1), ld(5, 0x80, 1), lfs(1, 0xa4, 1),
    lis(12, TARGET >> 16), ori(12, 12, TARGET & 0xffff), mtctr(12), bctrl(),   # sample B into r1+0xb0
    ld(9, 0x70, 1), addi(10, 1, 0xb0), lfs(13, 0xa0, 1), li(11, 16), mtctr(11),
    # loop: out[i] += (b[i] - out[i]) * frac
    lfs(0, 0, 9), lfs(12, 0, 10), fsubs(12, 12, 0), fmadds(0, 12, 13, 0), stfs(0, 0, 9),
    addi(9, 9, 4), addi(10, 10, 4), None,
    addi(1, 1, 0x100),
]
loop_start = code.index(None) - 7
code[code.index(None)] = bdnz((loop_start - code.index(None)) * 4)

md = capstone.Cs(capstone.CS_ARCH_PPC, capstone.CS_MODE_64 | capstone.CS_MODE_BIG_ENDIAN)
base = 0x10000000
blob = b''.join(struct.pack('>I', w) for w in code)
for ins in md.disasm(blob, base):
    print('%08x: %08x  %s %s' % (ins.address, struct.unpack('>I', ins.bytes)[0], ins.mnemonic, ins.op_str))
print('count', len(code))
with open('remo_lerp.yml.txt', 'w') as f:
    f.write('      - [ calloc, 0x00614e30, %d ]\n' % len(code))
    for ins in md.disasm(blob, base):
        f.write('      - [ be32, 0x0, 0x%08x ] # %s %s\n' % (struct.unpack('>I', ins.bytes)[0], ins.mnemonic, ins.op_str))
