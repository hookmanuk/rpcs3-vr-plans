"""callspread.py RUN_LOG [START_US] [SECONDS=8]: groups the "VR call:" lines (BB_VR_CALLLOG) into frames (a fresh call
starts one) and prints, over the window, the calls a frame, the time from a frame's first to last call, and how far the
head yaw moved between them (each pass of a frame drawn with a different head is the world sliding against itself)."""
import re, sys, statistics
path = sys.argv[1]
start = int(sys.argv[2]) if len(sys.argv) > 2 else None
seconds = float(sys.argv[3]) if len(sys.argv) > 3 else 8
rx = re.compile(r'VR call: (\d+) us view (0x[0-9a-f]+) (fresh|recall) tag (\d+) head yaw (-?[0-9.]+)')
calls = [(int(m[1]), m[2], m[3], int(m[4]), float(m[5])) for m in (rx.search(l) for l in open(path, errors='replace')) if m]
if start is not None:
    calls = [c for c in calls if start <= c[0] <= start + seconds * 1e6]
frames, cur = [], []
for c in calls:
    if c[2] == 'fresh' and cur:
        frames.append(cur)
        cur = []
    cur.append(c)
if cur:
    frames.append(cur)
print(f'{len(calls)} calls, {len(frames)} frames')
if not frames:
    sys.exit()
n = [len(f) for f in frames]
span = [(f[-1][0] - f[0][0]) / 1000 for f in frames]
spread = [max(c[4] for c in f) - min(c[4] for c in f) for f in frames]
tags = [len(set(c[3] for c in f)) for f in frames]
step = [abs(frames[i][0][4] - frames[i - 1][0][4]) for i in range(1, len(frames))]
q = lambda v, p: sorted(v)[min(len(v) - 1, int(p * len(v)))]
print(f'calls a frame: median {statistics.median(n)}, max {max(n)}; distinct tags a frame: median {statistics.median(tags)}')
print(f'first to last call: median {statistics.median(span):.2f} ms, p99 {q(span, .99):.2f}')
print(f'head yaw spread within a frame: median {statistics.median(spread):.3f} deg, p99 {q(spread, .99):.3f}, max {max(spread):.3f}')
print(f'head yaw step frame to frame (first calls): median {statistics.median(step):.3f} deg, max {max(step):.3f}')
print(f'frames with calls on more than one head: {sum(1 for s in spread if s > 1e-4)} of {len(frames)}')
