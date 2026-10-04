"""findproj2.py: scan live guest memory (pine) for 4x4 perspective projections (row or column major) and print
address, the diagonal terms and the vertical FOV in degrees."""
import sys, struct, os, math
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from pine import Pine
p = Pine(); CH = 0x100000
ranges = [(0x10000, 0x10000000), (0x10000000, 0x20000000), (0x20000000, 0x40000000), (0xc0000000, 0xd0000000)]
z = lambda x: abs(x) < 1e-6
for lo, hi in ranges:
    for base in range(lo, hi, CH):
        data, missing = p.dump(base, CH)
        if len(missing) * 4096 >= CH: continue
        n = len(data) // 4; f = struct.unpack('>%df' % n, data[:n * 4])
        for i in range(0, n - 16):
            a, b = f[i], f[i + 5]
            if not (0.2 < a < 10 and 0.2 < b < 10): continue
            m = f[i:i + 16]
            if not all(z(m[k]) for k in (1, 2, 3, 4, 6, 7, 8, 9, 12, 13, 15)): continue
            if not (abs(abs(m[11]) - 1) < 1e-4 or abs(abs(m[14]) - 1) < 1e-4): continue
            print(hex(base + i * 4), 'sx %.4f sy %.4f ratio %.4f fovy %.2f' % (a, b, a / b, math.degrees(2 * math.atan(1 / b))), ['%.4g' % x for x in (m[10], m[11], m[14])])
