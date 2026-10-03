"""shot.py ID [out] [width] [crop x0,y0,x1,y1 fractions]: RPCS3 screenshot via the SHOT trigger; saves scratchpad/<out>.png (resized) and <out>.full.png
Env SHOT_MOVE=1: the screenshot leaves bin/screenshots/ID once copied (scripted runs at 300% wrote ~20 MB each there)."""
import sys, os, glob, time, shutil, subprocess
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
tid = sys.argv[1]
out = sys.argv[2] if len(sys.argv) > 2 else 'shot'
w = int(sys.argv[3]) if len(sys.argv) > 3 else 960
crop = tuple(map(float, sys.argv[4].split(','))) if len(sys.argv) > 4 and sys.argv[4] != '-' else None
wait = float(sys.argv[5]) if len(sys.argv) > 5 else 0
time.sleep(wait)
d = rf'F:\rpsc3\source\rpcs3\bin\screenshots\{tid}'
os.makedirs(d, exist_ok=True)
before = set(glob.glob(d + r'\*.png'))
open(os.path.join(os.environ['TEMP'], 'rpcs3-vrprofile', 'SHOT'), 'w').close()
new = None
for _ in range(240):  # a screenshot can take ~20 s while shaders compile
    n = set(glob.glob(d + r'\*.png')) - before
    if n:
        new = max(n, key=os.path.getmtime)
        break
    time.sleep(0.25)
if not new:
    print('no screenshot'); sys.exit(1)
time.sleep(0.7)
full = os.path.join(HERE, out + '.full.png')
for _ in range(40):
    try:
        shutil.copy(new, full)
        im = Image.open(full); im.load()
        break
    except (PermissionError, OSError):
        time.sleep(0.25)
print(im.size, new)
if os.environ.get('SHOT_MOVE') == '1':
    try:
        os.remove(new)
    except OSError:
        pass
if crop:
    im = im.crop((int(crop[0] * im.width), int(crop[1] * im.height), int(crop[2] * im.width), int(crop[3] * im.height)))
im.resize((w, im.height * w // im.width)).save(os.path.join(HERE, out + '.png'))
print(subprocess.run(['powershell', '-c', '(Get-Process rpcs3).MainWindowTitle'], capture_output=True, text=True).stdout.strip())
