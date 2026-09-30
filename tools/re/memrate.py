"""memrate.py LO HI base0 base1 [base2...]: like memclock.py but for a chosen rate range (units/s), for f32 and u32.
Frame-unit clocks: a game counting 1/60 s ticks shows ~60 when real-time, ~vblank when frame-locked."""
import sys, numpy as np
from collections import Counter
lo, hi = float(sys.argv[1]), float(sys.argv[2]); bases = sys.argv[3:]
walls = [int(open(b + '.txt').read().strip()) / 1e6 for b in bases]
idxs = [np.fromfile(b + '.idx', dtype='<u4') for b in bases]
common = sorted(set(idxs[0].tolist()).intersection(*[set(i.tolist()) for i in idxs[1:]]))
mems = []
for b, idx in zip(bases, idxs):
    raw = np.memmap(b + '.bin', dtype=np.uint8, mode='r'); pos = {int(p): k for k, p in enumerate(idx)}
    mems.append(np.concatenate([raw[pos[p] * 0x10000:(pos[p] + 1) * 0x10000] for p in common]))
page_of = np.array(common, dtype=np.uint64); n = len(mems[0])
addr = lambda off: int(page_of[off // 0x10000]) + off % 0x10000
for kind, dt_ in (('f32', '>f4'), ('u32', '>u4')):
    vals = [np.frombuffer(m[:n // 4 * 4], dtype=dt_).astype(np.float64) for m in mems]
    ok = np.ones(len(vals[0]), bool); rates = []
    for i in range(len(vals) - 1):
        a, b = vals[i], vals[i + 1]; dt = walls[i + 1] - walls[i]
        with np.errstate(all='ignore'):
            r = (b - a) / dt
            ok &= np.isfinite(a) & np.isfinite(b) & (np.abs(a) > 1) & (np.abs(a) < 1e9) & (r > lo) & (r < hi)
        rates.append(r)
    idx = np.nonzero(ok)[0]
    R = np.stack([r[idx] for r in rates]); cons = np.abs(R.max(0) - R.min(0)) < 0.03 * np.abs(R.mean(0)); idx = idx[cons]
    mr = np.mean([r[idx] for r in rates], axis=0)
    print(f'== {kind}: {len(idx)} linear values, dt {[round(walls[i+1]-walls[i],2) for i in range(len(walls)-1)]}')
    h = Counter(np.round(mr).astype(int))
    for k, c in sorted(h.items(), key=lambda x: -x[1])[:12]:
        ex = [f'0x{addr(int(idx[s]) * 4):08x}={vals[-1][idx[s]]:.1f}' for s in np.nonzero(np.round(mr) == k)[0][:4]]
        print(f'   rate {k:5d}/s: {c:4d}   ' + ', '.join(ex))
