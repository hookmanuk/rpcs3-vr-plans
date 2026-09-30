"""posdiff.py A B: f32 xyz triplets (16-byte aligned, below 0x10000000) that moved between dumps A and B; histogram of distances."""
import sys, numpy as np
from collections import Counter
def load(b):
    idx = np.fromfile(b + '.idx', dtype='<u4'); raw = np.fromfile(b + '.bin', dtype=np.uint8)
    keep = [k for k, p in enumerate(idx) if p < 0x10000000]
    return idx[keep], np.concatenate([raw[k * 0x10000:(k + 1) * 0x10000] for k in keep])
ia, a = load(sys.argv[1]); ib, b = load(sys.argv[2])
assert (ia == ib).all()
A = a.view('>f4').reshape(-1, 4)[:, :3].astype(np.float64); B = b.view('>f4').reshape(-1, 4)[:, :3].astype(np.float64)
with np.errstate(all='ignore'):
    ok = np.isfinite(A).all(1) & np.isfinite(B).all(1) & (np.abs(A).max(1) < 1e5) & (np.abs(A).max(1) > 1)
    d = np.linalg.norm(B - A, axis=1)
sel = np.where(ok & (d > float(sys.argv[3]) if len(sys.argv) > 3 else ok & (d > 0.5)) & (d < 1000))[0]
addr = lambda i: int(ia[(i * 16) // 0x10000]) + (i * 16) % 0x10000
print(len(sel), 'moved'); print(Counter(round(x, 1) for x in d[sel]).most_common(12))
for i in sel[:20]: print(hex(addr(i)), np.round(A[i], 2), np.round(B[i], 2), round(d[i], 2))
