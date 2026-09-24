"""memclock.py <dumpA base> <dumpB base> [more bases...]
Each base is '<RPCS3_VR_MEMDUMP>.<n>' with .bin (guest 0..1GB) and .txt (wall time us).
Finds big-endian float/double variables that grow roughly linearly with wall time between consecutive
dumps (clock-like: game time, timers) and prints their rate (value units per wall second), clustered.
A frame-locked game run at 2x its native frame rate shows its game clocks at ~2.0; a real-time game at ~1.0.
"""
import sys, numpy as np
from collections import Counter

bases = sys.argv[1:]
walls = [int(open(b + '.txt').read().strip()) / 1e6 for b in bases]
idxs = [np.fromfile(b + '.idx', dtype='<u4') for b in bases]
common = sorted(set(idxs[0].tolist()).intersection(*[set(i.tolist()) for i in idxs[1:]]))
raws = [np.memmap(b + '.bin', dtype=np.uint8, mode='r') for b in bases]
mems = []
for raw, idx in zip(raws, idxs):
    pos = {int(p): k for k, p in enumerate(idx)}
    mems.append(np.concatenate([raw[pos[p] * 0x10000:(pos[p] + 1) * 0x10000] for p in common]))
page_of = np.array(common, dtype=np.uint64)
n = len(mems[0])
def addr(off):
    return int(page_of[off // 0x10000]) + off % 0x10000

def as_f32(m):
    return np.frombuffer(m[:n // 4 * 4], dtype='>f4')

def as_f64(m):
    return np.frombuffer(m[:n // 8 * 8], dtype='>f8')

for kind, conv in (('f32', as_f32), ('f64', as_f64)):
    vals = [conv(m) for m in mems]
    size = 4 if kind == 'f32' else 8
    ok = np.ones(len(vals[0]), bool)
    rates = []
    for i in range(len(vals) - 1):
        a, b = vals[i].astype(np.float64), vals[i + 1].astype(np.float64)
        dt = walls[i + 1] - walls[i]
        with np.errstate(all='ignore'):
            r = (b - a) / dt
            ok &= np.isfinite(a) & np.isfinite(b) & (np.abs(a) > 0.5) & (np.abs(a) < 1e8) & (r > 0.2) & (r < 6.5)
        rates.append(r)
    idx = np.nonzero(ok)[0]
    # consistent rate across intervals (linear clock)
    if len(rates) > 1:
        R = np.stack([r[idx] for r in rates])
        cons = np.abs(R.max(0) - R.min(0)) < 0.1 * np.abs(R.mean(0))
        idx = idx[cons]
    mean_rate = np.mean([r[idx] for r in rates], axis=0) if len(idx) else np.array([])
    print(f'== {kind}: {len(idx)} clock-like values; dt = {[round(walls[i+1]-walls[i],2) for i in range(len(walls)-1)]} s')
    hist = Counter(np.round(mean_rate, 1))
    for k, c in sorted(hist.items()):
        if c >= 2:
            print(f'   rate {k:4.1f}: {c}')
    # print a few examples near integer-ish rates
    for target in (0.5, 1.0, 1.5, 2.0, 3.0):
        sel = np.nonzero(np.abs(mean_rate - target) < 0.06)[0][:6]
        if len(sel):
            print(f'   ~{target}: ' + ', '.join(f'0x{addr(int(idx[s])*size):08x}={vals[-1][idx[s]]:.3f}' for s in sel))
