"""lenscheck.py OFF_A.raw ON.raw OFF_B.raw [TAN_X=1.1155] [TAN_Y=1.0355] [R=1.035]: eye dumps (dev trigger EYES,
eye_0.raw: u32 width, u32 height, RGBA8) with the lens skip off, on, and off again. Inside the lens circle (radius R in
view tangents, the image's edge at TAN_X / TAN_Y) the on frame must differ from the off ones no more than they differ
from each other (the scene moves between shots: snow, fire). Prints mean |difference| per pixel inside and outside,
and the share of inside pixels off by more than 24 levels. Writes a sheet beside ON.raw."""
import struct, sys
import numpy as np
from PIL import Image


def load(p):
    d = open(p, 'rb').read()
    w, h = struct.unpack('<II', d[:8])
    return np.frombuffer(d[8:8 + w * h * 4], np.uint8).reshape(h, w, 4)[:, :, :3].astype(np.int16)


a, on, b = (load(p) for p in sys.argv[1:4])
tx = float(sys.argv[4]) if len(sys.argv) > 4 else 1.1155
ty = float(sys.argv[5]) if len(sys.argv) > 5 else 1.0355
r = float(sys.argv[6]) if len(sys.argv) > 6 else 1.035
h, w = a.shape[:2]
x = ((np.arange(w) + 0.5) / w * 2 - 1) * tx
y = ((np.arange(h) + 0.5) / h * 2 - 1) * ty
X, Y = np.meshgrid(x, y)
inside = X * X + Y * Y <= r * r
for name, p, q in (('off vs off (control)', a, b), ('on vs off A', on, a), ('on vs off B', on, b)):
    d = np.abs(p - q).max(axis=2)
    print(f'{name:22s} inside: mean {d[inside].mean():.3f}, over 24 {100 * (d[inside] > 24).mean():.3f}% | '
          f'outside: mean {d[~inside].mean():.3f}')
sheet = np.concatenate([a, on, np.clip(np.abs(on - a).max(axis=2, keepdims=True) * 4, 0, 255).repeat(3, 2)], axis=1)
Image.fromarray(sheet.astype(np.uint8)).resize((3 * w // 4, h // 4)).save(sys.argv[2][:-4] + '_sheet.png')
