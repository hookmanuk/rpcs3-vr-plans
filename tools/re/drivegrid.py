"""drivegrid.py DIR STEP,STEP [OUT.png]: drive.sh results, one row per step: the flat frame beside the headset left eye."""
import sys, os
from PIL import Image
import glob
d = sys.argv[1]; names = sys.argv[2].split(',')
rows = []
for n in names:
    f = Image.open(os.path.join(d, 'flat_%s.png' % n)).convert('RGB').resize((640, 360))
    s = Image.open(os.path.join(d, 'sim_%s.png' % n)).convert('RGB'); s = s.crop((0, 0, s.width // 2, s.height)); s = s.resize((int(s.width * 360 / s.height), 360))
    rows.append((f, s))
W = 640 + 6 + rows[0][1].width
o = Image.new('RGB', (W, 366 * len(rows)), (255, 0, 255))
for i, (f, s) in enumerate(rows): o.paste(f, (0, i * 366)); o.paste(s, (646, i * 366))
out = sys.argv[3] if len(sys.argv) > 3 else os.path.join(d, 'grid.png'); o.save(out); print(out, o.size)
