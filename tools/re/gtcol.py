"""gtcol.py SHOT: count saturated red and green pixels in the lower middle band of each eye (car shadows)."""
import sys, numpy as np
from PIL import Image
a = np.asarray(Image.open(sys.argv[1]).convert('RGB')).astype(int); h, w, _ = a.shape; hw = w // 2
for name, e in (('L', a[:, :hw]), ('R', a[:, hw:])):
    b = e[int(h * .35):int(h * .7)]
    red = ((b[..., 0] > 110) & (b[..., 1] < 50) & (b[..., 2] < 50)).sum()
    grn = ((b[..., 1] > 70) & (b[..., 0] < 40) & (b[..., 2] < 60) & (b[..., 1] > b[..., 2] + 30)).sum()
    blu = ((b[..., 2] > 90) & (b[..., 0] < 40) & (b[..., 1] < 60)).sum()
    print(f'{name}: red {red} green {grn} blue {blu}', end='  ')
print()
