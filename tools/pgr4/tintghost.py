"""tintghost.py TRACE BASE.png X0 Y0 X1 Y1: with the game running on a still scene: finds which pixel shader draws what is in that box (fractions of the picture) by tinting each shader of the trace in turn, and printing the ones that change the box's pixels."""
import re
import subprocess
import sys

import numpy as np
from PIL import Image

trace, base = sys.argv[1], sys.argv[2]
fx0, fy0, fx1, fy1 = (float(v) for v in sys.argv[3:7])
PG = ['sh', 'F:/rpsc3/source/plans/tools/pgr4/pg.sh']


def pg(*a):
    return subprocess.run(PG + list(a), capture_output=True, text=True).stdout


shaders = {}
for line in open(trace, errors='replace'):
    m = re.search(r'draw #\d+ vs ([0-9a-f]{16}) ps ([0-9a-f]{16}) ', line)
    if m:
        shaders.setdefault(m.group(2), m.group(1))
a0 = np.asarray(Image.open(base).convert('RGB'), dtype=np.int16)
h, w = a0.shape[:2]
box = (int(fx0 * w), int(fy0 * h), int(fx1 * w), int(fy1 * h))
region = a0[box[1]:box[3], box[0]:box[2]]
print(len(shaders), 'pixel shaders; box', box, flush=True)
for ps, vs in shaders.items():
    pg('ps', ps, 'tint', '1,0,1')
    pg('wait', '4')
    pg('shot', 'H:/PGR4-ReGPU/out/tg.png')
    pg('ps', ps)
    a = np.asarray(Image.open('H:/PGR4-ReGPU/out/tg.png').convert('RGB'), dtype=np.int16)[box[1]:box[3], box[0]:box[2]]
    changed = int((np.abs(a - region).max(axis=2) > 30).sum())
    if changed > 8:
        print('ps %s vs %s: %d pixels of the box change' % (ps, vs, changed), flush=True)
