"""stagesum.py LOG [SECONDS=30]: the last SECONDS of a REGPU_VR_TRACE run: every "vr stages" line (p50/p99/max of each stage
from the token, and the late frames by cause), the timer probe, draws that stalled, pipelines started, resources created."""
import re, sys
path = sys.argv[1]
window = float(sys.argv[2]) if len(sys.argv) > 2 else 30
lines = open(path, errors='replace').read().splitlines()
def t(l):
    m = re.match(r'\[ *([0-9.]+)\]', l)
    return float(m.group(1)) if m else None
last = max((t(l) for l in lines if t(l) is not None), default=0)
tail = [l for l in lines if t(l) is not None and t(l) > last - window]
for l in tail:
    if 'vr stages' in l:
        print(l[:260])
late = game = cp = gpu = rt = 0
for l in tail:
    m = re.search(r'late (\d+): title (\d+), command processor (\d+), GPU (\d+), runtime (\d+)', l)
    if m:
        late += int(m.group(1)); game += int(m.group(2)); cp += int(m.group(3)); gpu += int(m.group(4)); rt += int(m.group(5))
print('   late %d: title %d, command processor %d, GPU %d, runtime %d' % (late, game, cp, gpu, rt))
timer = [l for l in tail if 'timer:' in l]
if timer:
    print('   ' + ' | '.join(re.sub(r'^\[ *[0-9.]+\] ', '', l) for l in timer[-3:]))
stalls = [l for l in tail if 'took' in l and 'ms' in l and 'perf:' in l]
print('   draw stalls logged: %d%s' % (len(stalls), (' e.g. ' + re.sub(r'^\[ *[0-9.]+\] ', '', stalls[0])[:90]) if stalls else ''))
pipes = sum(int(m.group(1)) for l in tail for m in [re.search(r'pipelines started (\d+)', l)] if m)
created = [re.sub(r'^.*created this second: ', '', l) for l in tail if 'resources created this second' in l]
print('   pipelines started %d, resources created in %d seconds: %s' % (pipes, len(created), ', '.join(created[:4])[:120]))
slow = [re.search(r'slowest frame ([0-9.]+) ms, (\d+) over 20', l) for l in tail]
slow = [(float(m.group(1)), int(m.group(2))) for m in slow if m]
if slow:
    print('   per-second slowest frame: %s' % ' '.join('%.0f' % s[0] for s in slow))
