"""eyecrops.py OUT.png X0,Y0,X1,Y1 SCALE FILE.raw...: eye dumps (u32 w, u32 h, RGBA8) cropped, brightened (gamma 0.45),
labelled and laid out four to a row."""
import struct, sys, numpy as np
from PIL import Image, ImageDraw
out, box, scale = sys.argv[1], [int(v) for v in sys.argv[2].split(',')], float(sys.argv[3])
tiles = []
for path in sys.argv[4:]:
    d = open(path, 'rb').read(); w, h = struct.unpack('<II', d[:8])
    a = np.frombuffer(d[8:8 + w * h * 4], np.uint8).reshape(h, w, 4)[box[1]:box[3], box[0]:box[2], :3]
    im = Image.fromarray(a).point(lambda v: min(255, int(255 * (v / 255) ** 0.45)))
    im = im.resize((int(im.width * scale), int(im.height * scale)))
    ImageDraw.Draw(im).text((4, 4), path.replace('\\', '/').split('/')[-1], fill=(255, 255, 0))
    tiles.append(im)
cols = min(4, len(tiles)); rows = (len(tiles) + cols - 1) // cols
tw, th = tiles[0].size
sheet = Image.new('RGB', (tw * cols, th * rows))
for i, t in enumerate(tiles): sheet.paste(t, ((i % cols) * tw, (i // cols) * th))
sheet.save(out)
