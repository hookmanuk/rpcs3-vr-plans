"""rtd2png.py BASE OUT: raw RTDUMP colour dump (BASE.left/.right + .txt: w h fmt, 4-byte texels) -> OUT.png, eyes side by side."""
import sys
from PIL import Image
base, out = sys.argv[1], sys.argv[2]
ims = []
for eye in ('left', 'right'):
    try:
        w, h, f = map(int, open(f'{base}.{eye}.txt').read().split())
    except FileNotFoundError:
        continue
    im = Image.frombytes('RGBA', (w, h), open(f'{base}.{eye}', 'rb').read()[:w * h * 4])
    r, g, b, a = im.split()
    ims.append(Image.merge('RGB', (b, g, r)) if f in (44, 50) else Image.merge('RGB', (r, g, b)))
c = Image.new('RGB', (sum(i.width for i in ims), ims[0].height))
x = 0
for i in ims:
    c.paste(i, (x, 0)); x += i.width
c.save(out)
