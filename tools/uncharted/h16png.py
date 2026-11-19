"""h16png.py OUT.png CROP(x0,y0,x1,y1|all) SCALE FILE.raw...: tshot captures of RGBA16F targets (u32 w, u32 h, half4) to
one contact sheet, each tone-mapped (x / (1 + x), then gamma 1/2.2) and cropped; SCALE resizes each tile."""
import struct, sys, numpy as np
from PIL import Image, ImageDraw
out, crop, scale = sys.argv[1], sys.argv[2], float(sys.argv[3])
tiles = []
for path in sys.argv[4:]:
    d = open(path, 'rb').read(); w, h = struct.unpack('<II', d[:8])
    if (len(d) - 8) == w * h * 4: w //= 2  # SaveImage writes 8-byte texels as a width twice the real one
    a = np.frombuffer(d[8:8 + w * h * 8], np.float16).reshape(h, w, 4)[..., :3].astype(np.float32)
    if crop != 'all':
        x0, y0, x1, y1 = [int(v) for v in crop.split(',')]; a = a[y0:y1, x0:x1]
    a = np.nan_to_num(np.clip(a, 0, 1e4)); a = (a / (1 + a)) ** (1 / 2.2)
    im = Image.fromarray((a * 255).astype(np.uint8))
    im = im.resize((int(im.width * scale), int(im.height * scale)))
    ImageDraw.Draw(im).text((4, 4), path.replace('\\', '/').split('/')[-1][6:20], fill=(255, 255, 0))
    tiles.append(im)
cols = min(4, len(tiles)); rows = (len(tiles) + cols - 1) // cols
tw, th = tiles[0].size
sheet = Image.new('RGB', (tw * cols, th * rows))
for i, t in enumerate(tiles): sheet.paste(t, ((i % cols) * tw, (i // cols) * th))
sheet.save(out)
