import sys, glob, re, numpy as np
# wedge.py PATTERN...: per dump pair (*_0.raw / *_1.raw), how much darker the left eye is than the right over the
# wedge below U2's wreck fire (Matt's cliff save, first walk leg): native x 2170-2235, y 1605-1695, right eye 5 px left.
def load(p): return np.fromfile(p, np.uint8)[8:].reshape(3584, 3584, 4)[1605:1695, 2160:2240, :3].astype(np.float32).mean(2)
for pat in sys.argv[1:]:
    vals = []
    for f0 in sorted(glob.glob(pat + '_0.raw')):
        L = load(f0)[:, 10:75]; R = load(f0[:-6] + '_1.raw')[:, 5:70]
        vals.append(float((R - L).mean()))
    print(f'{pat:28s} R-L ' + ' '.join(f'{v:5.1f}' for v in vals) + f'   wedge frames (>4): {sum(v > 4 for v in vals)}/{len(vals)}')
