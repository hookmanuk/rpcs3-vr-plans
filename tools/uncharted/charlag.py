"""charlag.py REF.raw DUMP.raw... : does a character sit where the world is? REF is a left-eye dump with the head still;
each DUMP was taken while the head swept. A patch on the character (Drake, picture centre) and patches of the scenery
around him are found again in each dump (normalised correlation, quarter size); printed per dump: the scenery's shift,
and the character's shift minus the scenery's (px at full size). With a pure head turn both move alike: a difference
of tens of px is a character drawn with another head pose than the world (the "double image")."""
import sys, numpy as np
N = 2880; K = 4; n = N // K
ld = lambda p: np.fromfile(p, np.uint8)[8:8 + N * N * 4].reshape(N, N, 4)[::K, ::K, :3].astype(np.float32).mean(2)
ref = ld(sys.argv[1])
# patches (centre y, x, half size) at quarter size: the character, and scenery left / right / above him
P = {'char': (int(n * .60), int(n * .50), 40), 'left': (int(n * .50), int(n * .28), 40), 'right': (int(n * .50), int(n * .74), 40),
     'up': (int(n * .25), int(n * .50), 40)}
if len(sys.argv) > 2 and sys.argv[2].startswith('char='):
    y, x = (float(v) for v in sys.argv[2][5:].split(',')); P['char'] = (int(n * y), int(n * x), 40); del sys.argv[2]


def find(img, key):
    y, x, h = P[key]
    t = ref[y - h:y + h, x - h:x + h]; t = t - t.mean(); nt = np.sqrt((t * t).sum())
    best = (-1, 0, 0)
    for dy in range(-40, 41, 4):
        for dx in range(-200, 201, 2):
            yy, xx = y + dy, x + dx
            if yy - h < 0 or xx - h < 0 or yy + h > n or xx + h > n: continue
            w = img[yy - h:yy + h, xx - h:xx + h]; w = w - w.mean()
            c = (t * w).sum() / (nt * np.sqrt((w * w).sum()) + 1e-6)
            if c > best[0]: best = (c, dx, dy)
    return best


worst = 0
for p in sys.argv[2:]:
    img = ld(p); r = {k: find(img, k) for k in P}
    world = [r[k][1] for k in ('left', 'right', 'up') if r[k][0] > 0.6]
    if not world or r['char'][0] < 0.6:
        print('%s: no match (char %.2f)' % (p[-22:], r['char'][0])); continue
    w = float(np.median(world)); d = (r['char'][1] - w) * K; worst = max(worst, abs(d))
    print('%s: scenery %+5.0f px, character - scenery %+4.0f px (corr %.2f)' % (p[-22:], w * K, d, r['char'][0]))
print('worst %d px' % worst)
