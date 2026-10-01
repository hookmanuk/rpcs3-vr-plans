"""speedline.py LOG XADDR ZADDR [YADDR]: horizontal speed of a peeked position over time (0.1 s steps), from RPCS3_VR_PEEK lines."""
import sys, re, struct
log, xa, za = sys.argv[1:4]; ya = sys.argv[4] if len(sys.argv) > 4 else None
f = lambda h: struct.unpack('>f', bytes.fromhex(h))[0]
pts = []
for line in open(log, encoding='utf8', errors='replace'):
    if 'VR peek' not in line: continue
    m = re.search(r't=([\d.]+)', line); v = dict(re.findall(r' ([0-9a-f]+)=([0-9a-f]{8})', line))
    if m and xa in v: pts.append((float(m.group(1)), f(v[xa]), f(v[za]), f(v[ya]) if ya else 0))
t0 = pts[0][0]; out = []; last = pts[0]
for p in pts:
    if p[0] - last[0] >= 0.1:
        s = ((p[1] - last[1]) ** 2 + (p[2] - last[2]) ** 2) ** .5 / (p[0] - last[0])
        out.append('%.1f:%.1f%s' % (p[0] - t0, s, '/h%.2f' % p[3] if ya and abs(p[3]) > 0.05 else '')); last = p
print(' '.join(o for o in out if not o.endswith(':0.0')))
