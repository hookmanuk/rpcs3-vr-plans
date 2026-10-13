"""posspeed.py A0,A1 B0,B1: f32 xyz triplets (16-byte aligned) moving 5..120 units per wall second in both runs (same
savestate, same layout); histogram of speed(B)/speed(A) and examples."""
import sys, numpy as np
from collections import Counter
def load(bases):
    walls = [int(open(b + '.txt').read().strip()) / 1e6 for b in bases]; pages = []
    for b in bases:
        idx = np.fromfile(b + '.idx', dtype='<u4'); raw = np.memmap(b + '.bin', dtype=np.uint8, mode='r')
        pages.append({int(p): raw[k * 0x10000:(k + 1) * 0x10000] for k, p in enumerate(idx) if p < 0x60000000})
    common = sorted(set(pages[0]) & set(pages[1]))
    return walls, common, [np.concatenate([pg[p] for p in common]) for pg in pages]
def speeds(bases):
    walls, common, mems = load(bases)
    v = [np.frombuffer(m, dtype='>f4').astype(np.float64).reshape(-1, 4)[:, :3] for m in mems]
    with np.errstate(all='ignore'):
        d = np.sqrt(((v[1] - v[0]) ** 2).sum(1)) / (walls[1] - walls[0])
        ok = np.isfinite(d) & (d > 5) & (d < 120) & (np.abs(v[0]).max(1) < 5000) & (np.abs(v[0]).max(1) > 1)
    addr = lambda k: common[k * 16 // 0x10000] + (k * 16) % 0x10000
    return {addr(k): d[k] for k in np.nonzero(ok)[0]}
A, B = speeds(sys.argv[1].split(',')), speeds(sys.argv[2].split(','))
both = sorted(set(A) & set(B))
print(len(A), len(B), len(both), 'moving triplets in A, B, both')
c = Counter(round(B[a] / A[a], 1) for a in both)
for k, n in sorted(c.items(), key=lambda x: -x[1])[:12]:
    ex = [f'0x{a:08x} {A[a]:.1f}->{B[a]:.1f}' for a in both if round(B[a] / A[a], 1) == k][:3]
    print(f'ratio {k:4.1f}: {n:5d}  ' + '; '.join(ex))
