"""posratio.py A0 A1 B0 B1: per-address speed (f32 xyz triplets moved per wall second) in run A (dumps A0->A1)
and run B (B0->B1); histogram of speed(B)/speed(A). Same scene in both runs: a real-time game gives 1.0."""
import sys, numpy as np
from collections import Counter
def load(b):
    idx = np.fromfile(b + '.idx', dtype='<u4'); raw = np.fromfile(b + '.bin', dtype=np.uint8)
    keep = [k for k, p in enumerate(idx) if p < 0x10000000]
    pages = {int(idx[k]): raw[k * 0x10000:(k + 1) * 0x10000] for k in keep}
    return pages, int(open(b + '.txt').read().strip()) / 1e6
def speeds(b0, b1):
    p0, t0 = load(b0); p1, t1 = load(b1); out = {}
    for p in set(p0) & set(p1):
        A = p0[p].view('>f4').reshape(-1, 4)[:, :3].astype(np.float64); B = p1[p].view('>f4').reshape(-1, 4)[:, :3].astype(np.float64)
        with np.errstate(all='ignore'):
            ok = np.isfinite(A).all(1) & np.isfinite(B).all(1) & (np.abs(A).max(1) < 1e5) & (np.abs(A).max(1) > 1)
            d = np.linalg.norm(B - A, axis=1)
        for i in np.where(ok & (d > 0.05) & (d < 1000))[0]: out[p + i * 16] = d[i] / (t1 - t0)
    return out
a = speeds(sys.argv[1], sys.argv[2]); b = speeds(sys.argv[3], sys.argv[4])
common = sorted(set(a) & set(b)); print(len(a), len(b), len(common), 'moving in A, B, both')
r = Counter(round(b[k] / a[k], 1) for k in common); print(r.most_common(15))
