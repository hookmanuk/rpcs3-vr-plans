"""dispmap.py L.raw R.raw [BLOCK=96] [N=2880]: the disparity (px, left eye x minus right eye x: larger = nearer) of each
block of the left eye matched along x in the right eye (normalised correlation; '..' where the block is flat or the
match poor). A planar reflection must show the disparity of what it reflects (its distance beyond the water), not the
water surface's."""
import sys, numpy as np
B = int(sys.argv[3]) if len(sys.argv) > 3 else 96; N = int(sys.argv[4]) if len(sys.argv) > 4 else 2880
ld = lambda p: np.fromfile(p, np.uint8)[8:8 + N * N * 4].reshape(N, N, 4)[..., :3].astype(np.float32).mean(2)
L, R = ld(sys.argv[1]), ld(sys.argv[2])
for ys in range(0, N - B + 1, B):
    row = []
    for xs in range(0, N - B + 1, B):
        a = L[ys:ys + B, xs:xs + B]; a = a - a.mean(); na = np.sqrt((a * a).sum())
        best, bs = -1, 0
        if na > B * 2.0:
            for s in range(-10, 161, 2):
                if xs - s < 0 or xs - s + B > N: continue
                b = R[ys:ys + B, xs - s:xs - s + B]; b = b - b.mean(); nb = np.sqrt((b * b).sum())
                c = (a * b).sum() / (na * nb + 1e-6)
                if c > best: best, bs = c, s
        row.append('%3d' % bs if best > 0.8 else ' ..')
    print(' '.join(row))
