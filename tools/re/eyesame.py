"""eyesame.py IMG...: headset shots (simshot: left eye | right eye). For each, the horizontal shift that best aligns the
right eye onto the left over the whole image and the residual at shift 0. Healthy stereo on the simulator: the best shift
is the frusta offset (tens to hundreds of px) and shift 0 leaves a residual; IDENTICAL eyes (0 shift, ~0 residual)
mean both eyes got one image (Dragon Age II before 2026-10-07: an SPU copy blitted back)."""
import sys, numpy as np
from PIL import Image
for f in sys.argv[1:]:
    im = Image.open(f).convert('L'); w, h = im.size
    a = np.asarray(im, dtype=np.float32); L = a[:, :w // 2]; R = a[:, w // 2:w // 2 * 2]
    r0 = float(np.abs(L - R).mean())
    best = (1e9, 0)
    for s in range(-w // 6, w // 12, 2):
        if s < 0: d = np.abs(L[:, -s:] - R[:, :R.shape[1] + s]).mean()
        else: d = np.abs(L[:, :L.shape[1] - s] - R[:, s:]).mean() if s else r0
        best = min(best, (float(d), s))
    flag = 'IDENTICAL' if r0 < 0.5 else ''
    print(f'{f}: residual at 0 {r0:.2f}, best shift {best[1]} ({best[0]:.2f}) {flag}')
