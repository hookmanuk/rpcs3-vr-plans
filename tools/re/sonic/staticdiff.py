"""staticdiff.py A1,A2 B1,B2: u32 words below 0x10000000 (the ELF's data, same addresses every boot) equal within each
group and different between the groups. Prints address, A value, B value (also as f32)."""
import sys, numpy as np, struct
def load(tag):
    idx = np.fromfile('dumps/%s.idx' % tag, dtype='<u4'); raw = np.fromfile('dumps/%s.bin' % tag, dtype=np.uint8)
    return {int(p): raw[k * 0x10000:(k + 1) * 0x10000].view('>u4') for k, p in enumerate(idx) if p < 0x10000000}
A = [load(t) for t in sys.argv[1].split(',')]; B = [load(t) for t in sys.argv[2].split(',')]
pages = sorted(set.intersection(*[set(d) for d in A + B]))
n = 0
for p in pages:
    a0 = A[0][p]; b0 = B[0][p]; ok = a0 != b0
    for d in A[1:]: ok &= d[p] == a0
    for d in B[1:]: ok &= d[p] == b0
    for i in np.nonzero(ok)[0]:
        a, b = int(a0[i]), int(b0[i]); fa, fb = struct.unpack('>f', struct.pack('>I', a))[0], struct.unpack('>f', struct.pack('>I', b))[0]
        print('%08x  %08x %08x   %.6g %.6g' % ((p) + 4 * i, a, b, fa, fb)); n += 1
print(n, 'words')
