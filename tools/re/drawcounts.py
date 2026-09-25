"""drawcounts.py LOG: camera/other draw counts per traced frame (VR trace, headset runs), grouped in bursts."""
import sys, re
rows = []
for line in open(sys.argv[1], encoding='utf-8', errors='replace'):
    if 'VR trace:' not in line:
        continue
    cam = sum(int(m) for m in re.findall(r'C\d+ x(\d+)', line))
    oth = sum(int(m) for m in re.findall(r'N x(\d+)', line))
    f = re.search(r'F\[d\d\] declared (\d+)', line)
    rows.append((int(f.group(1)) if f else -1, cam, oth))
for r in rows[-int(sys.argv[2]) if len(sys.argv) > 2 else -60:]:
    print(*r)
