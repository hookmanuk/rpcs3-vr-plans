"""blockspeed.py LO HI STRIDE base... (pairs base.0/.1): speed (units/wall s) of the xyz triplet at each LO+k*STRIDE per run."""
import sys, struct, numpy as np
lo, hi, st = (int(x, 16) for x in sys.argv[1:4])
def rd(b, a, n):
    idx = np.fromfile(b + '.idx', dtype='<u4'); raw = np.memmap(b + '.bin', dtype=np.uint8, mode='r')
    p = a & ~0xffff; k = list(idx).index(p); o = k * 0x10000 + a - p
    return bytes(raw[o:o + n])
for base in sys.argv[4:]:
    t = [int(open(f'{base}.{n}.txt').read()) / 1e6 for n in (0, 1)]
    row = []
    for a in range(lo, hi, st):
        v = [struct.unpack('>3f', rd(f'{base}.{n}', a, 12)) for n in (0, 1)]
        d = sum((v[1][i] - v[0][i]) ** 2 for i in range(3)) ** 0.5 / (t[1] - t[0])
        row.append(f'{d:5.1f}')
    print(base.split('/')[-1].ljust(6), ' '.join(row))
