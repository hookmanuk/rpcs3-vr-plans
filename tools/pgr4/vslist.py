"""vslist.py: after a capture, each vertex shader of the main view's passes (pitch 1280) in the last traced frame: its draws, order
range (before/after the final composite), pixel shaders, texture formats, and how its HLSL makes the position (which constants)."""
import json, re, socket, sys, os
def send(s, line):
    s.sendall((line + '\n').encode()); d = b''
    while not d.endswith(b'\n'): d += s.recv(1 << 20)
    return json.loads(d)
log = open('H:/PGR4-ReGPU/thirdparty/ReGPU/out/live.log', errors='ignore').read().splitlines()
# the last frame: from the last "draw #0"
start = max(i for i, l in enumerate(log) if 'draw #0 vs' in l)
draws = []
for l in log[start:]:
    m = re.search(r'draw #(\d+) vs (\w+) ps (\w+) prim (\d+) n (\d+) blend (\w+) mask (\w+) scissor (\S+) vte (\w+) wide (\d) layer (\d) pitch (\d+)(.*)', l)
    if m:
        draws.append(m.groups())
comp = [int(d[0]) for d in draws if d[1] == 'e0b5be1feb70ac93' and d[2] == '4c40a956f32770b5']
comp = comp[-1] if comp else 1 << 30
print('draws', len(draws), 'composite at', comp)
s = socket.create_connection(('127.0.0.1', 7341))
os.makedirs('H:/PGR4-ReGPU/out/hlsl', exist_ok=True)
by = {}
for d in draws:
    if d[11] != '1280':
        continue
    e = by.setdefault(d[1], dict(n=0, first=int(d[0]), last=0, ps=set(), prim=set(), blend=set(), tex=set(), mask=set()))
    e['n'] += 1; e['last'] = int(d[0]); e['ps'].add(d[2][:6]); e['prim'].add(d[3]); e['blend'].add(d[5]); e['mask'].add(d[6])
    for t in re.findall(r't\d+=(\S+) (\d+x\d+)', d[12]):
        e['tex'].add(t[0] + ' ' + t[1])
for vs, e in sorted(by.items(), key=lambda kv: kv[1]['first']):
    path = 'H:/PGR4-ReGPU/out/hlsl/%s.hlsl' % vs
    if not os.path.exists(path):
        send(s, 'hlsl %s %s' % (vs, path))
    pos = ''
    try:
        h = open(path, errors='ignore').read()
        i = h.find('void GuestVS(uint vindex, out float4 opos, out float4 o[16], out float4 opts)')
        lines = [l for l in h[i:h.find('void GuestVS', i + 10)].splitlines() if 'opos' in l and 'void' not in l and 'opos =' not in l]
        pos = ' '.join(sorted(set(re.findall(r'vc\[[^\]]*\]', ' '.join(lines)))))[:40] or ('src ' + ' '.join(sorted(set(re.findall(r'r\d+', ' '.join(lines)))))[:30])
    except OSError:
        pos = '?'
    where = 'HUD' if e['first'] > comp else 'scene'
    print('%-5s %s n %4d #%d-%d prim %s blend %s mask %s pos[%s] ps %s tex %s' % (where, vs, e['n'], e['first'], e['last'], ','.join(sorted(e['prim'])),
        ','.join(sorted(e['blend']))[:26], ','.join(sorted(e['mask'])), pos, ','.join(sorted(e['ps']))[:30], ', '.join(sorted(e['tex']))[:60]))
