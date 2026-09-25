"""blips.py DIR: compare a burst of VR shots of a still scene against their median; print outliers."""
import sys, glob
import numpy as np
from PIL import Image
fs = sorted(glob.glob(sys.argv[1] + '/*.png'))
ims = [np.asarray(Image.open(f).convert('L').resize((640, 180)), dtype=np.int16) for f in fs]
med = np.median(np.stack(ims), axis=0)
for f, im in zip(fs, ims):
    frac = float((np.abs(im - med) > 40).mean())
    print(f'{f[-7:]} {frac:.4f}' + ('  <<<' if frac > 0.003 else ''))
Image.fromarray(med.astype(np.uint8)).save(sys.argv[1] + '/median.png')
