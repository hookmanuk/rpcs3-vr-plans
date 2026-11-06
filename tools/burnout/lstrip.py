import sys
from PIL import Image, ImageDraw
out = sys.argv[1]; items = sys.argv[2:]
ims = []
for f in items:
    i = Image.open(f + '.full.png').convert('RGB'); i = i.crop((0, 0, i.width // 2, i.height)); i = i.resize((640, int(640 * i.height / i.width)))
    ImageDraw.Draw(i).text((6, 6), f, fill=(0, 255, 0)); ims.append(i)
h = ims[0].height; s = Image.new('RGB', (1920, h * ((len(ims) + 2) // 3)))
for k, i in enumerate(ims): s.paste(i, ((k % 3) * 640, (k // 3) * h))
s.save(out); print(s.size)
