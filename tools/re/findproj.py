"""findproj.py SX SY [RANGES]: search live PS3 memory (pine) for a projection matrix: f32 SX followed by SY at a
matrix-diagonal distance (row-major 4x4: +20 bytes; also +16, +24 for 3x4/padded forms). Prints each address,
the 16 floats from it, and the gap. Default ranges: main memory 0x00010000-0x10000000 and 0x30000000-0x40000000."""
import sys, struct
sys.path.insert(0, __import__('os').path.join(__import__('os').path.dirname(__file__), '..'))
from pine import Pine
sx, sy = float(sys.argv[1]), float(sys.argv[2])
ranges = [(0x10000, 0x10000000), (0x30000000, 0x40000000)]
if len(sys.argv) > 3:
    ranges = [tuple(int(x, 16) for x in r.split('-')) for r in sys.argv[3].split(',')]
p = Pine()
CH = 0x100000
hits = 0
for lo, hi in ranges:
    for base in range(lo, hi, CH):
        data, missing = p.dump(base, CH)
        if len(missing) * 4096 >= CH:
            continue
        n = len(data) // 4
        f = struct.unpack('>%df' % n, data[:n * 4])
        for i in range(n):
            if abs(f[i] - sx) < 1e-3 * abs(sx):
                for gap in (5, 4, 6):
                    j = i + gap
                    if j < n and abs(f[j] - sy) < 1e-3 * abs(sy):
                        hits += 1
                        print('%08x gap %d:' % (base + i * 4, gap * 4), ' '.join('%.4g' % x for x in f[i:i + 16]))
print('hits', hits)
