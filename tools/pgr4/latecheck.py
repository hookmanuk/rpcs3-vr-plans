"""latecheck.py LOG [BUDGET_MS=11.6]: from a game log with REGPU_VR_TRACE=1: frame lengths and time in xrEndFrame, the share of frames over budget, how far apart they fall,
and the last "slow frame" lines (REGPU_PERF=1)."""
import re, sys
text = open(sys.argv[1], errors='replace').read().splitlines()
budget = float(sys.argv[2]) if len(sys.argv) > 2 else 11.6
frames = []
for l in text:
    if 'vr trace:' in l:
        frames += [tuple(int(x) for x in t.split('/')) for t in l.split('vr trace:')[1].split() if re.fullmatch(r'\d+/\d+/\d+', t)]
frames = frames[-1800:]
if not frames:
    sys.exit('no trace')
late = [i for i, f in enumerate(frames) if f[0] > budget]
print('frames %d, over %.1f ms: %d (%.2f%%), mean %.2f ms' % (len(frames), budget, len(late), 100.0 * len(late) / len(frames), sum(f[0] for f in frames) / len(frames)))
hist = {}
for f in frames:
    hist[f[0]] = hist.get(f[0], 0) + 1
print('lengths:', ' '.join('%dms:%d' % (k, hist[k]) for k in sorted(hist)))
gaps = [b - a for a, b in zip(late, late[1:])]
if gaps:
    g = {}
    for x in gaps:
        g[x] = g.get(x, 0) + 1
    print('gaps between late frames (most common):', sorted(g.items(), key=lambda kv: -kv[1])[:12])
print('late frame: end/wait, then next frame:', [(frames[i][1], frames[i][2] if len(frames[i]) > 2 else 0, frames[i + 1][0]) for i in late[:24] if i + 1 < len(frames)])
slow = [l for l in text if 'slow frame' in l]
print('slow frame lines: %d' % len(slow))
for l in slow[-8:]:
    print(l[:230])
