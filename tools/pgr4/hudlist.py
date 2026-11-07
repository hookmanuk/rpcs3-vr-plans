"""hudlist.py TRACE.txt [FIRST_HASH]: the draws and resolves after the last final composite (vs e0b5be), one line each: shaders, primitive, blend, mask, scissor, vte, pitch, first
texture, target surface, depth control, stencil. Compare a flat and a VR trace of the same screen."""
import re, sys
lines = open(sys.argv[1], errors='replace').read().splitlines()
first = sys.argv[2] if len(sys.argv) > 2 else 'vs e0b5be1feb70ac93'
start = 0
for i, l in enumerate(lines):
    if first in l and ' draw #' in l:
        start = i
cur = None
out = []
def flush():
    global cur
    if cur:
        out.append(cur)
    cur = None
for l in lines[start:]:
    l = re.sub(r'^\[ *[0-9.]+\] +', '', l)
    m = re.match(r'draw #(\d+) vs (\w+) ps (\w+) prim (\d+) n \d+ blend (\w+) mask (\w) scissor (\S+) vte (\w+) wide \d layer (\d) pitch (\d+)(.*)', l)
    if m:
        flush()
        tex = re.findall(r't\d+=\S+ \S+', m.group(11))
        cur = '#%s vs %s ps %s p%s b %s m %s sc %s vte %s L%s pitch %s %s' % (m.group(1), m.group(2)[-8:], m.group(3)[-8:], m.group(4), m.group(5), m.group(6), m.group(7), m.group(8), m.group(9), m.group(10), ' '.join(tex))
        continue
    m = re.match(r'surface (\w+) color (\w+) depth (\w+) depthctl (\w+) stencil (\w+)', l)
    if m and cur:
        cur += ' | surf %s col %s dep %s dc %s st %s' % m.groups()
        continue
    m = re.match(r'host: scissor (\S+)', l)
    if m and cur:
        cur += ' | host %s' % m.group(1)
        continue
    if l.startswith('resolve: control'):
        flush()
        m = re.search(r'dest (\w+).*rect (\S+) clear (\w+) depth clear (\w+) \(color info (\w+)', l)
        ctl = re.search(r'control (\w+)', l).group(1)
        out.append('  RESOLVE ctl %s dest %s rect %s clear %s %s col %s' % (ctl, m.group(1), m.group(2), m.group(3), m.group(4), m.group(5)))
flush()
for o in out:
    print(o)
