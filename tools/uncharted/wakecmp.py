"""wakecmp.py RING_A.raw RING_B.raw OUT.png [PHASES_MS=300,500,700,900,1100,1300]: two flash rings of the same scripted
walk (ripplering.sh WALKING=1) at two frame rates, lined up by the moment the walk starts (the first frame the picture
moves), shown side by side (A left, B right) at equal real times after it: the left eye's lower middle, brightened.
Prints, per phase, the share of bright foam pixels in that region for each (the wake's size): a wake whose life is
counted in frames is 1.5 times as long-lived at 60 FPS as at 90; one that follows the clock is the same."""
import struct, sys, numpy as np
from PIL import Image, ImageDraw
phases = [float(v) for v in (sys.argv[4] if len(sys.argv) > 4 else '300,500,700,900,1100,1300').split(',')]
Y0, Y1, X0, X1 = 0.42, 0.80, 0.15, 0.85


class Ring:
    def __init__(self, path):
        self.f = open(path, 'rb')
        self.w, self.h, self.n = struct.unpack('<III', self.f.read(12))
        self.size = self.w * self.h * 4
        self.f.seek(12 + self.size * self.n)
        self.t = np.frombuffer(self.f.read(8 * self.n), np.uint64).astype(np.float64) / 1e3
        self.t -= self.t[0]
        self.fps = 1000 / np.median(np.diff(self.t))

    def frame(self, i):
        self.f.seek(12 + self.size * i)
        e = self.w // 2
        return np.frombuffer(self.f.read(self.size), np.uint8).reshape(self.h, self.w, 4)[:, :e, :3]

    def start(self):
        # The walk starts: the first frame from which the picture keeps changing (mean difference of small frames).
        small = [self.frame(i)[::8, ::8].astype(np.float32).mean(2) for i in range(self.n)]
        d = np.array([np.abs(small[i] - small[i - 1]).mean() for i in range(1, self.n)])
        base = np.median(d[:max(10, self.n // 8)])
        for i in range(len(d) - 12):
            if (d[i:i + 12] > base * 3 + 0.5).all():
                return self.t[i + 1]
        return 0.0

    def at(self, ms):
        return self.frame(int(np.argmin(np.abs(self.t - ms))))


rings = [Ring(sys.argv[1]), Ring(sys.argv[2])]
starts = [r.start() for r in rings]
print('walk starts: A %.0f ms (%.1f FPS), B %.0f ms (%.1f FPS)' % (starts[0], rings[0].fps, starts[1], rings[1].fps))
tiles = []
for p in phases:
    row = []
    for r, s in zip(rings, starts):
        f = r.at(s + p)
        h, e = f.shape[:2]
        c = f[int(h * Y0):int(h * Y1), int(e * X0):int(e * X1)].astype(np.float32)
        lum = c.mean(2)
        # Foam: bright and yellowish against the dark water (red and green well over blue).
        foam = (lum > 70) & (c[..., 0] > c[..., 2] * 1.25)
        row.append((c, foam.mean()))
    print('  +%4.0f ms: foam A %.3f  B %.3f  (B / A %.2f)' % (p, row[0][1], row[1][1], row[1][1] / max(row[0][1], 1e-6)))
    tiles.append(row)
th, tw = tiles[0][0][0].shape[:2]
sheet = Image.new('RGB', (tw * 2 + 6, th * len(tiles)))
for y, (p, row) in enumerate(zip(phases, tiles)):
    for x, (c, share) in enumerate(row):
        im = Image.fromarray(np.clip(c * 2.5, 0, 255).astype(np.uint8))
        ImageDraw.Draw(im).text((4, 4), '%s %.0f FPS  +%.0f ms' % ('AB'[x], rings[x].fps, p), fill=(255, 255, 0))
        sheet.paste(im, (x * (tw + 6), y * th))
sheet.save(sys.argv[3])
