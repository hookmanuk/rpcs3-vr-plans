"""memcount.py A1 A2 B1 B2: integer counters that tick with the frame rate.
A1/A2 are two RPCS3_VR_MEMDUMP bases (<file>.<n>, with .bin/.idx/.txt) taken a few seconds apart at one frame
rate, B1/B2 the same at another rate. For every big-endian u32 that increases steadily (and modestly) in both
pairs, prints its rate in units per wall second for both runs and the ratio B/A. Frame-counted ticks show the
frame-rate ratio (90/60 = 1.5); real-time ones ~1.0. Clustered by (rate A, ratio)."""
import sys, numpy as np
from collections import Counter

def load(base):
    wall = int(open(base + '.txt').read().strip()) / 1e6
    idx = np.fromfile(base + '.idx', dtype='<u4')
    data = np.fromfile(base + '.bin', dtype='>u4')
    return wall, idx, data

def words(base):
    wall, idx, data = load(base)
    # .idx lists the mapped 64 KiB pages' addresses in .bin order
    addrs = (idx.astype(np.uint64)[:, None] + np.arange(0, 0x10000, 4, dtype=np.uint64)[None, :]).ravel()
    return wall, addrs[:data.size], data

def rates(b1, b2):
    w1, a1, d1 = words(b1); w2, a2, d2 = words(b2)
    common, i1, i2 = np.intersect1d(a1, a2, return_indices=True)
    v1 = d1[i1].astype(np.int64); v2 = d2[i2].astype(np.int64)
    dt = w2 - w1
    diff = v2 - v1
    ok = (diff > 0) & (diff < 100000 * dt) & (v1 > 0)
    return dict(zip(common[ok].tolist(), (diff[ok] / dt).tolist()))

ra = rates(sys.argv[1], sys.argv[2]); rb = rates(sys.argv[3], sys.argv[4])
both = [(addr, ra[addr], rb[addr]) for addr in ra.keys() & rb.keys() if ra[addr] >= 20]
clusters = Counter()
examples = {}
for addr, x, y in both:
    key = (round(x, -1), round(y / x, 2))
    clusters[key] += 1
    examples.setdefault(key, []).append(addr)
print(f"{len(both)} counters rising in both runs")
for (rate, ratio), n in sorted(clusters.items(), key=lambda kv: -kv[1])[:30]:
    ex = ' '.join(hex(a) for a in examples[(rate, ratio)][:4])
    print(f"  rate A {rate:8.0f}/s  ratio B/A {ratio:5.2f}  x{n:4d}  e.g. {ex}")
