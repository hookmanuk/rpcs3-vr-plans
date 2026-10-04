"""valtrack.py snap OUT V1 [V2...] | check OUT: live memory (pine). 'snap' saves every f32 address within 2e-4 relative
of each value; 'check' re-reads them and prints the ones whose value changed (address, old, new)."""
import sys, struct, os, json
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from pine import Pine
p = Pine(); CH = 0x100000
ranges = [(0x10000, 0x10000000), (0x10000000, 0x20000000), (0x20000000, 0x40000000)]
if sys.argv[1] == 'snap':
    out = sys.argv[2]; vals = [float(x) for x in sys.argv[3:]]; hits = []
    for lo, hi in ranges:
        for base in range(lo, hi, CH):
            data, missing = p.dump(base, CH)
            if len(missing) * 4096 >= CH: continue
            n = len(data) // 4; f = struct.unpack('>%df' % n, data[:n * 4])
            for i in range(n):
                for v in vals:
                    if abs(f[i] - v) < 2e-4 * abs(v): hits.append((base + i * 4, f[i]))
    json.dump(hits, open(out, 'w')); print(len(hits), 'addresses')
else:
    hits = json.load(open(sys.argv[2]))
    for a, old in hits:
        d, m = p.dump(a & ~0xfff, 0x1000)
        if m: continue
        new = struct.unpack('>f', d[a & 0xfff:(a & 0xfff) + 4])[0]
        if abs(new - old) > 1e-4 * abs(old): print('%08x %.6g -> %.6g' % (a, old, new))
