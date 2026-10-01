"""movratio.py A0 A1 B0 B1: per-address displacement (f32 xyz, 16-byte aligned) in run A and B; histogram of B/A for
addresses that moved more than 0.5 in both (same input in both runs: a real-time game gives ~1.0)."""
import sys, numpy as np
from collections import Counter
def load(b):
    idx = np.fromfile(b + '.idx', dtype='<u4'); raw = np.fromfile(b + '.bin', dtype=np.uint8)
    return {int(p): raw[k * 0x10000:(k + 1) * 0x10000] for k, p in enumerate(idx) if p < 0x20000000}
def disp(a0, a1):
    p0, p1 = load(a0), load(a1); out = {}
    for p in set(p0) & set(p1):
        A = p0[p].view('>f4').reshape(-1, 4)[:, :3].astype(np.float64); B = p1[p].view('>f4').reshape(-1, 4)[:, :3].astype(np.float64)
        with np.errstate(all='ignore'):
            ok = np.isfinite(A).all(1) & np.isfinite(B).all(1) & (np.abs(A).max(1) < 1e5)
            d = np.linalg.norm(B - A, axis=1)
        for i in np.where(ok & (d > 0.5) & (d < 1e4))[0]: out[p + i * 16] = d[i]
    return out
a = disp(sys.argv[1], sys.argv[2]); b = disp(sys.argv[3], sys.argv[4])
common = sorted(set(a) & set(b)); print(len(a), len(b), len(common), 'moved in A, B, both')
print(Counter(round(b[k] / a[k], 1) for k in common).most_common(10))
