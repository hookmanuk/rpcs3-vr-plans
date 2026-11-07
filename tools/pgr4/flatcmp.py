"""flatcmp.py FLAT.png EYE.png TANL TANR TANU TAND [SX SY]: the VR eye image resampled to the flat game's view (same directions: flat
projection sx 1.0003, sy 1.7783 unless given), saved beside it, and the mean colour difference per grid cell of the flat frame."""
import sys
import numpy as np
from PIL import Image
flat, eye = sys.argv[1], sys.argv[2]
tl, tr, tu, td = (float(v) for v in sys.argv[3:7])
sx = float(sys.argv[7]) if len(sys.argv) > 7 else 1.0003
sy = float(sys.argv[8]) if len(sys.argv) > 8 else 1.7783
F = np.asarray(Image.open(flat).convert('RGB')).astype(float)
E = np.asarray(Image.open(eye).convert('RGB')).astype(float)
h, w = F.shape[:2]
H, W = E.shape[:2]
xs = (np.arange(w) + 0.5) / w * 2 - 1
ys = 1 - (np.arange(h) + 0.5) / h * 2
tx = xs / sx
ty = ys / sy
px = np.clip(((tx - tl) / (tr - tl) * W).astype(int), 0, W - 1)
py = np.clip(((tu - ty) / (tu - td) * H).astype(int), 0, H - 1)
R = E[py][:, px]
Image.fromarray(R.astype('uint8')).save(eye.rsplit('.', 1)[0] + '_flatview.png')
Image.fromarray(np.concatenate([F, R], axis=1).astype('uint8')).resize((1600, 450)).save(eye.rsplit('.', 1)[0] + '_cmp.png')
print('whole frame: flat %.1f VR %.1f' % (F.mean(), R.mean()))
for j, name in enumerate(('top', 'upper', 'lower', 'bottom')):
    row = []
    for i in range(6):
        a = F[j * h // 4:(j + 1) * h // 4, i * w // 6:(i + 1) * w // 6].mean(axis=(0, 1))
        b = R[j * h // 4:(j + 1) * h // 4, i * w // 6:(i + 1) * w // 6].mean(axis=(0, 1))
        row.append('%4.0f/%-4.0f' % (a.mean(), b.mean()))
    print('%-7s' % name, ' '.join(row))
