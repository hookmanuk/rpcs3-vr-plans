import sys, os, numpy as np
from PIL import Image
# texview.py ADDR OUT [X0 Y0 W H in 3584 coords] [DISP]: both layers of %TEMP%/dcvr/tex_ADDR_{0,1}.raw side by side
D = os.path.join(os.environ['TEMP'], 'dcvr')
addr, out = sys.argv[1], sys.argv[2]
x0, y0, w, h = [int(v) for v in sys.argv[3:7]] if len(sys.argv) > 6 else (1980, 1500, 450, 300)
disp = int(sys.argv[7]) if len(sys.argv) > 7 else -16
def load(layer):
    b = open(os.path.join(D, f'tex_{addr}_{layer}.raw'), 'rb').read()
    W, H, fmt, n = np.frombuffer(b[:16], np.uint32)
    d = b[16:16 + n]
    if fmt == 97: a = np.frombuffer(d, np.float16).reshape(H, W, 4).astype(np.float32)[..., :3]
    elif fmt in (130, 100, 124): a = np.frombuffer(d, np.float32).reshape(H, W)[..., None].repeat(3, 2)
    elif fmt == 83: a = np.frombuffer(d, np.float16).reshape(H, W, 2).astype(np.float32); a = np.dstack([a, a[..., :1] * 0])
    elif fmt in (37, 43): a = np.frombuffer(d, np.uint8).reshape(H, W, 4)[..., :3].astype(np.float32) / 255
    elif fmt in (9, 13): a = np.frombuffer(d, np.uint8).reshape(H, W)[..., None].repeat(3, 2).astype(np.float32) / 255
    else: raise SystemExit(f'fmt {fmt}')
    return a, W, fmt
L, W, fmt = load(0); R, _, _ = load(1)
s = W / 3584
X0, Y0, ww, hh, dd = int(x0 * s), int(y0 * s), int(w * s), int(h * s), int(round(disp * s))
cl, cr = L[Y0:Y0+hh, X0:X0+ww], R[Y0:Y0+hh, X0+dd:X0+dd+ww]
both = np.concatenate([cl, cr], 1)
lo, hi = np.percentile(both, 1), np.percentile(both, 99)
if fmt in (130, 100, 124): lo, hi = np.percentile(both, 1), np.percentile(both, 99)
img = np.clip((both - lo) / max(hi - lo, 1e-6), 0, 1) ** (1 / 2.2 if fmt == 97 else 1)
img = (img * 255).astype(np.uint8)
diff = np.abs(cl - cr).mean(2); dimg = np.clip(diff / max(np.percentile(diff, 99.5), 1e-6) * 255, 0, 255).astype(np.uint8)
full = np.concatenate([img, np.dstack([np.concatenate([dimg, dimg * 0], 1)] * 3)], 0)
Image.fromarray(full).resize((900, int(900 * full.shape[0] / full.shape[1]))).save(out)
print(addr, 'fmt', fmt, 'W', W, 'mean |L-R|', float(diff.mean()), 'range', float(lo), float(hi))
