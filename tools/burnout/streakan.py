"""streakan.py NAME AMP HZ: streak quad size vs head speed from the streaktrace log; static-camera frames split out."""
import math, re, sys
n, amp, hz = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
t0 = float(open(n + '.t0').read()) * 1000
cam, st = [], []
for l in open(n + '.log', errors='ignore'):
    m = re.search(r'streakcam: (\d+) (.*)', l)
    if m: cam.append((int(m.group(1)), [float(x) for x in m.group(2).split()])); continue
    m = re.search(r'streaktrace: (\d+) (\d+) (\S+) (\S+) (\S+) (\S+)', l)
    if m: st.append((int(m.group(1)), int(m.group(2)), *[float(m.group(k)) for k in (3, 4, 5, 6)]))
def nearest(t):
    lo, hi = 0, len(cam) - 1
    while lo < hi:
        mid = (lo + hi) // 2
        if cam[mid][0] < t: lo = mid + 1
        else: hi = mid
    return lo
rows = []
for t, q, cx, cy, sw, sh in st:
    if t < t0 or t > t0 + 6000 or q < 8: continue
    p = (t - t0) / 1000
    yaw = amp * math.sin(2 * math.pi * hz * p); rate = amp * 2 * math.pi * hz * math.cos(2 * math.pi * hz * p)
    k = nearest(t); a = cam[max(k - 3, 0)][1]; b = cam[k][1]; mv = sum(abs(a[i] - b[i]) for i in range(6))
    rows.append((p, q, yaw, rate, cx, cy, sw, sh, mv))
print(n, 'draws', len(rows), 'of', len(st), 'cam samples', len(cam))
def corr(x, y):
    N = len(x)
    if N < 3: return 0, 0
    mx, my = sum(x) / N, sum(y) / N; sx = sum((v - mx) ** 2 for v in x); sy = sum((v - my) ** 2 for v in y); c = sum((a - mx) * (b - my) for a, b in zip(x, y))
    return (c / sx if sx else 0), (c / math.sqrt(sx * sy) if sx and sy else 0)
for label, R in (('all', rows), ('static camera', [r for r in rows if r[8] < 0.02]), ('moving camera', [r for r in rows if r[8] >= 0.02])):
    if len(R) < 3: print(label, 'n', len(R)); continue
    sl, r = corr([x[2] for x in R], [x[4] for x in R]); sl2, r2 = corr([abs(x[3]) for x in R], [x[6] for x in R])
    fast = [x[6] for x in R if abs(x[3]) > 150]; slow = [x[6] for x in R if abs(x[3]) < 60]
    print(f'{label}: n {len(R)} quads {sum(x[1] for x in R) // len(R)} centre_x vs yaw slope {sl:.4f} r {r:.3f}; width vs |rate| slope {sl2:.6f} r {r2:.3f}; width fast {sum(fast) / max(len(fast), 1):.4f} (n {len(fast)}) slow {sum(slow) / max(len(slow), 1):.4f} (n {len(slow)})')
