"""mvcheck.py DIR [B=16] [R=26]: per frame of a RPCS3_DLSS_SEQ dump with .mv/.z: for BxB blocks of the input, the motion
vector (block mean, render px, prev = cur + mv) against the block's measured displacement in the previous input (SAD
search +-R px). Prints per frame the textured blocks off by > 2 px (x, y, measured, mv, sad); writes DIR_err.npy
(frames x blocks error) and DIR_mverr.png (the frame with most, bad blocks boxed)."""
import sys, os, numpy as np
from PIL import Image, ImageDraw
d = sys.argv[1]; B = int(sys.argv[2]) if len(sys.argv) > 2 else 16; R = int(sys.argv[3]) if len(sys.argv) > 3 else 26
w, h, iw, ih, fo, fi = map(int, open(os.path.join(d, 'seq.txt')).read().split())
def rgb(i): return np.frombuffer(open(f'{d}/seq.{i:03d}.in', 'rb').read(), np.uint8).reshape(ih, iw, 4)[:, :, :3].astype(np.float32).mean(2)
def mv(i): return np.frombuffer(open(f'{d}/seq.{i:03d}.mv', 'rb').read(), np.float32).reshape(ih, iw, 2)
n = len([f for f in os.listdir(d) if f.endswith('.mv')])
ny, nx = (ih - 2 * R) // B, (iw - 2 * R) // B
def blocks(x): return x[:ny * B, :nx * B].reshape(ny, B, nx, B).mean((1, 3))
worst = (0, None, None); errs = []
for t in range(1, n):
    a, p, m = rgb(t), rgb(t - 1), mv(t)
    A = a[R:R + ny * B, R:R + nx * B]
    std = A.reshape(ny, B, nx, B).std((1, 3))
    best = np.full((ny, nx), 1e9, np.float32); bx = np.zeros((ny, nx)); byy = np.zeros((ny, nx))
    for dy in range(-R, R + 1):
        for dx in range(-R, R + 1):
            s = blocks(np.abs(p[R + dy:R + dy + ny * B, R + dx:R + dx + nx * B] - A))
            better = s < best; best[better] = s[better]; bx[better] = dx; byy[better] = dy
    M = m[R:R + ny * B, R:R + nx * B]; mx, my = blocks(M[:, :, 0]), blocks(M[:, :, 1])
    e = np.hypot(bx - mx, byy - my); ok = (std > 6) & (best < 12)
    e[~ok] = 0; errs.append(e)
    bad = np.argwhere(e > 2)
    print(t, len(bad), [(int(R + x * B), int(R + y * B), int(bx[y, x]), int(byy[y, x]), round(float(mx[y, x]), 1), round(float(my[y, x]), 1)) for y, x in bad[:5]])
    if len(bad) > worst[0]: worst = (len(bad), t, bad)
np.save(d + '_err.npy', np.array(errs))
if worst[1]:
    t = worst[1]; im = Image.fromarray(np.frombuffer(open(f'{d}/seq.{t:03d}.in', 'rb').read(), np.uint8).reshape(ih, iw, 4)[:, :, 2::-1].copy())
    dr = ImageDraw.Draw(im)
    for y, x in worst[2]: dr.rectangle((R + x * B, R + y * B, R + x * B + B, R + y * B + B), outline=(255, 0, 0))
    im.save(d + '_mverr.png'); print('worst frame', t, worst[0])
