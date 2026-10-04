"""findvals.py V1 [V2 ...]: live memory (pine): every f32 within 2e-4 relative of each value, per range summary + first hits."""
import sys, struct, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from pine import Pine
vals = [float(x) for x in sys.argv[1:]]
ranges = [(0x10000, 0x10000000), (0x10000000, 0x19000000), (0x20000000, 0x40000000)]
p = Pine(); CH = 0x100000
hits = {v: [] for v in vals}
for lo, hi in ranges:
    for base in range(lo, hi, CH):
        data, missing = p.dump(base, CH)
        if len(missing) * 4096 >= CH: continue
        n = len(data) // 4
        f = struct.unpack('>%df' % n, data[:n * 4])
        for i in range(n):
            x = f[i]
            for v in vals:
                if abs(x - v) < 2e-4 * abs(v):
                    hits[v].append(base + i * 4)
for v in vals:
    print('%.6g: %d hits' % (v, len(hits[v])), ' '.join('%08x' % a for a in hits[v][:30]))
