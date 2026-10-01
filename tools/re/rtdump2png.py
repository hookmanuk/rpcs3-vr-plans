"""rtdump2png.py PREFIX OUT: convert RPCS3_VR_RTDUMP raw dumps (PREFIX.<n>.<addr>.left/right + .txt) to PNG.
Writes OUT_<addr>_<eye>.png next to this script for every dump matching PREFIX*. Colour: 4-byte BGRA/RGBA
(format id from the .txt; 44/50 = B8G8R8A8, else R8G8B8A8) or 8-byte RGBA16F."""
import glob, os, sys
import numpy as np
from PIL import Image
prefix, out = sys.argv[1], sys.argv[2]
here = os.path.dirname(os.path.abspath(__file__))
for txt in sorted(glob.glob(prefix + '*.txt')):
    raw = txt[:-4]
    w, h, fmt = (int(x) for x in open(txt).read().split())
    data = np.fromfile(raw, dtype=np.uint8)
    texel = len(data) // (w * h)
    parts = os.path.basename(raw).split('.')
    addr, eye = parts[-2], parts[-1]
    if texel == 8:
        img = np.clip(data.view(np.float16).reshape(h, w, 4).astype(np.float32), 0, 1) * 255
        img = img.astype(np.uint8)[:, :, :3]
    else:
        img = data.reshape(h, w, 4)
        img = img[:, :, [2, 1, 0]] if fmt in (44, 50) else img[:, :, :3]
    Image.fromarray(img).save(os.path.join(here, '%s_%s_%s.png' % (out, addr, eye)))
    print(addr, eye, w, h, fmt, texel)
