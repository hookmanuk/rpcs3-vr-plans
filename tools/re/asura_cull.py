"""asura_cull.py [--poke]: Asura's Wrath (BLUS30721) culling patch: the words, checked with capstone.

The scene view constructor calls GetViewFrustumBounds(ViewFrustum = view + 0x380, ViewProjectionMatrix = view + 0x270,
FALSE) at 0x662aec (the function at 0x1048a0, DELTA^2 at 0x104894 before it; other callers build light and shadow
frustums). The call goes to a cave instead, written over the radial blur function 0x679ff8, whose only caller
0x67a908 is a nop (as the community "Disable Motion Blur" patch does). The cave passes a copy of the matrix whose
clip x and y columns are scaled by s = min(1, T / Px) (Px = |column 0|, the projection's x scale), so the side planes
open to at least 2 atan(1 / T); T = 0 puts them on the camera plane: everything ahead. Rendering, level of detail and
the near and far planes keep the game's matrix. T is the patch's configurable value "Culling".
Prints patch lines, or with --poke [T] a RPCS3_VR_POKE file (PPU interpreter)."""
import sys, struct
import capstone

CALL = 0x662aec
GVFB = 0x1048a0
CAVE = 0x679ff8
RADIAL_BLUR_CALL = 0x67a908


def D(op, rt, ra, d):
    return (op << 26) | (rt << 21) | (ra << 16) | (d & 0xffff)


def A(op, frt, fra, frb, frc, xo):
    return (op << 26) | (frt << 21) | (fra << 16) | (frb << 11) | (frc << 6) | (xo << 1)


lfs = lambda ft, d, ra: D(48, ft, ra, d)
stfs = lambda fs, d, ra: D(52, fs, ra, d)
lwz = lambda rt, d, ra: D(32, rt, ra, d)
stw = lambda rs, d, ra: D(36, rs, ra, d)
addi = lambda rt, ra, imm: D(14, rt, ra, imm)
lis = lambda rt, imm: D(15, rt, 0, imm)
stdu = lambda rs, d, ra: (62 << 26) | (rs << 21) | (ra << 16) | (d & 0xfffc) | 1
std = lambda rs, d, ra: (62 << 26) | (rs << 21) | (ra << 16) | (d & 0xfffc)
ld = lambda rt, d, ra: (58 << 26) | (rt << 21) | (ra << 16) | (d & 0xfffc)
mflr = lambda rt: (31 << 26) | (rt << 21) | (8 << 16) | (339 << 1)
mtlr = lambda rs: (31 << 26) | (rs << 21) | (8 << 16) | (467 << 1)
blr = 0x4e800020
fmuls = lambda t, a, c: A(59, t, a, 0, c, 25)
fmadds = lambda t, a, c, b: A(59, t, a, b, c, 29)
fsubs = lambda t, a, b: A(59, t, a, b, 0, 20)
fmul = lambda t, a, c: A(63, t, a, 0, c, 25)
fsel = lambda t, a, c, b: A(63, t, a, b, c, 23)
frsqrte = lambda t, b: A(63, t, 0, b, 0, 26)
frsp = lambda t, b: (63 << 26) | (t << 21) | (b << 11) | (12 << 1)
bl = lambda frm, to: (18 << 26) | ((to - frm) & 0x3fffffc) | 1
f32bits = lambda x: struct.unpack('>I', struct.pack('>f', x))[0]

FRAME = 0xb0
BUF = 0x70  # the matrix copy, after the frame header and parameter save area


def cave_words(data_addr):
    hi = (data_addr + 0x8000) >> 16
    lo = data_addr - (hi << 16)
    code = [
        stdu(1, -FRAME, 1),
        mflr(0),
        std(0, FRAME + 0x10, 1),
        lis(11, hi),
        lfs(5, lo, 11),             # T
        lfs(7, lo + 4, 11),         # 1.0
        lfs(0, 0x00, 4),            # column 0 of rows 0..2
        lfs(1, 0x10, 4),
        lfs(2, 0x20, 4),
        fmuls(3, 0, 0),
        fmadds(3, 1, 1, 3),
        fmadds(3, 2, 2, 3),         # Px^2
        frsqrte(4, 3),              # ~1 / Px
        fmul(6, 5, 4),              # T / Px
        frsp(6, 6),
        fsubs(8, 6, 7),
        fsel(6, 8, 7, 6),           # s = min(T / Px, 1)
    ]
    for r in range(4):
        o = r * 16
        code += [
            lfs(0, o + 0, 4), fmuls(0, 0, 6), stfs(0, BUF + o + 0, 1),
            lfs(0, o + 4, 4), fmuls(0, 0, 6), stfs(0, BUF + o + 4, 1),
            lwz(0, o + 8, 4), stw(0, BUF + o + 8, 1),
            lwz(0, o + 12, 4), stw(0, BUF + o + 12, 1),
        ]
    code += [addi(4, 1, BUF)]
    code += [bl(CAVE + len(code) * 4, GVFB)]  # GetViewFrustumBounds(r3 = ViewFrustum, r4 = the copy, r5 = FALSE)
    code += [ld(0, FRAME + 0x10, 1), mtlr(0), addi(1, 1, FRAME), blr]
    return code


n_code = len(cave_words(0))
DATA = CAVE + n_code * 4
code = cave_words(DATA)
assert len(code) == n_code
T = 0.0
if '--poke' in sys.argv and len(sys.argv) > sys.argv.index('--poke') + 1:
    T = float(sys.argv[sys.argv.index('--poke') + 1])
words = [(RADIAL_BLUR_CALL, 0x60000000, 'radial blur call: nop (as "Disable Motion Blur"); its function becomes the cave')]
words += [(CAVE + i * 4, w, None) for i, w in enumerate(code)]
words += [(DATA, f32bits(T), 'data: T ("Culling")'), (DATA + 4, f32bits(1.0), 'data: 1.0')]
words += [(CALL, bl(CALL, CAVE), 'scene view: GetViewFrustumBounds through the cave')]
assert DATA + 8 <= 0x67a51c

md = capstone.Cs(capstone.CS_ARCH_PPC, capstone.CS_MODE_64 | capstone.CS_MODE_BIG_ENDIAN)
for a, w, note in words:
    ins = list(md.disasm(struct.pack('>I', w), a))
    text = ins[0].mnemonic + ' ' + ins[0].op_str if ins else '?'
    if '--poke' in sys.argv:
        print('%x u32 0x%08x' % (a, w))
    elif a == DATA:
        print('      - [ bef32, 0x%08x, "Culling" ] # %s' % (a, note))
    else:
        print('      - [ be32, 0x%08x, 0x%08x ] # %s%s' % (a, w, text, ' (' + note + ')' if note else ''))
