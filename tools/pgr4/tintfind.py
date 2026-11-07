"""tintfind.py TRACE OUTPREFIX: with the game running: every pixel shader of the trace that blends (and is not plainly the HUD's font), tinted magenta one at a time: a shot of each and where the magenta landed. To find which shader draws something on the screen."""
import re
import subprocess
import sys

import numpy as np
from PIL import Image

trace, out = sys.argv[1], sys.argv[2]
PG = ['sh', 'F:/rpsc3/source/plans/tools/pgr4/pg.sh']
shaders = {}
for line in open(trace, errors='replace'):
    m = re.search(r'draw #\d+ vs ([0-9a-f]{16}) ps ([0-9a-f]{16}) prim (\d+) n \d+ blend ([0-9a-f]{8}).* wide (\d)', line)
    if m and m.group(4) != '00010001' and m.group(5) == '1':
        key = m.group(2)
        s = shaders.setdefault(key, {'n': 0, 'vs': m.group(1), 'blend': m.group(4)})
        s['n'] += 1


def pg(*a):
    return subprocess.run(PG + list(a), capture_output=True, text=True).stdout


print(len(shaders), 'blending pixel shaders')
for ps, s in sorted(shaders.items(), key=lambda kv: -kv[1]['n']):
    pg('ps', ps, 'tint', '1,0,1')
    pg('wait', '6')
    path = '%s_%s.png' % (out, ps[-8:])
    pg('shot', path)
    pg('ps', ps)
    a = np.asarray(Image.open(path).convert('RGB'), dtype=np.int16)
    m = (a[:, :, 0] > 120) & (a[:, :, 1] < 70) & (a[:, :, 2] > 120)
    ys, xs = np.nonzero(m)
    box = '%d-%d x %d-%d' % (xs.min(), xs.max(), ys.min(), ys.max()) if len(xs) else '-'
    print('ps %s vs %s blend %s draws %d: magenta %d, box %s' % (ps[-8:], s['vs'][-8:], s['blend'], s['n'], len(xs), box), flush=True)
    if not len(xs):
        import os
        os.remove(path)
