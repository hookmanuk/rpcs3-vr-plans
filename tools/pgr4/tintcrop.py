"""tintcrop.py OUT.png X0 Y0 X1 Y1 HASH...: with the game running: each pixel shader tinted cyan in turn, the box (fractions of the picture) close up, in a montage: untinted first, then one per shader, in the order given."""
import subprocess
import sys

from PIL import Image

out = sys.argv[1]
fx0, fy0, fx1, fy1 = (float(v) for v in sys.argv[2:6])
hashes = sys.argv[6:]
PG = ['sh', 'F:/rpsc3/source/plans/tools/pgr4/pg.sh']


def pg(*a):
    return subprocess.run(PG + list(a), capture_output=True, text=True).stdout


def crop():
    pg('wait', '4')
    pg('shot', 'H:/PGR4-ReGPU/out/tc.png')
    a = Image.open('H:/PGR4-ReGPU/out/tc.png').convert('RGB')
    w, h = a.size
    return a.crop((int(fx0 * w), int(fy0 * h), int(fx1 * w), int(fy1 * h))).resize((600, 300))


cols = 3
rows = (len(hashes) + 1 + cols - 1) // cols
m = Image.new('RGB', (600 * cols, 300 * rows))
m.paste(crop(), (0, 0))
for i, h in enumerate(hashes):
    pg('ps', h, 'tint', '0,1,1')
    m.paste(crop(), (600 * ((i + 1) % cols), 300 * ((i + 1) // cols)))
    pg('ps', h)
    print(i + 1, h, flush=True)
m.save(out)
