"""callframes.py RUN.LOG [LAST_N=4000]: from the last N "VR call" lines (BB_VR_CALLLOG=N), the frames (a "fresh" call
starts one) whose calls took more than one tag or head: each must be 0, or passes of one frame are drawn with two poses."""
import sys, re
lines = [l for l in open(sys.argv[1], errors='replace') if l.startswith('VR call:')][-(int(sys.argv[2]) if len(sys.argv) > 2 else 4000):]
frames, cur = [], None
for l in lines:
    m = re.search(r'(fresh|recall) tag (\d+) head yaw (\S+)', l)
    if not m: continue
    if m.group(1) == 'fresh':
        cur = []; frames.append(cur)
    if cur is not None: cur.append((m.group(2), m.group(3)))
frames = frames[1:-1]
bad_tag = sum(len({t for t, _ in f}) > 1 for f in frames); bad_head = sum(len({h for _, h in f}) > 1 for f in frames)
yaws = {f[0][1] for f in frames}
print('%d frames, %d distinct head yaws; frames with two tags %d, with two heads %d' % (len(frames), len(yaws), bad_tag, bad_head))
import collections
kinds = collections.Counter(' '.join(l.split()[6:7] + l.split()[11:]) for l in lines)  # fresh/recall + written/other [gameview]
print('calls:', dict(kinds))
