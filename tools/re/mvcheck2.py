"""mvcheck2.py DIR [B=16] [R=64] [F=2]: (F: the coarse search's downsampling) as mvcheck.py, for large motion: each BxB block's displacement found coarse to fine (a half
resolution SAD search over +-R px, refined +-2 px at full resolution) against its motion vector (block mean). Writes
DIR_err.npy, DIR_meas.npy (measured dx, dy per block) and DIR_mvb.npy (block mean vectors); prints per frame the median
measured motion, the median vector and the count of textured blocks off by > 2 px."""
import sys, os, numpy as np
d = sys.argv[1]; B = int(sys.argv[2]) if len(sys.argv) > 2 else 16; R = int(sys.argv[3]) if len(sys.argv) > 3 else 64; F = int(sys.argv[4]) if len(sys.argv) > 4 else 2
w, h, iw, ih, fo, fi = map(int, open(os.path.join(d, 'seq.txt')).read().split())
def rgb(i): return np.frombuffer(open(f'{d}/seq.{i:03d}.in', 'rb').read(), np.uint8).reshape(ih, iw, 4)[:, :, :3].astype(np.float32).mean(2)
def mv(i): return np.frombuffer(open(f'{d}/seq.{i:03d}.mv', 'rb').read(), np.float32).reshape(ih, iw, 2)
n = len([f for f in os.listdir(d) if f.endswith('.mv')])
ny, nx = (ih - 2 * R) // B, (iw - 2 * R) // B
def blocks(x, b): yy, xx = x.shape[0] // b, x.shape[1] // b; return x[:yy * b, :xx * b].reshape(yy, b, xx, b).mean((1, 3))
errs, meas, mvbs = [], [], []
for t in range(1, n):
    a, p, m = rgb(t), rgb(t - 1), mv(t)
    A = a[R:R + ny * B, R:R + nx * B]; std = A.reshape(ny, B, nx, B).std((1, 3))
    a2 = a[::F, ::F]; p2 = p[::F, ::F]; R2, B2 = R // F, B // F
    A2 = a2[R2:R2 + ny * B2, R2:R2 + nx * B2]
    best = np.full((ny, nx), 1e9, np.float32); bx = np.zeros((ny, nx), int); by = np.zeros((ny, nx), int)
    for dy in range(-R2, R2 + 1):
        for dx in range(-R2, R2 + 1):
            s = blocks(np.abs(p2[R2 + dy:R2 + dy + ny * B2, R2 + dx:R2 + dx + nx * B2] - A2), B2)
            b_ = s < best; best[b_] = s[b_]; bx[b_] = dx * F; by[b_] = dy * F
    fx = bx.astype(float); fy = by.astype(float); fb = np.full((ny, nx), 1e9)
    for yy in range(ny):
        for xx in range(nx):
            y0, x0 = R + yy * B, R + xx * B; blk = a[y0:y0 + B, x0:x0 + B]
            for ddy in range(-F, F + 1):
                for ddx in range(-F, F + 1):
                    oy, ox = y0 + by[yy, xx] + ddy, x0 + bx[yy, xx] + ddx
                    if oy < 0 or ox < 0 or oy + B > ih or ox + B > iw: continue
                    s = np.abs(p[oy:oy + B, ox:ox + B] - blk).mean()
                    if s < fb[yy, xx]: fb[yy, xx] = s; fx[yy, xx] = bx[yy, xx] + ddx; fy[yy, xx] = by[yy, xx] + ddy
    M = m[R:R + ny * B, R:R + nx * B]; mx, my = blocks(M[:, :, 0], B), blocks(M[:, :, 1], B)
    e = np.hypot(fx - mx, fy - my); ok = (std > 6) & (fb < 12); e[~ok] = 0
    errs.append(e); meas.append(np.stack([fx, fy])); mvbs.append(np.stack([mx, my]))
    print('%2d meas %6.1f %6.1f  mv %6.1f %6.1f  bad %d of %d' % (t, np.median(fx[ok]), np.median(fy[ok]), np.median(mx[ok]), np.median(my[ok]), int((e > 2).sum()), int(ok.sum())))
np.save(d + '_err.npy', np.array(errs)); np.save(d + '_meas.npy', np.array(meas)); np.save(d + '_mvb.npy', np.array(mvbs))
