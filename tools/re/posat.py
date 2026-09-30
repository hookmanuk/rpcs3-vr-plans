"""posat.py ADDR A B: distance moved by the f32 xyz at ADDR between dumps A and B."""
import sys, numpy as np
a = int(sys.argv[1], 16)
def xyz(b):
    idx = np.fromfile(b + '.idx', dtype='<u4'); pos = {int(p): k for k, p in enumerate(idx)}
    raw = np.memmap(b + '.bin', dtype=np.uint8, mode='r'); o = pos[a & ~0xffff] * 0x10000 + (a & 0xffff)
    return np.frombuffer(raw[o:o + 12].tobytes(), dtype='>f4').astype(np.float64)
p, q = xyz(sys.argv[2]), xyz(sys.argv[3]); print(np.round(p, 1), np.round(q, 1), 'moved %.1f' % np.linalg.norm(q - p))
