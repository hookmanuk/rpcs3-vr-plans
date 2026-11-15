"""diffg.py A1,A2 B1,B2: bytes of the data segment (snapg.py snapshots) that are the same within state A, the same
within state B, and differ between them: a setting toggled A, B, A, B. Printed as image offsets, shortest runs first."""
import struct, sys, numpy as np


def load(n):
    raw = open('snaps/%s.bin' % n, 'rb').read()
    return struct.unpack_from('<Q', raw)[0], np.frombuffer(raw, np.uint8, offset=8)


va = load(sys.argv[1].split(',')[0])[0]
A = np.stack([load(n)[1] for n in sys.argv[1].split(',')]); B = np.stack([load(n)[1] for n in sys.argv[2].split(',')])
cand = np.nonzero((A == A[0]).all(0) & (B == B[0]).all(0) & (A[0] != B[0]))[0]
print(len(cand), 'bytes')
runs = []
for a in cand:
    if runs and a - runs[-1][1] <= 4: runs[-1][1] = a
    else: runs.append([a, a])
for a, b in runs[:int(sys.argv[3]) if len(sys.argv) > 3 else 40]:
    print(hex(va + a), 'A', A[0][a:b + 1].tobytes().hex(), 'B', B[0][a:b + 1].tobytes().hex())
