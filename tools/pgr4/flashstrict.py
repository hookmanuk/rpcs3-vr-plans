"""flashstrict.py NAME: from rec100.py's frames: one-frame flashes only where the picture is steady for 3 frames each side of it (scenery moving past doesn't count). Lists them; close-ups of the biggest in out/NAME_strict.png, before / flash / after."""
import glob
import sys

import numpy as np
from PIL import Image

name = sys.argv[1]
O = 'H:/PGR4-ReGPU/out/'
fs = sorted(glob.glob(O + name + '/[0-9]*.png'))
st = np.stack([np.asarray(Image.open(f).convert('RGB'), dtype=np.int16) for f in fs])
res = []
for i in range(3, len(fs) - 3):
    around = st[[i - 3, i - 2, i - 1, i + 1, i + 2, i + 3]]
    steady = (around.max(axis=0) - around.min(axis=0)).max(axis=2) < 14
    near = np.median(around, axis=0)
    m = (np.abs(st[i] - near).max(axis=2) > 14) & steady
    h, w = m.shape
    b = m[:h // 16 * 16, :w // 16 * 16].reshape(h // 16, 16, w // 16, 16).sum(axis=(1, 3))
    y, x = np.unravel_index(np.argmax(b), b.shape)
    res.append((int(b[y, x]), int(m.sum()), i, int(x) * 16, int(y) * 16))
res.sort(reverse=True)
print('%s: %d frames; with a steady block over 60 pixels: %d, over 120: %d; biggest (block, total, frame, x, y): %s' % (name, len(res), sum(1 for r in res if r[0] > 60), sum(1 for r in res if r[0] > 120), res[:6]))
h, w = st[0].shape[:2]
m = Image.new('RGB', (1800, 1800))
shown = []
for r in res:
    if all(abs(r[2] - s[2]) > 2 for s in shown):
        shown.append(r)
    if len(shown) == 4:
        break
for n, (s, t, i, x, y) in enumerate(shown):
    box = (max(0, x - 70), max(0, y - 70), min(w, x + 86), min(h, y + 86))
    for c, fi in enumerate([i - 1, i, i + 1]):
        m.paste(Image.fromarray(np.uint8(st[fi])).crop(box).resize((600, 450), Image.NEAREST), (600 * c, 450 * n))
m.save(O + name + '_strict.png')
