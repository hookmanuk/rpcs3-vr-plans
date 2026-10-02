"""statevar.py A1,A2,.. B1,B2,..: find game-state words (an enum or flag such as "in play" vs "front end").
Loads dumps/<tag>.{bin,idx} (RPCS3_VR_MEMDUMP) and lists u32 words, in main memory and 0x30000000+ user memory, that
hold one small value (< 256) in every A dump and one other small value in every B dump. Words repeated 0x180000 bytes
away are dropped (triple-buffered RSX command buffers in user memory). Writes the candidates to dumps/statevar_peek.txt:
log them with RPCS3_VR_PEEK=<that file> RPCS3_VR_PEEK_EVERY=20 through a fresh boot (menus, play, pause, game over) and
keep the word that changes exactly at those screens (Super Stardust HD: 0x332b7ec0, 8 = front end, 9 = play)."""
import sys, numpy as np, collections
def load(tag):
    idx = np.fromfile('dumps/%s.idx' % tag, dtype='<u4'); raw = np.fromfile('dumps/%s.bin' % tag, dtype=np.uint8)
    return {int(p): raw[k * 0x10000:(k + 1) * 0x10000].view('>u4') for k, p in enumerate(idx)
            if p < 0x10000000 or 0x30000000 <= p < 0x40000000}
A = [load(t) for t in sys.argv[1].split(',')]; B = [load(t) for t in sys.argv[2].split(',')]
pages = set.intersection(*[set(d) for d in A + B])
out = {}
for p in sorted(pages):
    a0 = A[0][p]; b0 = B[0][p]
    ok = (a0 < 256) & (b0 < 256) & (a0 != b0)
    for d in A[1:]: ok &= d[p] == a0
    for d in B[1:]: ok &= d[p] == b0
    for i in np.nonzero(ok)[0]: out[p + 4 * i] = (int(a0[i]), int(b0[i]))
keep = {a: v for a, v in out.items() if out.get(a + 0x180000) != v and out.get(a - 0x180000) != v}
print('%d words, %d after dropping command-buffer copies' % (len(out), len(keep)))
for (va, vb), n in collections.Counter(keep.values()).most_common(10):
    print('  A=%d B=%d: %d words' % (va, vb, n))
open('dumps/statevar_peek.txt', 'w').write(''.join('%x\n' % a for a in sorted(keep)))
print('candidates written to dumps/statevar_peek.txt')
