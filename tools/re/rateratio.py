"""rateratio.py A0,A1[,A2] B0,B1[,B2] [maxaddr]: per-address linear rates in run A and run B (f32 and u32, addresses < maxaddr,
default 0x10000000); prints the histogram of rate(B)/rate(A). A real-time game at a faster vblank keeps game clocks at 1.0,
while frame counters move with the frame-rate ratio."""
import sys, numpy as np
from collections import Counter
maxaddr = int(sys.argv[3], 16) if len(sys.argv) > 3 else 0x10000000
def load(bases):
    walls = [int(open(b + '.txt').read().strip()) / 1e6 for b in bases]; pages = {}
    for b in bases:
        idx = np.fromfile(b + '.idx', dtype='<u4'); raw = np.memmap(b + '.bin', dtype=np.uint8, mode='r')
        pages[b] = {int(p): raw[k * 0x10000:(k + 1) * 0x10000] for k, p in enumerate(idx) if p < maxaddr}
    common = sorted(set.intersection(*[set(pages[b]) for b in bases]))
    return walls, common, [np.concatenate([pages[b][p] for p in common]) for b in bases]
def rates(bases, dt_):
    walls, common, mems = load(bases)
    vals = [np.frombuffer(m, dtype=dt_).astype(np.float64) for m in mems]
    rs = []; ok = np.ones(len(vals[0]), bool)
    for i in range(len(vals) - 1):
        with np.errstate(all='ignore'):
            r = (vals[i + 1] - vals[i]) / (walls[i + 1] - walls[i])
        ok &= np.isfinite(r) & (np.abs(vals[i]) < 1e9) & (r > 0.05) & (r < 1e5); rs.append(r)
    R = np.stack(rs)
    with np.errstate(all='ignore'):
        ok &= np.abs(R.max(0) - R.min(0)) < 0.05 * np.abs(R.mean(0))
    out = {}
    for k in np.nonzero(ok)[0]:
        out[common[k * 4 // 0x10000] + (k * 4) % 0x10000] = (R[:, k].mean(), vals[-1][k])
    return out
A, B = sys.argv[1].split(','), sys.argv[2].split(',')
for name, dt_ in (('f32', '>f4'), ('u32', '>u4')):
    ra, rb = rates(A, dt_), rates(B, dt_)
    both = sorted(set(ra) & set(rb))
    ratio = Counter(round(rb[a][0] / ra[a][0], 2) for a in both)
    print(f'== {name}: {len(both)} addresses linear in both runs')
    for k, c in sorted(ratio.items(), key=lambda x: -x[1])[:10]:
        ex = [f'0x{a:08x} {ra[a][0]:.2f}->{rb[a][0]:.2f}/s' for a in both if round(rb[a][0] / ra[a][0], 2) == k][:4]
        print(f'   ratio {k:5.2f}: {c:4d}   ' + '; '.join(ex))
