"""framelog.py LOG.csv [OUT.png] [--from S] [--to S]: chart and per-scene table of an RPCS3_VR_FRAMELOG run.

The log (fork hook, rsx_vr_hooks.cpp) has one row per game flip ("flip": time, frame time, RSX thread CPU time,
cinematic / fixed-screen flags) and one per headset frame submitted ("xr", OpenXR frame thread). The chart draws both
rates per second (game: blue, headset: orange) over the whole run, with 72 and 90 FPS lines; the background is purple
in cinematic frames (profile reduced_scale_frames) and grey on the fixed screen. The table splits the run into scenes
(runs of the same flags) and gives each one's average FPS, 1% low, worst frame and RSX thread time, and prints the
per-second series too.
"""
import csv, sys
from PIL import Image, ImageDraw

args = [a for a in sys.argv[1:]]
t_from = float(args[args.index('--from') + 1]) if '--from' in args else None
t_to = float(args[args.index('--to') + 1]) if '--to' in args else None
pos = [a for i, a in enumerate(args) if not a.startswith('--') and (i == 0 or not args[i - 1].startswith('--'))]
path = pos[0]
out = pos[1] if len(pos) > 1 else path.rsplit('.', 1)[0] + '.png'

rows = []
with open(path, newline='') as f:
    for r in csv.DictReader(f):
        try:
            rows.append((r['kind'], int(r['t_us']), float(r['dt_ms']), float(r['rsx_ms']), r['cinematic'] == '1', r['on_screen'] == '1'))
        except (ValueError, KeyError, TypeError):
            pass
if not rows:
    sys.exit('no rows')
t0 = min(r[1] for r in rows)
rows = [(k, (t - t0) / 1e6, dt, rsx, cin, scr) for k, t, dt, rsx, cin, scr in rows]
if t_from is not None:
    rows = [r for r in rows if r[1] >= t_from]
if t_to is not None:
    rows = [r for r in rows if r[1] <= t_to]
flips = [r for r in rows if r[0] == 'flip']
xrs = [r for r in rows if r[0] == 'xr']
end = max(r[1] for r in rows)
start = min(r[1] for r in rows)
secs = range(int(start), int(end))


def per_second(events):
    counts = {}
    for e in events:
        counts[int(e[1])] = counts.get(int(e[1]), 0) + 1
    return [counts.get(s, 0) for s in secs]


fps_flip = per_second(flips)
fps_xr = per_second(xrs)
state = {}
for r in flips:
    state[int(r[1])] = (r[4], r[5])


def stats(events):
    dts = sorted(e[2] for e in events if e[2] > 0)
    if not dts:
        return None
    avg = len(dts) * 1000 / sum(dts)
    p99 = dts[min(len(dts) - 1, len(dts) * 99 // 100)]
    rsx = [e[3] for e in events if e[3] > 0]
    return avg, 1000 / p99, dts[-1], (sum(rsx) / len(rsx) if rsx else 0)


# Scenes: runs of flips with the same flags.
scenes = []
for r in flips:
    key = (r[4], r[5])
    if not scenes or scenes[-1][0] != key:
        scenes.append([key, r[1], r[1], []])
    scenes[-1][2] = r[1]
    scenes[-1][3].append(r)
print(f'{path}: {len(flips)} game flips, {len(xrs)} headset frames over {end - start:.1f} s')
print(f'{"scene":<26}{"from":>7}{"to":>7}  {"game FPS":>9} {"1% low":>7} {"worst ms":>9} {"RSX ms":>7}  {"headset FPS":>11} {"1% low":>7}')
for (cin, scr), a, b, ev in scenes:
    if b - a < 0.5:
        continue
    name = ('cinematic ' if cin else '') + ('fixed screen' if scr else 'headset view')
    s = stats(ev)
    x = stats([e for e in xrs if a <= e[1] <= b])
    xs = f'{x[0]:11.1f} {x[1]:7.1f}' if x else f'{"-":>11} {"-":>7}'
    print(f'{name:<26}{a:7.1f}{b:7.1f}  {s[0]:9.1f} {s[1]:7.1f} {s[2]:9.1f} {s[3]:7.2f}  {xs}')
print('per second (game / headset FPS):')
line = []
for i, s in enumerate(secs):
    line.append(f'{s:>4}s {fps_flip[i]:3d}/{fps_xr[i]:3d}')
    if len(line) == 8:
        print('  '.join(line)); line = []
if line:
    print('  '.join(line))

# Chart.
W, H, L, B, T = 1600, 560, 60, 40, 20
img = Image.new('RGB', (W, H), (255, 255, 255))
d = ImageDraw.Draw(img)
n = max(1, len(fps_flip))
xw = (W - L - 20) / n
ymax = 100
yy = lambda v: H - B - (H - B - T) * min(v, ymax) / ymax
for i, s in enumerate(secs):
    cin, scr = state.get(s, (False, False))
    if cin or scr:
        d.rectangle([L + i * xw, T, L + (i + 1) * xw, H - B], fill=(230, 215, 245) if cin else (232, 232, 232))
for v in range(0, ymax + 1, 10):
    d.line([L, yy(v), W - 20, yy(v)], fill=(215, 215, 215))
    d.text((L - 30, yy(v) - 6), str(v), fill=(0, 0, 0))
for v, c in ((72, (0, 150, 0)), (90, (0, 90, 0))):
    d.line([L, yy(v), W - 20, yy(v)], fill=c, width=1)
    d.text((W - 60, yy(v) - 14), f'{v}', fill=c)
for series, c in ((fps_flip, (40, 90, 220)), (fps_xr, (240, 130, 0))):
    pts = [(L + (i + 0.5) * xw, yy(v)) for i, v in enumerate(series)]
    if len(pts) > 1:
        d.line(pts, fill=c, width=2)
for i, s in enumerate(secs):
    if s % 10 == 0:
        d.text((L + i * xw, H - B + 6), f'{s}s', fill=(0, 0, 0))
d.text((L, 2), f'{path.split("/")[-1].split(chr(92))[-1]}  blue: game FPS  orange: headset frames  purple: cinematic  grey: fixed screen', fill=(0, 0, 0))
img.save(out)
print('chart:', out)
