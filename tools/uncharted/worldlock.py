"""worldlock.py TAG YAW W H TX TY: warps TAG_yYAW.raw back to yaw 0 (pure rotation, the render's tangents TX, TY) and
compares with TAG_a.raw; TAG_c.raw (yaw 0 again) is the control. Prints mean diffs per 4x4 grid; writes TAG_wl.png."""
import sys, numpy as np
from PIL import Image
tag, yaw = sys.argv[1], float(sys.argv[2]); W, H = int(sys.argv[3]), int(sys.argv[4]); TX, TY = float(sys.argv[5]), float(sys.argv[6])
load = lambda n: np.frombuffer(open(f'{tag}_{n}.raw', 'rb').read()[8:8+W*H*4], np.uint8).reshape(H, W, 4)[..., :3].astype(np.float32)
A, C, B = load('a'), load('c'), load(f'y{yaw:g}')
ys, xs = np.mgrid[0:H, 0:W]
x = ((xs + 0.5) / W * 2 - 1) * TX; y = (1 - (ys + 0.5) / H * 2) * TY
best = None
for sgn in (1, -1):
    t = np.radians(yaw) * sgn; c, s = np.cos(t), np.sin(t)
    xb = c * x - s; zb = s * x + c   # direction (x, y, 1) turned about y
    u = xb / zb; v = y / zb
    px = ((u / TX + 1) / 2 * W - 0.5); py = ((1 - v / TY) / 2 * H - 0.5)
    ok = (zb > 0) & (px >= 0) & (px < W - 1) & (py >= 0) & (py < H - 1)
    Bw = np.zeros_like(A); Bw[ok] = B[py[ok].astype(int), px[ok].astype(int)]
    d = np.abs(Bw - A).mean(-1); d[~ok] = np.nan
    m = np.nanmean(d)
    if best is None or m < best[0]: best = (m, d, ok, sgn)
m, d, ok, sgn = best
dc = np.abs(C - A).mean(-1)
print(f'sign {sgn} warped diff {m:.2f}, control {np.mean(dc[ok]):.2f}')
g = 4
for r in range(g):
    print(' '.join(f'{np.nanmean(d[r*H//g:(r+1)*H//g, k*W//g:(k+1)*W//g]):6.1f}/{np.mean(dc[r*H//g:(r+1)*H//g, k*W//g:(k+1)*W//g]):5.1f}' for k in range(g)))
img = np.nan_to_num(np.clip(d - dc, 0, 255) * 4).clip(0, 255).astype(np.uint8)
Image.fromarray(np.concatenate([A.astype(np.uint8), np.stack([img] * 3, -1)], 1)).resize((W // 2, H // 4)).save(f'{tag}_wl.png')
