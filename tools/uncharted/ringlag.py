"""ringlag.py RING.raw [CHAR_X=0.5 CHAR_Y=0.62]: a flash ring (BB_VR_FLASH_RING: consecutive frames, both eyes side by side)
recorded while the head sweeps in yaw. Per frame, the shift along x since the frame before of a patch on the character
(left eye, at CHAR_X CHAR_Y of the eye) and of scenery patches left, right and above him (normalised correlation). With
every pass of a frame drawn with one head pose the two move together, frame after frame; a character drawn with another
pose than the world jumps against the scenery for a frame: the double image. Prints the frames where the character's
shift differs from the scenery's by more than 1.5% of the eye's width, and the worst."""
import struct, sys, numpy as np
data = open(sys.argv[1], 'rb').read()
w, h, n = struct.unpack('<III', data[:12])
frames = np.frombuffer(data[12:12 + w * h * 4 * n], np.uint8).reshape(n, h, w, 4)[..., :3]
e = w // 2  # the left eye
cx = float(sys.argv[2]) if len(sys.argv) > 2 else 0.5; cy = float(sys.argv[3]) if len(sys.argv) > 3 else 0.62
luma = frames[:, :, :e].astype(np.float32).mean(3)
H = e // 14  # half patch
P = {'char': (cy, cx), 'left': (0.45, 0.2), 'right': (0.45, 0.8), 'up': (0.2, 0.5)}
R = e // 8   # search range


def shift(a, b, key):
    y, x = int(P[key][0] * h), int(P[key][1] * e)
    t = a[y - H:y + H, x - H:x + H]; t = t - t.mean(); nt = np.sqrt((t * t).sum()) + 1e-6
    best = (-1.0, 0)
    for dx in range(-R, R + 1):
        if x + dx - H < 0 or x + dx + H > e: continue
        q = b[y - H:y + H, x + dx - H:x + dx + H]; q = q - q.mean()
        c = (t * q).sum() / (nt * (np.sqrt((q * q).sum()) + 1e-6))
        if c > best[0]: best = (c, dx)
    return best


bad, worst, used, moving = [], 0, 0, 0
for i in range(1, n):
    r = {k: shift(luma[i - 1], luma[i], k) for k in P}
    world = [r[k][1] for k in ('left', 'right', 'up') if r[k][0] > 0.7]
    if len(world) < 2 or r['char'][0] < 0.7: continue
    used += 1
    wsh = float(np.median(world)); d = r['char'][1] - wsh
    moving += abs(wsh) >= 2
    worst = max(worst, abs(d))
    if abs(d) > 0.015 * e: bad.append((i, wsh, d))
print('%d frames of %dx%d, %d measured (%d with the scenery moving 2 px or more); character against scenery: worst %.0f px, '
      '%d frames over %.0f px' % (n, e, h, used, moving, worst, len(bad), 0.015 * e))
for i, wsh, d in bad[:15]: print('  frame %d: scenery %+.0f px, character %+.0f px more' % (i, wsh, d))
