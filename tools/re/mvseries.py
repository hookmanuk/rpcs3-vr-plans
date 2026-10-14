"""mvseries.py DIR: per frame, median measured block motion vs median motion vector (textured blocks), and the same
against the NEXT frame's vectors (a one-frame lag shows as a better match there)."""
import sys, os, numpy as np
d = sys.argv[1]; B, R = 16, 26
w, h, iw, ih, fo, fi = map(int, open(os.path.join(d, 'seq.txt')).read().split())
def rgb(i): return np.frombuffer(open(f'{d}/seq.{i:03d}.in', 'rb').read(), np.uint8).reshape(ih, iw, 4)[:, :, :3].astype(np.float32).mean(2)
def mv(i): return np.frombuffer(open(f'{d}/seq.{i:03d}.mv', 'rb').read(), np.float32).reshape(ih, iw, 2)
n = len([f for f in os.listdir(d) if f.endswith('.mv')])
ny, nx = (ih - 2 * R) // B, (iw - 2 * R) // B
def blocks(x): return x[:ny * B, :nx * B].reshape(ny, B, nx, B).mean((1, 3))
mvs = [None] + [mv(t) for t in range(1, n)]
for t in range(1, n):
    a, p = rgb(t), rgb(t - 1)
    A = a[R:R + ny * B, R:R + nx * B]; std = A.reshape(ny, B, nx, B).std((1, 3))
    best = np.full((ny, nx), 1e9, np.float32); bx = np.zeros((ny, nx)); by = np.zeros((ny, nx))
    for dy in range(-R, R + 1):
        for dx in range(-R, R + 1):
            s = blocks(np.abs(p[R + dy:R + dy + ny * B, R + dx:R + dx + nx * B] - A))
            b = s < best; best[b] = s[b]; bx[b] = dx; by[b] = dy
    ok = (std > 6) & (best < 12)
    row = []
    for k in (t - 1, t, t + 1):
        if k >= n or k < 1: continue
        M = mvs[k][R:R + ny * B, R:R + nx * B]; mx, my = blocks(M[:, :, 0]), blocks(M[:, :, 1])
        row.append('mv%+d %6.1f %5.1f err %4.1f' % (k - t, np.median(mx[ok]), np.median(my[ok]), np.median(np.hypot(bx - mx, by - my)[ok])))
    print('%2d meas %6.1f %5.1f  ' % (t, np.median(bx[ok]), np.median(by[ok])) + ' | '.join(row))
