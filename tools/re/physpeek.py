"""physpeek.py LOG XADDR YADDR ZADDR: from RPCS3_VR_PEEK lines over the last WINDOW s (env, default 15): peak horizontal
speed (units/s, 0.2 s windows) and airtime of each jump (z above the resting height by > 0.3)."""
import sys, re, struct, os
log, xa, ya, za = sys.argv[1:5]
W = float(os.environ.get('WINDOW', 15))
f = lambda h: struct.unpack('>f', bytes.fromhex(h))[0]
pts = []
for line in open(log, encoding='utf8', errors='replace'):
    if 'VR peek' not in line: continue
    m = re.search(r't=([\d.]+)', line); v = dict(re.findall(r' ([0-9a-f]+)=([0-9a-f]{8})', line))
    if m and xa in v: pts.append((float(m.group(1)), f(v[xa]), f(v[ya]), f(v[za])))
T = pts[-1][0]; pts = [p for p in pts if p[0] > T - W]
sp = []; i = 0
for j in range(len(pts)):
    while pts[j][0] - pts[i][0] > 0.2: i += 1
    dt = pts[j][0] - pts[i][0]
    if dt > 0.15: sp.append(((pts[j][1] - pts[i][1]) ** 2 + (pts[j][2] - pts[i][2]) ** 2) ** .5 / dt)
sp.sort()
print('samples %d, speed p50 of moving %.2f, p90 %.2f u/s' % (len(pts), sp[len(sp)//2] if sp else 0, sp[int(len(sp)*.9)] if sp else 0))
base = sorted(p[3] for p in pts)[len(pts) // 10]
air = []; start = None; peak = 0
for p in pts:
    if p[3] > base + 0.3 and start is None: start = p[0]; peak = p[3]
    elif start is not None:
        peak = max(peak, p[3])
        if p[3] <= base + 0.3: air.append((p[0] - start, peak - base)); start = None
print('jumps (airtime s, height):', ['%.3f/%.2f' % a for a in air])
