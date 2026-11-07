"""earlybisect.py X0 Y0 X1 Y1 [MAXDRAW]: with the game running on a frozen frame (paused), finds the draws whose early-depth variant
changes the box (fractions of the picture), by REGPU_EARLY_RANGE (renderer.cpp, a test build): early depth for draws a-b only.
Reference: no early depth at all (range 0-0). Prints each step and the draws found."""
import subprocess
import sys

import numpy as np
from PIL import Image

fx0, fy0, fx1, fy1 = (float(v) for v in sys.argv[1:5])
top = int(sys.argv[5]) if len(sys.argv) > 5 else 6000
PG = ['sh', 'F:/rpsc3/source/plans/tools/pgr4/pg.sh']


def pg(*a):
    return subprocess.run(PG + list(a), capture_output=True, text=True).stdout


def shot(rng):
    pg('env', 'REGPU_EARLY_RANGE', rng)
    pg('wait', '3')
    pg('shot', 'H:/PGR4-ReGPU/out/eb.png')
    a = np.asarray(Image.open('H:/PGR4-ReGPU/out/eb.png').convert('RGB'), dtype=np.int16)
    h, w = a.shape[:2]
    return a[int(fy0 * h):int(fy1 * h), int(fx0 * w):int(fx1 * w)]


ref = shot('0-0')
again = shot('0-0')
noise = int((np.abs(ref - again).max(axis=2) > 20).sum())
full = int((np.abs(shot('0-%d' % top) - ref).max(axis=2) > 20).sum())
print('noise %d px, all early %d px' % (noise, full), flush=True)


def bad(a, b):
    n = int((np.abs(shot('%d-%d' % (a, b)) - ref).max(axis=2) > 20).sum())
    print('  draws %d-%d: %d px differ' % (a, b, n), flush=True)
    return n > max(50, noise * 3)


def find(a, b, out):
    if not bad(a, b):
        return
    if b - a <= 0:
        out.append(a)
        return
    m = (a + b) // 2
    find(a, m, out)
    find(m + 1, b, out)
    if len(out) > 12:
        return


found = []
find(0, top, found)
print('draws:', found)
pg('env', 'REGPU_EARLY_RANGE', '')
