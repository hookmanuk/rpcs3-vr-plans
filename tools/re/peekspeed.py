"""peekspeed.py LOG X_ADDR Z_ADDR [from_s]: from RPCS3_VR_PEEK lines (f32 words), the horizontal speed in units per wall second:
median over 0.25 s windows while moving, and the 90th percentile."""
import sys, re, struct, statistics
log, xa, za = sys.argv[1], sys.argv[2].lower(), sys.argv[3].lower()
t0 = float(sys.argv[4]) if len(sys.argv) > 4 else 0
pts = []
for line in open(log, encoding='utf8', errors='replace'):
    if 'VR peek' not in line: continue
    m = re.search(r't=([\d.]+)', line); vals = dict(re.findall(r' ([0-9a-f]+)=([0-9a-f]{8})', line))
    if not m or xa not in vals or za not in vals: continue
    f = lambda h: struct.unpack('>f', bytes.fromhex(h))[0]
    pts.append((float(m.group(1)), f(vals[xa]), f(vals[za])))
pts = [p for p in pts if p[0] >= t0]
sp = []
i = 0
for j in range(len(pts)):
    while pts[j][0] - pts[i][0] > 0.25: i += 1
    dt = pts[j][0] - pts[i][0]
    if dt > 0.2:
        d = ((pts[j][1] - pts[i][1]) ** 2 + (pts[j][2] - pts[i][2]) ** 2) ** 0.5
        sp.append(d / dt)
mv = [s for s in sp if s > 10]
print(f'{len(pts)} samples; moving windows {len(mv)}; median {statistics.median(mv) if mv else 0:.1f} u/s; p90 {sorted(mv)[int(len(mv)*0.9)] if mv else 0:.1f}')
