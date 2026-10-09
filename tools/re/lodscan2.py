import struct, sys
from ps3elf import Elf
e = Elf('elf/BCUS98114-0100.elf')
v, fs, ms, o, f = e.text
code = e.d[o:o + fs]; n = len(code) // 4
W = struct.unpack('>%dI' % n, code[:n * 4])
def op(w): return w >> 26
def rD(w): return (w >> 21) & 31
def rA(w): return (w >> 16) & 31
def d16(w):
    d = w & 0xffff
    return d - 0x10000 if d >= 0x8000 else d
hits = []
for i, w in enumerate(W):
    if op(w) == 32 and d16(w) == 0x84:   # lwz rD, 0x84(rA)
        rd = rD(w)
        # look ahead 8 instructions for a sign-bit test of rd
        for j in range(i + 1, min(n, i + 9)):
            x = W[j]
            tested = False
            if op(x) == 29 and rA(x) == rd and (x & 0xffff) == 0x8000: tested = True   # andis. rX, rd, 0x8000
            if op(x) == 11 and rA(x) == rd and (x & 0xffff) == 0: tested = True  # cmpwi rd, 0 (sign via blt/bge)
            if op(x) == 21 and rA(x) == rd:  # rlwinm from rd
                sh = (x >> 11) & 31; mb = (x >> 6) & 31; me = (x >> 1) & 31
                if (sh == 1 and mb == 31 and me == 31) or (mb == 0 and me == 0): tested = True
            if op(x) == 30 and rA(x) == rd:  # rldicl rd, sh=33, mb=63 (bit 0)
                tested = True
            if tested:
                hits.append((i, j)); break
print(len(hits), 'candidates')
for i, j in hits:
    va = v + i * 4
    # also report whether 0x80(rA) is loaded nearby
    near80 = any(op(W[k]) == 32 and d16(W[k]) == 0x80 for k in range(max(0, i - 12), min(n, i + 12)))
    print('%08x  near +0x80 load: %s' % (va, near80))
    print(e.dis(va - 16, 12))
    print()
