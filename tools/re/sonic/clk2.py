# clk2.py: f32/f64 clocks (rate 0.3..3 /s) in each pair, any address < 0x40000000; print both pairs side by side
import sys, numpy as np
sys.path.insert(0, '.')
def load(b):
    idx = np.fromfile(b + '.idx', dtype='<u4'); raw = np.memmap(b + '.bin', dtype=np.uint8, mode='r')
    return {int(p): k for k, p in enumerate(idx)}, raw, int(open(b + '.txt').read()) / 1e6
P = {k: load('dumps/sd_' + k) for k in ('frz_a', 'frz_b', 'ok_a', 'ok_b')}
def clocks(a, b, kind):
    (ia, ra, ta), (ib, rb, tb) = P[a], P[b]; dt = tb - ta; out = {}
    for p in sorted(set(ia) & set(ib)):
        if p >= 0x40000000: continue
        x = np.frombuffer(ra[ia[p]*0x10000:(ia[p]+1)*0x10000], dtype=kind).astype(np.float64)
        y = np.frombuffer(rb[ib[p]*0x10000:(ib[p]+1)*0x10000], dtype=kind).astype(np.float64)
        with np.errstate(all='ignore'):
            r = (y - x) / dt
            m = np.isfinite(x) & np.isfinite(y) & (np.abs(x) > 0.5) & (np.abs(x) < 1e7) & (r > 0.3) & (r < 3)
        for i in np.nonzero(m)[0]: out[p + i * (4 if kind == '>f4' else 8)] = (x[i], y[i], r[i])
    return out
for kind in ('>f4', '>f8'):
    F = clocks('frz_a', 'frz_b', kind); O = clocks('ok_a', 'ok_b', kind)
    print('==', kind, len(F), len(O))
    for a in sorted(set(F) | set(O)):
        if a >= 0x01000000 and a not in F: continue
        f = F.get(a); o = O.get(a)
        print('%08x frz %s ok %s' % (a, '%.4f->%.4f (%.2f/s)' % f if f else '-', '%.4f->%.4f (%.2f/s)' % o if o else '-'))
