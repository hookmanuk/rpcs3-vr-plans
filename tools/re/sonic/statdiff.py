# statdiff.py LO HI: words stable within each pair but different between frozen and working, f32-plausible
import sys, numpy as np, struct
sys.path.insert(0, '.')
from dmem import Dump
lo, hi = int(sys.argv[1], 16), int(sys.argv[2], 16)
D = {k: Dump('dumps/sd_' + k) for k in ('frz_a', 'frz_b', 'ok_a', 'ok_b')}
for a in range(lo, hi, 0x10000):
    try: w = {k: np.frombuffer(d.rd(a, min(0x10000, hi - a)), dtype='>u4') for k, d in D.items()}
    except KeyError: continue
    m = (w['frz_a'] == w['frz_b']) & (w['ok_a'] == w['ok_b']) & (w['frz_a'] != w['ok_a'])
    for i in np.nonzero(m)[0]:
        f, o = int(w['frz_a'][i]), int(w['ok_a'][i])
        ff, of = struct.unpack('>f', struct.pack('>I', f))[0], struct.unpack('>f', struct.pack('>I', o))[0]
        print('%08x frz %08x (%g) ok %08x (%g)' % (a + i * 4, f, ff, o, of))
