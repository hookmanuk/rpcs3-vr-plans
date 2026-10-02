"""rtclock.py BASE OTHER [OTHER...]: game clocks. In run BASE (dumps/BASE.0 and .1) finds f32 words that grow at
0.5-2 per second (a seconds clock) or 30-120 per second (a 1/60 s tick clock), then prints how fast each grows per
second in the other runs. A real-time clock grows at the same speed in every run."""
import sys, numpy as np, collections
np.seterr(all='ignore')
def load(b):
    idx = np.fromfile(b + '.idx', dtype='<u4'); raw = np.fromfile(b + '.bin', dtype=np.uint8)
    t = int(open(b + '.txt').read().strip()) / 1e6
    pages = {int(p): k for k, p in enumerate(idx) if p < 0x10000000 or 0x30000000 <= p < 0x40000000}
    return raw, pages, t
def run(tag):
    a, pa, t0 = load('dumps/%s.0' % tag); b, pb, t1 = load('dumps/%s.1' % tag); return a, pa, b, pb, t1 - t0
def words(raw, pages, p):
    k = pages[p]; return raw[k * 0x10000:(k + 1) * 0x10000].view('>f4').astype(np.float64)
base = run(sys.argv[1]); others = [(t, run(t)) for t in sys.argv[2:]]
a, pa, b, pb, dt = base
hits = []
for p in pa:
    if p not in pb: continue
    w0 = words(a, pa, p); w1 = words(b, pb, p); r = (w1 - w0) / dt
    ok = np.isfinite(r) & (np.abs(w0) > 1) & (np.abs(w0) < 1e7) & (((r > 0.5) & (r < 2)) | ((r > 30) & (r < 120)))
    for i in np.nonzero(ok)[0]: hits.append((p + 4 * i, r[i]))
print('%d clock candidates in %s (dt %.2f s)' % (len(hits), sys.argv[1], dt))
for t, (oa, opa, ob, opb, odt) in others:
    c = collections.Counter()
    for addr, r in hits:
        p = addr & ~0xffff; i = (addr & 0xffff) // 4
        if p in opa and p in opb:
            q = (words(ob, opb, p)[i] - words(oa, opa, p)[i]) / odt / r
            if np.isfinite(q) and q > 0.05: c[round(q, 2)] += 1
    print('  %-10s dt %.2f s  growth vs base: %s' % (t, odt, ', '.join('x%.2f (%d)' % kv for kv in c.most_common(8))))
