"""campath.py SECONDS OUT: samples the race camera (the view-projection of the scene's draws, via the debug server's vrcam) as fast
as it can; writes time, eye position and forward axis. Prints how rough the path is: the RMS of the second difference of the
eye's position and of the forward axis, per sample, which camera shake raises and steady motion does not."""
import json, math, socket, sys, time

def send(s, line):
    s.sendall((line + '\n').encode()); d = b''
    while not d.endswith(b'\n'): d += s.recv(1 << 16)
    return json.loads(d)

seconds, out = float(sys.argv[1]), sys.argv[2]
s = socket.create_connection(('127.0.0.1', 7341))
rows, last, t0 = [], None, time.time()
while time.time() - t0 < seconds:
    vp = send(s, 'vrcam')['vp']
    if vp == last:
        time.sleep(0.001); continue
    last = vp
    r = [vp[i:i + 4] for i in range(0, 16, 4)]
    k = math.sqrt(sum(v * v for v in r[3][:3])) or 1
    f = [v / k for v in r[3][:3]]
    sx = math.sqrt(sum(v * v for v in r[0][:3])) or 1
    sy = math.sqrt(sum(v * v for v in r[1][:3])) or 1
    right = [v / sx for v in r[0][:3]]
    up = [v / sy for v in r[1][:3]]
    eye = [-(r[0][3] / sx * right[i] + r[1][3] / sy * up[i] + r[3][3] / k * f[i]) for i in range(3)]
    rows.append((time.time() - t0, *eye, *f, sy))
with open(out, 'w') as o:
    for x in rows:
        o.write(' '.join('%.5f' % v for v in x) + '\n')
def rough(a, b):
    total, n = 0.0, 0
    for i in range(1, len(rows) - 1):
        for c in range(a, b):
            d = rows[i + 1][c] - 2 * rows[i][c] + rows[i - 1][c]
            total += d * d
        n += 1
    return math.sqrt(total / max(n, 1))
speed = 0.0
if len(rows) > 2:
    dist = sum(math.dist(rows[i][1:4], rows[i - 1][1:4]) for i in range(1, len(rows)))
    speed = dist / (rows[-1][0] - rows[0][0])
print('%d samples, %.0f a second, camera speed %.1f m/s: position roughness %.5f m, direction roughness %.6f, lens sy %.3f..%.3f' % (
    len(rows), len(rows) / seconds, speed, rough(1, 4), rough(4, 7), min(x[7] for x in rows), max(x[7] for x in rows)))
