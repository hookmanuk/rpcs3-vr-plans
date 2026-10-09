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
    # pattern A: addi rX, rY, 0x70 ... lwz rD, 0x14(rX) or 0x10(rX)
    if op(w) == 14 and d16(w) == 0x70 and rA(w) != 1:
        rx = rD(w)
        for j in range(i + 1, min(n, i + 10)):
            x = W[j]
            if op(x) == 32 and rA(x) == rx and d16(x) in (0x10, 0x14):
                hits.append((i, 'A', j)); break
            if op(x) in (14, 32, 58) and rD(x) == rx: break  # rx overwritten
    # pattern B: lwz rX, 0x10(rY) ... lwz rD, 0x84(rX) (or lfs/lwz 0x80)
    if op(w) == 32 and d16(w) == 0x10 and rA(w) != 1:
        rx = rD(w)
        for j in range(i + 1, min(n, i + 10)):
            x = W[j]
            if op(x) in (32, 48) and rA(x) == rx and d16(x) in (0x80, 0x84):
                hits.append((i, 'B', j)); break
            if op(x) in (14, 32, 58, 48) and rD(x) == rx: break
print(len(hits), 'candidates')
for i, kind, j in hits:
    va = v + i * 4
    # nearby float loads / compares (lfs = 48, fcmpu = 63 with xo 0)
    near = sum(1 for k in range(max(0, i - 24), min(n, i + 40)) if op(W[k]) == 48 or (op(W[k]) == 63 and ((W[k] >> 1) & 0x3ff) == 0))
    print('%08x %s -> %08x  float ops nearby: %d' % (va, kind, v + j * 4, near))
