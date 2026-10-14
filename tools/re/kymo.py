"""kymo.py DIR F0 F1 X...: x-t strips of a RPCS3_DLSS_SEQ dump: for each output column X (and the matching input column,
scaled), the column's pixels over frames F0..F1 side by side (time left to right, 6 px a frame). Vertical jumps show as
steps. Writes DIR_kymo.png (per X: input | output)."""
import sys, os, numpy as np
from PIL import Image
d = sys.argv[1]; f0, f1 = int(sys.argv[2]), int(sys.argv[3]); xs = [int(v) for v in sys.argv[4:]]
w, h, iw, ih, fo, fi = map(int, open(os.path.join(d, 'seq.txt')).read().split())
def load(i, k, ww, hh, bgra): a = np.frombuffer(open(f'{d}/seq.{i:03d}.{k}', 'rb').read(), np.uint8).reshape(hh, ww, 4)[:, :, :3]; return a[:, :, ::-1] if bgra else a
n = f1 - f0 + 1; S = 6; strips = []
for x in xs:
    xi = int(x * iw / w)
    A = np.zeros((h, n * S, 3), np.uint8); Bo = np.zeros((h, n * S, 3), np.uint8)
    for k, t in enumerate(range(f0, f1 + 1)):
        col_in = load(t, 'in', iw, ih, fi == 44)[:, xi]
        col_in = np.array(Image.fromarray(col_in[:, None, :]).resize((1, h), Image.BILINEAR))[:, 0]
        A[:, k * S:(k + 1) * S] = col_in[:, None]; Bo[:, k * S:(k + 1) * S] = load(t, 'out', w, h, fo == 44)[:, x][:, None]
    strips += [A, np.zeros((h, 8, 3), np.uint8) + 255, Bo, np.zeros((h, 24, 3), np.uint8)]
Image.fromarray(np.concatenate(strips, 1)).save(d + '_kymo.png')
