"""parallax.py SBS.full.png name:cx:cy:w:h ...: horizontal R-L offset of each region between the eyes of a side-by-side
capture (RPCS3 SHOT of a headset session: left eye | right eye). Region coordinates are in a 960x540 view of one
eye. With parallel headset eyes, nearer objects have a more negative R-L than far ones (the far-field value is the
two frusta's offset). Prints offset, vertical offset and match score (trust > 0.6). Env PLX_LO/PLX_HI: search range."""
import sys, numpy as np
from PIL import Image
a = Image.open(sys.argv[1]).convert('L'); w, h = a.size
L = np.asarray(a.crop((0, 0, w // 2, h)), dtype=np.float32); R = np.asarray(a.crop((w // 2, 0, w, h)), dtype=np.float32)
sx = (w // 2) / 960; sy = h / 540
import os
lo = int(os.environ.get('PLX_LO', -1200)); hi = int(os.environ.get('PLX_HI', 200))
for spec in sys.argv[2:]:
    name, cx, cy, bw, bh = spec.split(':'); cx, cy, bw, bh = map(float, (cx, cy, bw, bh))
    x0 = int((cx - bw / 2) * sx); y0 = int((cy - bh / 2) * sy); tw = int(bw * sx); th = int(bh * sy)
    tpl = L[y0:y0 + th, x0:x0 + tw]; t = (tpl - tpl.mean()) / (tpl.std() + 1e-6)
    def score(dx, dy):
        if x0 + dx < 0: return -2
        p = R[y0 + dy:y0 + dy + th, x0 + dx:x0 + dx + tw]
        if p.shape != tpl.shape: return -2
        q = (p - p.mean()) / (p.std() + 1e-6); return (t * q).mean()
    best = (-2, 0, 0)
    for dy in range(-4, 5, 2):
        for dx in range(lo, hi + 1, 3):
            s = score(dx, dy)
            if s > best[0]: best = (s, dx, dy)
    # refine: 1 px around the coarse best, then a parabola through the peak for sub-pixel x
    s0, bx, by = best
    for dy in range(by - 2, by + 3):
        for dx in range(bx - 3, bx + 4):
            s = score(dx, dy)
            if s > best[0]: best = (s, dx, dy)
    s0, bx, by = best
    sl, sr = score(bx - 1, by), score(bx + 1, by)
    den = sl - 2 * s0 + sr
    sub = bx + (0.5 * (sl - sr) / den if den < 0 else 0.0)
    print(f"{name:14s} R-L x {sub:8.1f} px  y {by:3d}  score {s0:.3f}")
