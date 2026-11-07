"""flashtop.py NAME: from rec100.py's saved frames (out/NAME/NNN.png): the 4 biggest one-frame flashes, each as before, flash, after, close up: out/NAME_top.png. A frame's biggest block only, skipping neighbours of one already shown."""
import glob
import sys

import numpy as np
from PIL import Image

name = sys.argv[1]
O = 'H:/PGR4-ReGPU/out/'
fs = sorted(glob.glob(O + name + '/[0-9]*.png'))
st = np.stack([np.asarray(Image.open(f).convert('RGB'), dtype=np.int16) for f in fs])
res = []
for i in range(1, len(fs) - 1):
    j = np.minimum(np.abs(st[i] - st[i - 1]).max(axis=2), np.abs(st[i] - st[i + 1]).max(axis=2))
    a = np.abs(st[i - 1] - st[i + 1]).max(axis=2)
    m = (j > 12) & (a < 8)
    h, w = m.shape
    b = m[:h // 16 * 16, :w // 16 * 16].reshape(h // 16, 16, w // 16, 16).sum(axis=(1, 3))
    y, x = np.unravel_index(np.argmax(b), b.shape)
    res.append((int(b[y, x]), i, int(x) * 16, int(y) * 16))
res.sort(reverse=True)
shown = []
for r in res:
    if all(abs(r[1] - s[1]) > 2 for s in shown):
        shown.append(r)
    if len(shown) == 4:
        break
print(shown)
h, w = st[0].shape[:2]
m = Image.new('RGB', (1800, 1800))
for n, (s, i, x, y) in enumerate(shown[:4]):
    box = (max(0, x - 70), max(0, y - 70), min(w, x + 86), min(h, y + 86))
    for c, fi in enumerate([i - 1, i, i + 1]):
        m.paste(Image.fromarray(np.uint8(st[fi])).crop(box).resize((600, 450), Image.NEAREST), (600 * c, 450 * n))
m.save(O + name + '_top.png')
