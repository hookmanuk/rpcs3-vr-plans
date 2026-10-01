"""rcpaused.py SHOT: exit 0 if the R&C pause menu is showing (Veldin start: the centre goes dark grey under the menu)."""
import sys, numpy as np
from PIL import Image
a = np.asarray(Image.open(sys.argv[1]).convert('RGB')).astype(int); h, w, _ = a.shape
m = a[int(h * .08):int(h * .75), int(w * .36):int(w * .64)].reshape(-1, 3).mean(0)
print('centre mean', m.round(1)); sys.exit(0 if m[0] < 45 and abs(m[0] - m[2]) < 8 else 1)
