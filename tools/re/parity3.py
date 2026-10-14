"""parity3.py DIR [LIMIT=18]: mvcheck errors (DIR_err.npy) by DLSS frame parity, only blocks whose own motion vector is under
LIMIT px (inside the search window): bad blocks (> 2 px) a frame and mean error."""
import sys, numpy as np
d = sys.argv[1]; lim = float(sys.argv[2]) if len(sys.argv) > 2 else 18
w, h, iw, ih, fo, fi = map(int, open(d + '/seq.txt').read().split()); B, R = 16, 26
ny, nx = (ih - 2 * R) // B, (iw - 2 * R) // B
e = np.load(d + '_err.npy'); out = {0: [], 1: []}
for t in range(1, e.shape[0] + 1):
    m = np.frombuffer(open(f'{d}/seq.{t:03d}.mv', 'rb').read(), np.float32).reshape(ih, iw, 2)[R:R + ny * B, R:R + nx * B]
    mag = np.hypot(m[..., 0], m[..., 1]).reshape(ny, B, nx, B).max((1, 3))
    err = e[t - 1]; ok = (err > 0) & (mag < lim)
    f = int(open(f'{d}/seq.{t:03d}.f').read())
    if ok.sum() > 50: out[f & 1].append(((err[ok] > 2).sum(), err[ok].mean(), ok.sum()))
for k in (0, 1):
    a = np.array(out[k]); print('%s: %.1f bad blocks a frame of %.0f checked, mean error %.2f px, %d frames' % ('even' if k == 0 else 'odd ', a[:, 0].mean(), a[:, 2].mean(), a[:, 1].mean(), len(a)))
