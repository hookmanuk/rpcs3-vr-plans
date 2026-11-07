"""passlist.py LOG [MINDRAWS]: from a frame's trace (pg.sh capture): the frame in order: every run of draws on one colour/depth surface, with its pitch, number of draws and
vertices, the first and last draws' shaders, then the resolves and clears between runs. What the frame does, pass by pass."""
import re, sys
from collections import Counter

log = sys.argv[1]
runs = []
cur = None
last = None
for raw in open(log, errors='replace'):
    l = re.sub(r'^\[ *[0-9.]+\] +', '', raw.rstrip())
    m = re.match(r'draw #(\d+) vs (\w+) ps (\w+) prim (\d+) n (\d+) blend (\w+) mask (\w) .*pitch (\d+)', l)
    if m:
        last = dict(n=int(m.group(1)), vs=m.group(2)[-8:], ps=m.group(3)[-8:], prim=m.group(4), verts=int(m.group(5)), blend=m.group(6), pitch=m.group(8))
        continue
    m = re.match(r'surface (\w+) color (\w+) depth (\w+) depthctl (\w+)', l)
    if m and last:
        key = (m.group(2), m.group(3), last['pitch'])
        if not cur or cur['key'] != key or cur.get('kind') != 'draws':
            cur = dict(key=key, kind='draws', draws=0, verts=0, shaders=Counter(), first=None, last=None, dc=Counter())
            runs.append(cur)
        cur['draws'] += 1
        cur['verts'] += last['verts']
        cur['shaders'][(last['vs'], last['ps'])] += 1
        cur['dc'][m.group(4)] += 1
        cur['first'] = cur['first'] or last
        cur['last'] = last
        last = None
        continue
    if re.match(r'(resolve|clear|copy)\b', l, re.I):
        runs.append(dict(kind='other', text=l[:120]))
        cur = None
for r in runs:
    if r['kind'] == 'other':
        print('   ', r['text'])
        continue
    top = ' '.join('%s/%s*%d' % (k[0], k[1], n) for k, n in r['shaders'].most_common(3))
    print('colour %s depth %s pitch %s: %d draws, %d verts, prim %s blend %s, depthctl %s; %s' % (r['key'][0], r['key'][1], r['key'][2], r['draws'], r['verts'], r['first']['prim'], r['first']['blend'], ','.join(r['dc'].keys())[:30], top))
