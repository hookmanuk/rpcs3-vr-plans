"""simshot.py OUT [width]: screenshot of what the OpenXR Simulator composited (both eyes, as the headset would show),
via its screenshot_request.json; saves OUT.png (resized) and OUT.full.png next to this script."""
import json, os, sys, time
from PIL import Image
d = os.path.join(os.environ['LOCALAPPDATA'], 'OpenXR-Simulator')
out = sys.argv[1]; w = int(sys.argv[2]) if len(sys.argv) > 2 else 960
bmp = os.path.join(d, 'screenshot.bmp')
before = os.path.getmtime(bmp) if os.path.exists(bmp) else 0
tmp = os.path.join(d, 'screenshot_request.json.tmp')
with open(tmp, 'w') as f: json.dump({'eye': 'both'}, f)
os.replace(tmp, os.path.join(d, 'screenshot_request.json'))
for _ in range(100):
    time.sleep(0.1)
    if os.path.exists(bmp) and os.path.getmtime(bmp) > before:
        time.sleep(0.3)
        break
else:
    sys.exit('no simulator screenshot (is a headset session running?)')
img = Image.open(bmp).convert('RGB')
here = os.path.dirname(os.path.abspath(__file__))
img.save(os.path.join(here, out + '.full.png'))
img.resize((w, max(1, int(img.height * w / img.width)))).save(os.path.join(here, out + '.png'))
print(img.size)
