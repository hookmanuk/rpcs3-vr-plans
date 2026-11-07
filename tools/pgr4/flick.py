"""flick.py OUT.png SHOT...: frames of a still scene (paused): where they differ from each other. Prints the share of pixels that change and for each shot how far it is from the median; OUT.png: the first shot beside the changing pixels in white."""
import sys
import numpy as np
from PIL import Image

out = sys.argv[1]
shots = [np.asarray(Image.open(p).convert('RGB'), dtype=np.int16) for p in sys.argv[2:]]
stack = np.stack(shots)
median = np.median(stack, axis=0)
differ = np.abs(stack - median).max(axis=3) > 24
ever = differ.any(axis=0)
print('pixels that change: %.3f%% over %d shots' % (100 * ever.mean(), len(shots)))
print('per shot: ' + ' '.join('%.3f%%' % (100 * d.mean()) for d in differ))
ys, xs = np.nonzero(ever)
if len(xs):
    print('box of the changes: x %d-%d y %d-%d of %dx%d' % (xs.min(), xs.max(), ys.min(), ys.max(), ever.shape[1], ever.shape[0]))
h = 900
worst = int(np.argmax(differ.sum(axis=(1, 2))))
a = Image.fromarray(np.uint8(shots[worst])).resize((h, h))
b = Image.fromarray(np.uint8(ever) * 255).convert('RGB').resize((h, h))
m = Image.new('RGB', (2 * h, h))
m.paste(a, (0, 0))
m.paste(b, (h, 0))
m.save(out)
