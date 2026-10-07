"""findproj3.py [ASPECT=1.777778]: live memory (pine): f32 pairs x at +0 and x*ASPECT at +20 (a 4x4 projection's
diagonal, P00 and P11), x in 0.3..5; prints address, P00, P11, and the 16 floats."""
import sys, struct, os
import numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from pine import Pine
asp = float(sys.argv[1]) if len(sys.argv) > 1 else 16/9
p = Pine(); CH = 0x100000
for lo, hi in [(0x10000, 0x10000000), (0x30000000, 0x40000000)]:
    for base in range(lo, hi, CH):
        data, missing = p.dump(base, CH)
        if len(missing) * 4096 >= CH: continue
        f = np.frombuffer(data[:len(data)//4*4], dtype='>f4').astype(np.float64)
        a = f[:-5]; b = f[5:]
        with np.errstate(all='ignore'):
            ok = (a > 0.3) & (a < 5) & (np.abs(b / a / asp - 1) < 2e-4)
        for i in np.nonzero(ok)[0][:20]:
            m = f[i:i+16]
            print(hex(base + 4*i), '%.5f %.5f' % (a[i], b[i]), ' '.join('%.4g' % v for v in m))
