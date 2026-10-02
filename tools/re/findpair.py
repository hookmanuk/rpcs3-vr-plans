"""findpair.py A B [WIN] [RANGES]: live memory (pine): f32 |A| with |B| within WIN bytes after (default 64), either sign."""
import sys, struct, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from pine import Pine
a, b = abs(float(sys.argv[1])), abs(float(sys.argv[2]))
win = int(sys.argv[3]) // 4 if len(sys.argv) > 3 else 16
ranges = [(0x10000, 0x10000000), (0x20000000, 0x40000000), (0xd0000000, 0xd0100000)]
if len(sys.argv) > 4:
    ranges = [tuple(int(x, 16) for x in r.split('-')) for r in sys.argv[4].split(',')]
p = Pine(); CH = 0x100000; hits = 0; na = 0
for lo, hi in ranges:
    for base in range(lo, hi, CH):
        data, missing = p.dump(base, CH)
        if len(missing) * 4096 >= CH: continue
        n = len(data) // 4
        f = struct.unpack('>%df' % n, data[:n * 4])
        for i in range(n):
            if abs(abs(f[i]) - a) < 1e-3 * a:
                na += 1
                for j in range(i + 1, min(n, i + win + 1)):
                    if abs(abs(f[j]) - b) < 1e-3 * b:
                        hits += 1
                        if hits <= 40: print('%08x +%d:' % (base + i * 4, (j - i) * 4), ' '.join('%.4g' % x for x in f[i:i + 16]))
                        break
print('A matches', na, 'pairs', hits)
