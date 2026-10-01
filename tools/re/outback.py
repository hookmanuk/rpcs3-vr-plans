"""outback.py A B C: f32 xyz triplets that moved A->B (walk forward) and returned B->C (walk back): candidates for the player position."""
import sys, numpy as np
def load(b):
    idx = np.fromfile(b + '.idx', dtype='<u4'); raw = np.fromfile(b + '.bin', dtype=np.uint8)
    keep = [k for k, p in enumerate(idx) if p < 0x20000000]
    return idx[keep], np.concatenate([raw[k * 0x10000:(k + 1) * 0x10000] for k in keep])
ia, a = load(sys.argv[1]); ib, b = load(sys.argv[2]); ic, c = load(sys.argv[3])
lo = float(sys.argv[4]) if len(sys.argv) > 4 else 20
out = []
for off in (0, 4, 8, 12):
    n = (len(a) - off) // 16 * 16
    A, B, C = [x[off:off + n].view('>f4').reshape(-1, 4)[:, :3].astype(np.float64) for x in (a, b, c)]
    with np.errstate(all='ignore'):
        ok = np.isfinite(A).all(1) & np.isfinite(B).all(1) & np.isfinite(C).all(1) & (np.abs(A).max(1) < 1e5) & ((np.abs(A) > 1).sum(1) >= 2)
        d1 = np.linalg.norm(B - A, axis=1); d2 = np.linalg.norm(C - B, axis=1); d3 = np.linalg.norm(C - A, axis=1)
    for i in np.where(ok & (d1 > lo) & (d1 < 3000) & (d3 < 0.4 * d1) & (d2 > 0.6 * d1))[0]:
        o = off + i * 16; out.append((int(ia[o // 0x10000]) + o % 0x10000, A[i], B[i], C[i], d1[i], d2[i]))
from collections import Counter
print(len(out), 'candidates; distance histogram', Counter(round(r[4]) for r in out).most_common(8))
for r in out[:12]: print(hex(r[0]), np.round(r[1], 1), np.round(r[2], 1), np.round(r[3], 1), 'out %.1f back %.1f' % (r[4], r[5]))
