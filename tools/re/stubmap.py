"""stubmap.py ELF [NAME...]: map imported functions (by the .imports NIDs) to the ELF's import slots and the stub
functions that load them; with NAMEs, list each stub's callers. Works when the .imports addresses are RPCS3's HLE
descriptors (outside the ELF) rather than the stubs."""
import sys, struct, re, os
from ps3elf import Elf
e = Elf(sys.argv[1])
nid2name = {}
for line in open(os.path.splitext(sys.argv[1])[0] + '.imports'):
    m = re.search(r'\[(\w+)\] \((0x[0-9a-f]+)\)', line)
    if m: nid2name[int(m.group(2), 16)] = m.group(1)
d = e.d
phoff = struct.unpack('>Q', d[0x20:0x28])[0]; es, n = struct.unpack('>HH', d[0x36:0x3a])
for i in range(n):
    o = phoff + i * es; t, f, off, va, pa, fs, ms = struct.unpack('>IIQQQQQ', d[o:o + 48])
    if t == 0x60000002: prx = va
size, magic, ver, sdk, ls, le, ss, se = struct.unpack('>IIIIIIII', e.read(prx, 32))
slot2name = {}
a = ss
while a < se:
    hdr = e.read(a, 0x2c); sz = hdr[0]
    nf = struct.unpack('>H', hdr[6:8])[0]
    nidp, slotp = struct.unpack('>II', hdr[0x14:0x1c])
    for k in range(nf):
        nid = e.u32(nidp + 4 * k); slot2name[slotp + 4 * k] = nid2name.get(nid, hex(nid))
    a += sz
# stub functions: lis r12,hi ; lwz r12,lo(r12) (or li/oris form) referencing a slot
v, b = e.words(); W = struct.unpack('>%dI' % (len(b) // 4), b[:len(b) // 4 * 4])
name2stub = {}
for i in range(len(W) - 2):
    w0, w1, w2 = W[i], W[i + 1], W[i + 2]
    hi = None
    if w0 >> 26 == 15 and (w0 >> 16) & 31 == 0 and (w0 >> 21) & 31 == 12: hi = (w0 & 0xffff) << 16; nxt = w1  # lis r12
    elif w0 >> 26 == 14 and (w0 >> 21) & 31 == 12 and (w0 >> 16) & 31 == 0 and w1 >> 26 == 25: hi = (w1 & 0xffff) << 16; nxt = w2  # li r12,0; oris
    if hi is None: continue
    if nxt >> 26 == 32 and (nxt >> 16) & 31 == 12:
        ad = (hi + ((nxt & 0xffff) ^ 0x8000) - 0x8000) & 0xffffffff
        if ad in slot2name: name2stub.setdefault(slot2name[ad], []).append(v + 4 * i)
if len(sys.argv) == 2:
    for nm, st in sorted(name2stub.items()): print(nm, [hex(s) for s in st])
for nm in sys.argv[2:]:
    for s in name2stub.get(nm, []):
        print(nm, 'stub', hex(s), 'callers', [hex(c) for c in e.calls_to(s)])
