import sys, glob
from PIL import Image
n, cols = sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 4
fs = sorted(glob.glob(n + '_s*.png')) + sorted(glob.glob(n + '_c*.full.png')); fs = [f for f in fs if 'sheet' not in f and (f.endswith('.full.png') or 'full' not in f)]
ims = [Image.open(f).convert('RGB') for f in fs]
w = 480; ims = [i.resize((w, int(i.height * w / i.width))) for i in ims]; h = max(i.height for i in ims)
rows = (len(ims) + cols - 1) // cols
s = Image.new('RGB', (w * cols, h * rows))
for k, i in enumerate(ims): s.paste(i, ((k % cols) * w, (k // cols) * h))
s.save(n + '_sheet.png'); print(len(ims), s.size)
