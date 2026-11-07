"""eadiff.py TAG: earlyab.sh's shots: pixels that differ (early against none, and the control), and a montage of where."""
import sys

import numpy as np
from PIL import Image

tag = sys.argv[1]
O = 'H:/PGR4-ReGPU/out/ea_%s_' % tag
m = Image.new('RGB', (1500, 1000))
for r, sc in enumerate(('stp', 'tokyo')):
    L = lambda n: np.asarray(Image.open(O + sc + '_' + n + '.png').convert('RGB'), dtype=np.int16)
    a, b, c = L('none'), L('early'), L('none2')
    d = np.abs(a - b).max(axis=2) > 20
    k = np.abs(a - c).max(axis=2) > 20
    print('%s: early vs none %d px differ, control %d' % (sc, d.sum(), k.sum()))
    for i, x in enumerate((a, b)):
        m.paste(Image.fromarray(np.uint8(x)).resize((500, 500)), (i * 500, r * 500))
    m.paste(Image.fromarray(d.astype(np.uint8) * 255).convert('RGB').resize((500, 500)), (1000, r * 500))
m.save(O + 'cmp.png')
