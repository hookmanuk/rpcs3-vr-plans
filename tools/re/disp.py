import sys, numpy as np
from PIL import Image
# disp.py sbs.full.png  -> horizontal shift right-vs-left for regions (in full-eye pixels); image is 2 eyes squeezed into 16:9
im = np.asarray(Image.open(sys.argv[1]).convert('L')).astype(np.float32)
H, W = im.shape; half = W // 2
L = im[:, :half]; R = im[:, half:2*half]
sx = 2.0  # squeezed horizontally by 2
regions = {'hud_pos': (0.03,0.08,0.05,0.2), 'hud_map': (0.78,0.95,0.05,0.25), 'far_trees': (0.1,0.9,0.28,0.4), 'mid_track': (0.1,0.9,0.5,0.6), 'car': (0.35,0.65,0.55,0.85)}
if len(sys.argv) > 2:
    regions = {}
    for spec in sys.argv[2:]:
        n, v = spec.split('='); regions[n] = tuple(map(float, v.split(',')))
for name, (x0, x1, y0, y1) in regions.items():
    a = L[int(y0*H):int(y1*H), int(x0*half):int(x1*half)]
    best = None
    for d in range(-25, 26):
        xs0, xs1 = int(x0*half)+d, int(x1*half)+d
        if xs0 < 0 or xs1 > half: continue
        b = R[int(y0*H):int(y1*H), xs0:xs1]
        aa = a - a.mean(); bb = b - b.mean()
        c = (aa*bb).sum() / (np.sqrt((aa*aa).sum()*(bb*bb).sum()) + 1e-6)
        if best is None or c > best[0]: best = (c, d)
    print(f'{name:10s} shift {best[1]*sx:+5.1f} px (corr {best[0]:.3f})')
