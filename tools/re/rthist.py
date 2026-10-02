"""rthist.py BASE OTHER [OTHER...]: for f32 xyz triplets that look like world positions in run BASE (|coord| 10..1e4,
moving 50-1500 units/s between dumps/BASE.0 and .1; main and user memory), the histogram of their speed in each other
run divided by their speed in BASE. A real-time game peaks at 1.0; a frame-locked one at the frame-rate ratio."""
import sys, numpy as np, collections
np.seterr(all='ignore')
def load(b):
    idx = np.fromfile(b + '.idx', dtype='<u4'); raw = np.fromfile(b + '.bin', dtype=np.uint8)
    t = int(open(b + '.txt').read().strip()) / 1e6
    return {int(p): raw[k * 0x10000:(k + 1) * 0x10000].view('>f4').reshape(-1, 4)[:, :3].astype(np.float64)
            for k, p in enumerate(idx) if p < 0x10000000 or 0x30000000 <= p < 0x40000000}, t
def run(tag):
    a, t0 = load('dumps/%s.0' % tag); b, t1 = load('dumps/%s.1' % tag); return a, b, t1 - t0
a0, a1, dt = run(sys.argv[1])
others = [(t, run(t)) for t in sys.argv[2:]]
hist = {t: collections.Counter() for t, _ in others}
n = 0
for p in a0:
    if p not in a1: continue
    d = np.linalg.norm(a1[p] - a0[p], axis=1) / dt
    m0 = np.abs(a0[p]).max(axis=1); m1 = np.abs(a1[p]).max(axis=1)
    ok = np.isfinite(d) & (d > 50) & (d < 1500) & (m0 < 1e4) & (m1 < 1e4) & (m0 > 10)
    for i in np.nonzero(ok)[0]:
        n += 1
        for t, (b0, b1, dtb) in others:
            if p in b0 and p in b1:
                r = np.linalg.norm(b1[p][i] - b0[p][i]) / dtb / d[i]
                if np.isfinite(r) and r > 0.05: hist[t][round(r, 1)] += 1
print('%d plausible positions in %s' % (n, sys.argv[1]))
for t, _ in others:
    top = hist[t].most_common(5)
    print('  %-14s peak x%.1f (%d)   next: %s' % (t, top[0][0], top[0][1], ', '.join('x%.1f (%d)' % kv for kv in top[1:])))
