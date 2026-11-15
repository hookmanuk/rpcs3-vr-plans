"""wakerate.py RING_A.raw RING_B.raw: is the walk's wake animated by the clock or by the frame? Two flash rings of
the same scripted walk (ripplering.sh WALKING=1) at 90 and 60 FPS, lined up by the walk's start. For equal real lags
(33.3, 66.7, 100 ms: 3, 6, 9 frames at 90; 2, 4, 6 at 60) the change of the picture between two frames (1 - the
normalised correlation of the region's detail), averaged from 400 to 1500 ms into the walk, for three regions: the
wake behind Drake, the far water, and the bank (no water: the camera's motion alone, the control). The camera's path
follows the clock, so the control is equal in both; a wake stepped once a frame changes more per real lag at 90."""
import sys, numpy as np
sys.argv_keep = sys.argv[:]; import importlib.util
spec = importlib.util.spec_from_file_location('wakecmp_ring', __file__.replace('wakerate.py', 'wakecmp.py'))
src = open(spec.origin).read().split('rings = [Ring')[0]
ns = {}; exec(compile(src, 'wakecmp', 'exec'), ns)
A, B = ns['Ring'](sys.argv[1]), ns['Ring'](sys.argv[2])
REG = {'wake': (0.56, 0.66, 0.50, 0.78), 'far water': (0.69, 0.80, 0.15, 0.45), 'bank (control)': (0.40, 0.50, 0.50, 0.85)}


def change(r, start, step_frames, lags):
    out = {k: {l: [] for l in lags} for k in REG}
    i0 = int(np.argmin(np.abs(r.t - (start + 400)))); i1 = int(np.argmin(np.abs(r.t - (start + 1500))))
    cache = {}
    def g(i):
        if i not in cache: cache[i] = r.frame(i).astype(np.float32).mean(2)
        return cache[i]
    for i in range(i0, i1, step_frames):
        for l in lags:
            j = i + l * step_frames
            if j >= r.n: continue
            a, b = g(i), g(j); h, e = a.shape
            for k, (y0, y1, x0, x1) in REG.items():
                p = a[int(h * y0):int(h * y1), int(e * x0):int(e * x1)]; q = b[int(h * y0):int(h * y1), int(e * x0):int(e * x1)]
                p = p - p.mean(); q = q - q.mean()
                out[k][l].append(1 - float((p * q).sum() / (np.sqrt((p * p).sum() * (q * q).sum()) + 1e-6)))
    return {k: {l: float(np.mean(v)) for l, v in d.items()} for k, d in out.items()}


sa, sb = A.start(), B.start()
print('walk starts: A %.0f ms (%.1f FPS), B %.0f ms (%.1f FPS)' % (sa, A.fps, sb, B.fps))
fa = round(A.fps / 30); fb = round(B.fps / 30)  # frames per 33.3 ms
ca, cb = change(A, sa, fa, (1, 2, 3)), change(B, sb, fb, (1, 2, 3))
for k in REG:
    print('  %-15s' % k + '  '.join('%3.0f ms: A %.3f B %.3f (A/B %.2f)' % (l * 33.3, ca[k][l], cb[k][l], ca[k][l] / cb[k][l]) for l in (1, 2, 3)))
# The same number of FRAMES apart (a frame-stepped effect would then be equal): 3 frames.
ca3, cb3 = change(A, sa, 1, (3,)), change(B, sb, 1, (3,))
for k in REG:
    print('  %-15s 3 frames apart (A %.1f ms, B %.1f ms): A %.3f B %.3f (A/B %.2f)' % (k, 3000 / A.fps, 3000 / B.fps, ca3[k][3], cb3[k][3], ca3[k][3] / cb3[k][3]))
