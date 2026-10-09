"""sr_fit.py LOG: fits RSX-thread CPU ms/frame = a + b * draws/frame over the GPU profile lines (RPCS3_VR_GPUPROF=1)."""
import re, sys
import numpy as np
xs, ys, vr = [], [], []
for l in open(sys.argv[1], encoding='utf8', errors='ignore'):
    m = re.search(r'(\d+) draws/frame.*?left-eye constants ([0-9.]+).*?RSX thread CPU ([0-9.]+) ms/frame', l)
    if m and int(m.group(1)) > 500:
        xs.append(int(m.group(1))); vr.append(float(m.group(2))); ys.append(float(m.group(3)))
x, y = np.array(xs), np.array(ys)
b, a = np.polyfit(x, y, 1)
print(f'{len(x)} windows, draws {x.min()}-{x.max()}: CPU = {a:.2f} ms + {b*1000:.2f} us/draw; at 3500 draws {a+b*3500:.2f} ms; eye constants {np.mean(vr)/np.mean(x)*1000:.2f} us/draw')
