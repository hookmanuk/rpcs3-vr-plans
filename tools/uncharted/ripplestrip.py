"""ripplestrip.py RING.raw OUT.png [STEP_MS=100] [Y0 Y1 X0 X1 fractions of the left eye, default the whole eye]
[START_MS=0] [COUNT=12]: a strip of the left eye's region every STEP_MS of real time through a flash ring (consecutive
frames with their times), each labelled with its time from the ring's start in ms: how fast something moves on
screen in real time, to compare two frame rates by eye. Prints the ring's frame rate."""
import struct, sys, numpy as np
from PIL import Image, ImageDraw
path, out = sys.argv[1], sys.argv[2]
step = float(sys.argv[3]) if len(sys.argv) > 3 else 100.0
f = [float(v) for v in sys.argv[4:8]] if len(sys.argv) > 7 else [0, 1, 0, 1]
start = float(sys.argv[8]) if len(sys.argv) > 8 else 0.0
count = int(sys.argv[9]) if len(sys.argv) > 9 else 12
with open(path, 'rb') as fh:
    w, h, n = struct.unpack('<III', fh.read(12))
    size = w * h * 4
    fh.seek(12 + size * n)
    times = np.frombuffer(fh.read(8 * n), np.uint64).astype(np.float64) / 1e3
    times = times - times[0]
    print('%d frames of %dx%d, %.1f FPS, %.0f ms' % (n, w, h, 1000 / np.median(np.diff(times)), times[-1]))
    e = w // 2
    y0, y1, x0, x1 = int(h * f[0]), int(h * f[1]), int(e * f[2]), int(e * f[3])
    tiles = []
    for k in range(count):
        t = start + k * step
        if t > times[-1]: break
        i = int(np.argmin(np.abs(times - t)))
        fh.seek(12 + size * i)
        frame = np.frombuffer(fh.read(size), np.uint8).reshape(h, w, 4)[y0:y1, x0:x1, :3]
        gain = float(__import__('os').environ.get('GAIN', '1'))  # GAIN=3: dark scenes brightened
        im = Image.fromarray(np.clip(frame.astype(np.float32) * gain, 0, 255).astype(np.uint8))
        s = 360 / im.width
        im = im.resize((360, int(im.height * s)), Image.LANCZOS)
        ImageDraw.Draw(im).text((4, 4), '%.0f ms' % times[i], fill=(255, 255, 0))
        tiles.append(im)
cols = 6
rows = (len(tiles) + cols - 1) // cols
sheet = Image.new('RGB', (cols * 360, rows * tiles[0].height))
for k, im in enumerate(tiles):
    sheet.paste(im, ((k % cols) * 360, (k // cols) * tiles[0].height))
sheet.save(out)
