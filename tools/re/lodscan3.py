import struct
from ps3elf import Elf
e = Elf('elf/BCUS98114-0100.elf')
v, fs, ms, o, f = e.text
code = e.d[o:o + fs]; n = len(code) // 4
W = struct.unpack('>%dI' % n, code[:n * 4])
op = lambda w: w >> 26; rD = lambda w: (w >> 21) & 31; rA = lambda w: (w >> 16) & 31
def d16(w):
    d = w & 0xffff
    return d - 0x10000 if d >= 0x8000 else d
hits = []
for i, w in enumerate(W):
    if op(w) == 32 and d16(w) == 0x84 and rA(w) != 1:
        rd = rD(w); how = None
        for j in range(i + 1, min(n, i + 9)):
            x = W[j]
            if op(x) == 29 and rA(x) == rd and (x & 0xffff) == 0x8000: how = 'andis'
            elif op(x) == 21 and rA(x) == rd:
                sh = (x >> 11) & 31; mb = (x >> 6) & 31; me = (x >> 1) & 31
                if (sh == 1 and mb == 31 and me == 31) or (mb == 0 and me == 0): how = 'rlwinm'
            elif op(x) == 30 and rA(x) == rd and ((x >> 11) & 31) == 1 and ((x >> 1) & 1) == 1: how = 'rldicl'
            elif op(x) == 11 and rA(x) == rd and (x & 0xffff) == 0 and j + 1 < n:
                b = W[j + 1]
                if op(b) == 16 and ((b >> 16) & 31) % 4 == 0 and ((b >> 21) & 31) in (12, 4): how = 'cmpwi+blt/bge'  # BI lt bit
            if how: hits.append((i, j, how)); break
print(len(hits), 'candidates')
for i, j, how in hits:
    va = v + i * 4
    near80 = any(op(W[k]) == 32 and d16(W[k]) == 0x80 and rA(W[k]) == rA(W[i]) for k in range(max(0, i - 16), min(n, i + 16)))
    print('%08x %-14s +0x80 same base nearby: %s' % (va, how, near80))
