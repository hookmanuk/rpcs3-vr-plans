"""eyecmp.py: after a capture, each resolved image with a right-eye twin (out/res *_v100.png): left and right means."""
import glob, os
from PIL import Image
import numpy as np
os.chdir('H:/PGR4-ReGPU/out/res')
for f in sorted(glob.glob('*_v100.png')):
    g = f.replace('_v100', '_v0')
    if not os.path.exists(g):
        print(f, 'no left'); continue
    a = np.asarray(Image.open(g).convert('RGB')).astype(float)
    b = np.asarray(Image.open(f).convert('RGB')).astype(float)
    print('%-34s L %.1f R %.1f' % (f, a.mean(), b.mean()))
