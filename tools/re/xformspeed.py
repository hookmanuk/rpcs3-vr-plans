"""xformspeed.py A0,A1 B0,B1 ...: object transforms (16-byte aligned 4x4 f32 matrices: rows 0-2 unit length and orthogonal,
row 3 a position with w = 1) and their speed per wall second between each run's two dumps (same savestate: same addresses).
Prints, for transforms moving 5-90 m/s in the first run, the speed in every run and the ratio to the first."""
import sys, numpy as np
def load(b):
    idx = np.fromfile(b + '.idx', dtype='<u4'); raw = np.memmap(b + '.bin', dtype=np.uint8, mode='r')
    return idx, raw, int(open(b + '.txt').read()) / 1e6
def mats(b):
    idx, raw, t = load(b)
    f = np.frombuffer(raw, dtype='>f4').astype(np.float32).reshape(-1, 16)
    with np.errstate(all='ignore'):
        r = f[:, :12].reshape(-1, 3, 4)[:, :, :3]
        n = np.linalg.norm(r, axis=2)
        ok = (np.abs(n - 1) < 1e-3).all(1) & (np.abs(f[:, 15] - 1) < 1e-6) & (np.abs(f[:, 12:15]).max(1) < 5000) & (np.abs(f[:, 12:15]).max(1) > 1)
        d01 = np.abs((r[:, 0] * r[:, 1]).sum(1)) < 1e-3
        ok &= d01
    ks = np.nonzero(ok)[0]
    addr = lambda k: int(idx[(k * 64) // 0x10000]) + (k * 64) % 0x10000
    return {addr(k): f[k, 12:15].copy() for k in ks}, t
runs = [arg.split(',') for arg in sys.argv[1:]]
speeds = []
for a, b in runs:
    (ma, ta), (mb, tb) = mats(a), mats(b)
    speeds.append({k: float(np.linalg.norm(mb[k] - ma[k]) / (tb - ta)) for k in ma.keys() & mb.keys()})
base = speeds[0]
keys = sorted(k for k, v in base.items() if 5 < v < 90 and all(k in s for s in speeds))
print(len(keys), 'transforms moving 5-90 m/s in the first run')
for k in keys[:60]:
    print('0x%08x' % k, ' '.join('%6.2f' % s[k] for s in speeds), ' ratios', ' '.join('%5.2f' % (s[k] / base[k]) for s in speeds[1:]))
if len(speeds) > 1:
    for i, s in enumerate(speeds[1:], 1):
        r = np.array([s[k] / base[k] for k in keys]); print('run %d: median ratio %.3f (25%% %.3f, 75%% %.3f)' % (i, np.median(r), np.percentile(r, 25), np.percentile(r, 75)))
