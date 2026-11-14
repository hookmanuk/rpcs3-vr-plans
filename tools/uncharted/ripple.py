"""ripple.py RING.raw [Y0 Y1 X0 X1 as fractions of the left eye, default 0.58 0.9 0.25 0.75]: how fast the water's pattern
changes, in real time, from a flash ring (consecutive frames with their times) of the player standing in the river
right after walking. The region's detail (each frame less the region's time average) is correlated with itself a few
frames later; printed: the frame rate, and the time for that correlation to fall to 0.7 and to 0.5 (ms). Ripples
stepped once a frame run 1.5 times as fast at 90 FPS as at 60 (the times are then 2/3 as long); ripples that follow
the clock give the same times at both rates."""
import struct, sys, numpy as np
data = open(sys.argv[1], 'rb').read()
w, h, n = struct.unpack('<III', data[:12])
size = w * h * 4
frames = np.frombuffer(data[12:12 + size * n], np.uint8).reshape(n, h, w, 4)[..., :3]
times = np.frombuffer(data[12 + size * n:12 + size * n + 8 * n], np.uint64).astype(np.float64) / 1e3  # ms
e = w // 2
keep = times >= times[-1] - 3200  # the last 3.2 s (a ring at 60 FPS holds 5 s)
frames, times, n = frames[keep], times[keep], int(keep.sum())
f = [float(v) for v in sys.argv[2:6]] if len(sys.argv) > 5 else [0.58, 0.9, 0.25, 0.75]
roi = frames[:, int(h * f[0]):int(h * f[1]), int(e * f[2]):int(e * f[3])].astype(np.float32).mean(3)
roi = roi - roi.mean(0)  # the detail that changes
dt = np.median(np.diff(times))
norm = np.sqrt((roi * roi).sum((1, 2))) + 1e-6
lags, corr = [], []
for k in range(0, min(60, n - 1)):
    c = [(roi[i] * roi[i + k]).sum() / (norm[i] * norm[i + k]) for i in range(0, n - k, 3)]
    lags.append(k * dt); corr.append(float(np.mean(c)))


def cross(level):
    for i in range(1, len(corr)):
        if corr[i] < level <= corr[i - 1]:
            return lags[i - 1] + (corr[i - 1] - level) / (corr[i - 1] - corr[i]) * (lags[i] - lags[i - 1])
    return float('nan')


print('%d frames, %.1f FPS (frame %.2f ms); the water pattern keeps 0.7 of itself for %.0f ms, 0.5 for %.0f ms; '
      'change a frame %.2f levels' % (n, 1000 / dt, dt, cross(0.7), cross(0.5), float(np.abs(np.diff(roi, axis=0)).mean())))
