"""rtcmp.py BASE OTHER [OTHER...]: speed of the fastest-moving f32 xyz triplets (main and user memory) of run BASE
(dumps/BASE.0 -> .1) in each other run, as a ratio (1.0 = same real-time speed). Prints the top 20 and the median."""
import sys, numpy as np
def load(b):
    idx = np.fromfile(b + '.idx', dtype='<u4'); raw = np.fromfile(b + '.bin', dtype=np.uint8)
    t = int(open(b + '.txt').read().strip()) / 1e6
    return {int(p): raw[k * 0x10000:(k + 1) * 0x10000].view('>f4').reshape(-1, 4)[:, :3].astype(np.float64)
            for k, p in enumerate(idx) if p < 0x10000000 or 0x30000000 <= p < 0x40000000}, t
def run(tag):
    a, t0 = load('dumps/%s.0' % tag); b, t1 = load('dumps/%s.1' % tag); return a, b, t1 - t0
np.seterr(all='ignore')
base = run(sys.argv[1]); others = [(t, run(t)) for t in sys.argv[2:]]
a0, a1, dt = base
cands = []
for p in a0:
    if p not in a1: continue
    d = np.linalg.norm(a1[p] - a0[p], axis=1) / dt
    ok = np.isfinite(d) & (d > 30) & (d < 5000) & (np.abs(a0[p]).max(axis=1) < 1e5) & (np.abs(a0[p]).max(axis=1) > 1)
    cands += [(p, i, d[i]) for i in np.nonzero(ok)[0]]
cands.sort(key=lambda c: -c[2])
ratios = {t: [] for t, _ in others}
for n, (p, i, s) in enumerate(cands[:200]):
    line = '%08x  base %7.1f' % (p + i * 16, s)
    for t, (b0, b1, dtb) in others:
        r = np.linalg.norm(b1[p][i] - b0[p][i]) / dtb / s if p in b0 and p in b1 else float('nan')
        ratios[t].append(r)
        line += '  %s x%.2f' % (t, r)
    if n < 20: print(line)
for t in ratios:
    v = np.array([r for r in ratios[t] if np.isfinite(r)])
    print('%s: median ratio over the %d fastest: %.3f' % (t, len(v), np.median(v)))
