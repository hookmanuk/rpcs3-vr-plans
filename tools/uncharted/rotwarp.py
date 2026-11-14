"""rotwarp.py REF.raw TURNED.raw YAW PITCH ROLL OUT.png [TX=1.4565 TY=1.3902 N=2880]: the eye dump TURNED (taken with the
simulator's head at YAW PITCH ROLL degrees, position 0) warped back to the head-0 dump REF by the pure rotation, trying
the sign and order conventions and keeping the one that fits the top 45% of the picture (the land) best. Prints the mean
difference there and in the bottom 45% (the water: a planar reflection is a fixed virtual scene, so it must warp back
as well as the land does), and writes REF | warped | difference (x4) for a look. A world-lock check for reflections."""
import sys, itertools, numpy as np
from PIL import Image
ref, turned, out = sys.argv[1], sys.argv[2], sys.argv[6]
yaw, pitch, roll = (np.radians(float(v)) for v in sys.argv[3:6])
TX = float(sys.argv[7]) if len(sys.argv) > 7 else 1.4565
TY = float(sys.argv[8]) if len(sys.argv) > 8 else 1.3902
N = int(sys.argv[9]) if len(sys.argv) > 9 else 2880
K = 4  # work at 1/4 size
ld = lambda p: np.fromfile(p, np.uint8)[8:8 + N * N * 4].reshape(N, N, 4)[::K, ::K, :3].astype(np.float32)
A, B = ld(ref), ld(turned)
n = N // K
ys, xs = np.mgrid[0:n, 0:n]
d = np.stack([((xs + 0.5) / n * 2 - 1) * TX, (1 - (ys + 0.5) / n * 2) * TY, -np.ones((n, n))], -1)  # x right, y up, -z ahead


def rot(axis, a):
    c, s = np.cos(a), np.sin(a)
    return {'x': np.array([[1, 0, 0], [0, c, -s], [0, s, c]]), 'y': np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]]),
            'z': np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])}[axis]


best = None
for sy, sp, sr in itertools.product((1, -1), repeat=3):
    for order in itertools.permutations('ypr'):
        m = np.eye(3)
        for o in order:
            m = m @ {'y': rot('y', sy * yaw), 'p': rot('x', sp * pitch), 'r': rot('z', sr * roll)}[o]
        for mm in (m, m.T):
            v = d @ mm.T
            ok = v[..., 2] < -1e-3
            u = v[..., 0] / -v[..., 2]; w = v[..., 1] / -v[..., 2]
            px = (u / TX + 1) / 2 * n - 0.5; py = (1 - w / TY) / 2 * n - 0.5
            ok &= (px >= 0) & (px < n - 1) & (py >= 0) & (py < n - 1)
            W = np.zeros_like(A); W[ok] = B[py[ok].astype(int), px[ok].astype(int)]
            diff = np.abs(W - A).mean(-1); diff[~ok] = np.nan
            top = np.nanmean(diff[: int(n * 0.45)])
            if best is None or top < best[0]:
                best = (top, diff, W, ok)
top, diff, W, ok = best
bottom = np.nanmean(diff[int(n * 0.55):])
print('land %.2f  water %.2f  (covered %.0f%%)' % (top, bottom, ok.mean() * 100))
img = np.concatenate([np.clip(A * 1.6, 0, 255), np.clip(W * 1.6, 0, 255), np.stack([np.nan_to_num(diff) * 4] * 3, -1).clip(0, 255)], 1)
Image.fromarray(img.astype(np.uint8)).save(out)
