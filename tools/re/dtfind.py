"""dtfind.py base [base...]: f32 values in the ELF/data range (< 0x10000000) near 1/90, 1/60, 1/30 in every dump."""
import sys, numpy as np
bases = sys.argv[1:]
res = None
for b in bases:
    idx = np.fromfile(b + '.idx', dtype='<u4'); raw = np.memmap(b + '.bin', dtype=np.uint8, mode='r')
    found = {}
    for k, p in enumerate(idx):
        if p >= 0x10000000: continue
        v = np.frombuffer(raw[k * 0x10000:(k + 1) * 0x10000], dtype='>f4')
        for name, lo, hi in (('1/90', 0.0105, 0.0118), ('1/60', 0.0162, 0.0171), ('1/30', 0.0325, 0.0342)):
            for o in np.nonzero((v > lo) & (v < hi))[0]:
                found[int(p) + int(o) * 4] = (name, float(v[o]))
    res = found if res is None else {a: found[a] for a in res if a in found}
for a, (n, v) in sorted(res.items()):
    print(f'0x{a:08x} {n} {v:.6f}')
