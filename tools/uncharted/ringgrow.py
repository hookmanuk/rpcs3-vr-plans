"""ringgrow.py WADE.log...: how fast the walk's ripple rings grow, in real time. From wadelog.sh logs (the wake's
quads per draw with wall-clock times): each ring is followed by its centre (it stays where it was made); printed per
log: the frame rate while logging, the rings' growth (their diagonal, metres per second of wall-clock time: median
and spread over the rings followed for 8 frames or more), the growth per frame, and the fade parameter's rate (the
second half-float of the vertex's last pair, per second). A ring stepped once a frame grows 1.5 times as fast per
second at 90 FPS as at 60; one that follows the clock grows the same."""
import collections, re, sys, numpy as np


def half_hi(f):
    return float(np.array([f], np.float32).view(np.uint16).view(np.float16)[1])


for path in sys.argv[1:]:
    tracks = collections.defaultdict(list); frames = {}
    for l in open(path):
        w = l.split(); fr = int(w[2]); t = float(w[4])
        m = re.search(r'buf 0 at \S+ stride 32 size \d+: ([^|]*)', l)
        v = [float(x) for x in m.group(1).split()]
        if len(v) < 32: continue
        q = np.array(v[:32], np.float32).reshape(4, 8)
        c = q[:, :3].astype(float).mean(0)
        frames.setdefault(fr, t)
        tracks[(round(c[0], 1), round(c[2], 1))].append((fr, float(np.linalg.norm(q[0, :3] - q[2, :3])), half_hi(q[0, 6])))
    ft = np.array(sorted(frames.items()), float)
    fps = (len(ft) - 1) / ((ft[-1, 1] - ft[0, 1]) / 1000)
    rates, per_frame, fade = [], [], []
    for k, v in tracks.items():
        v = sorted(set(v))
        if len(v) < 8: continue
        t = np.array([frames[r[0]] for r in v]) / 1000; size = np.array([r[1] for r in v]); f = np.array([r[2] for r in v])
        n = np.array([r[0] for r in v], float)
        rates.append(np.polyfit(t, size, 1)[0]); per_frame.append(np.polyfit(n, size, 1)[0]); fade.append(np.polyfit(t, f, 1)[0])
    r = np.array(rates)
    print('%s: %d frames at %.1f FPS, %d rings: growth %.3f m/s (median; %.3f to %.3f), %.4f m a frame; fade %.2f /s'
          % (path[-16:], len(ft), fps, len(r), np.median(r), r.min(), r.max(), np.median(per_frame), np.median(fade)))
