"""alphastats.py TRACE.txt: from a frame's trace: per pixel shader in the main 3D pass, how many draws, whether depth is written, the alpha test (pinfo.x, 7 = always passes) and the alpha reference."""
import re, sys
from collections import Counter
cur = None
rows = Counter()
draws = 0
for l in open(sys.argv[1], errors='replace'):
    l = re.sub(r'^\[ *[0-9.]+\] +', '', l.rstrip())
    m = re.match(r'draw #\d+ vs (\w+) ps (\w+) prim \d+ n \d+ blend (\w+) mask (\w) .*pitch (\d+)', l)
    if m:
        cur = {'vs': m.group(1)[-8:], 'ps': m.group(2)[-8:], 'blend': m.group(3), 'pitch': m.group(5)}
        continue
    if not cur:
        continue
    m = re.match(r'alpha ref (\S+) \(pinfo.x (\d+)\)', l)
    if m:
        cur['ref'] = m.group(1)
        cur['fn'] = m.group(2)
        continue
    m = re.match(r'surface (\w+) color (\w+) depth (\w+) depthctl (\w+)', l)
    if m and 'fn' in cur:
        dc = int(m.group(4), 16)
        write = bool(dc & 4) and bool(dc & 2)
        rows[(cur['ps'], cur['vs'], cur['fn'], cur['ref'], 'zwrite' if write else 'nowrite', m.group(3))] += 1
        draws += 1
        cur = None
print('draws', draws)
total = Counter()
for k, n in rows.items():
    total[(k[2], k[4])] += n
print('by alpha test and depth write:', sorted(total.items(), key=lambda kv: -kv[1]))
for k, n in rows.most_common(26):
    print(n, *k)
