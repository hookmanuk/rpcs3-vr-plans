"""ratediff.py A B: addresses whose value changes like a 60 -> 30 FPS setting between dump A (60) and B (30)."""
import sys, numpy as np


def load(base):
    idx = np.fromfile(base + '.idx', dtype='<u4')
    raw = np.memmap(base + '.bin', dtype=np.uint8, mode='r')
    return idx, raw


ia, ra = load(sys.argv[1])
ib, rb = load(sys.argv[2])
common = sorted(set(ia.tolist()) & set(ib.tolist()))
pa = {int(p): k for k, p in enumerate(ia)}
pb = {int(p): k for k, p in enumerate(ib)}
A = np.concatenate([ra[pa[p] * 0x10000:(pa[p] + 1) * 0x10000] for p in common])
B = np.concatenate([rb[pb[p] * 0x10000:(pb[p] + 1) * 0x10000] for p in common])
pages = np.array(common, dtype=np.uint64)


def addr(off):
    return int(pages[off // 0x10000]) + off % 0x10000


tests = [
    ('f32 1/60->1/30', '>f4', 1 / 60, 1 / 30, 1e-4),
    ('f32 60->30', '>f4', 60.0, 30.0, 1e-2),
    ('f32 59.94->29.97', '>f4', 59.94, 29.97, 1e-2),
    ('f64 1/60->1/30', '>f8', 1 / 60, 1 / 30, 1e-6),
    ('f64 60->30', '>f8', 60.0, 30.0, 1e-6),
    ('u32 1->2', '>u4', 1, 2, 0),
    ('u32 16666/7->33333/4', '>u4', None, None, 0),
    ('u32 60->30', '>u4', 60, 30, 0),
]
for name, dt, va, vb, tol in tests:
    size = np.dtype(dt).itemsize
    a = np.frombuffer(A[:len(A) // size * size], dtype=dt)
    b = np.frombuffer(B[:len(B) // size * size], dtype=dt)
    if name.startswith('u32 16666'):
        m = np.isin(a, [16666, 16667]) & np.isin(b, [33333, 33334])
    elif dt.startswith('>u'):
        m = (a == va) & (b == vb)
    else:
        with np.errstate(all='ignore'):
            m = (np.abs(a - va) <= tol) & (np.abs(b - vb) <= tol)
    hits = np.nonzero(m)[0]
    print(f'{name}: {len(hits)}', ' '.join(f'0x{addr(int(h) * size):08x}' for h in hits[:25]))
