"""flickwin.py NAME COUNT: grabs the game's own window as fast as it can (no sync with the game, DPI aware), COUNT frames. Prints the grabs a second, how many frames differ from the one before, and the share of pixels that ever change; saves out/NAME_change.png (white: changed) and out/NAME_f<n>.png for the few frames most unlike the median."""
import ctypes
import sys
import time
from ctypes import wintypes

import mss
import numpy as np
from PIL import Image

ctypes.windll.shcore.SetProcessDpiAwareness(2)
u = ctypes.windll.user32
k = ctypes.windll.kernel32
O = 'H:/PGR4-ReGPU/out/'
name, count = sys.argv[1], int(sys.argv[2])
found = []
ENUM = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)


def visit(hwnd, _):
    if not u.IsWindowVisible(hwnd):
        return True
    pid = wintypes.DWORD()
    u.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
    h = k.OpenProcess(0x1000, False, pid.value)
    if h:
        buf = ctypes.create_unicode_buffer(512)
        size = wintypes.DWORD(512)
        if k.QueryFullProcessImageNameW(h, 0, buf, ctypes.byref(size)) and buf.value.lower().endswith('\\pgr4.exe'):
            r = wintypes.RECT()
            u.GetClientRect(hwnd, ctypes.byref(r))
            if r.right > 200:
                found.append(hwnd)
        k.CloseHandle(h)
    return True


u.EnumWindows(ENUM(visit), 0)
if not found:
    sys.exit('no game window')
# The game's own window, not the simulator's (both belong to pgr4.exe): the simulator's title names it.
def title(h):
    t = ctypes.create_unicode_buffer(256)
    u.GetWindowTextW(h, t, 256)
    return t.value


hwnd = next((h for h in found if 'simulator' not in title(h).lower()), found[0])
print('windows: ' + ' | '.join(title(h)[:40] for h in found) + ' -> ' + title(hwnd)[:40])
u.SetForegroundWindow(hwnd)
time.sleep(0.3)
r = wintypes.RECT()
u.GetClientRect(hwnd, ctypes.byref(r))
pt = wintypes.POINT(0, 0)
u.ClientToScreen(hwnd, ctypes.byref(pt))
box = {'left': pt.x, 'top': pt.y, 'width': r.right, 'height': r.bottom}
frames = []
with mss.MSS() as s:
    t0 = time.perf_counter()
    for _ in range(count):
        frames.append(np.asarray(s.grab(box))[:, :, 2::-1].copy())
    t1 = time.perf_counter()
stack = np.stack(frames).astype(np.int16)
median = np.median(stack[::max(1, count // 20)], axis=0)
differ = np.abs(stack - median).max(axis=3) > 30
ever = differ.any(axis=0)
share = differ.mean(axis=(1, 2))
moved = int((np.abs(stack[1:] - stack[:-1]).max(axis=(1, 2, 3)) > 0).sum())
print('%s: %dx%d, %.1f grabs a second, %d of %d differ from the one before; pixels that ever change %.2f%%, frame share median %.3f%% max %.3f%%' % (name, box['width'], box['height'], count / (t1 - t0), moved, count - 1, 100 * ever.mean(), 100 * np.median(share), 100 * share.max()))
Image.fromarray(np.uint8(ever) * 255).save(O + name + '_change.png')
for rank, i in enumerate(np.argsort(share)[-3:]):
    Image.fromarray(np.uint8(stack[i])).save(O + '%s_f%d.png' % (name, rank))
Image.fromarray(np.uint8(median)).save(O + name + '_median.png')
# The steady part of the picture (the cockpit with a still head): pixels that keep their colour in most frames. A frame's outliers
# there, in a block, are something that isn't always drawn: stray triangles.
sample = stack[::max(1, count // 40)]
spread = np.abs(sample - median).max(axis=3)
steady = (spread > 18).mean(axis=0) < 0.08
outliers = [(np.abs(stack[i] - median).max(axis=2) > 35) & steady for i in range(count)]
sizes = np.array([int(o.sum()) for o in outliers])
print('steady area %.1f%%; outlier pixels a frame: median %d, worst %s' % (100 * steady.mean(), int(np.median(sizes)), ' '.join(str(int(v)) for v in np.sort(sizes)[-6:][::-1])))
for rank, i in enumerate(np.argsort(sizes)[-2:][::-1]):
    Image.fromarray(np.uint8(stack[i])).save(O + '%s_out%d.png' % (name, rank))
    Image.fromarray(np.uint8(outliers[i]) * 255).save(O + '%s_out%d_mask.png' % (name, rank))
# Stray rows: a pixel unlike the ones above and below it, which agree (one-row dashes in the picture).
def stray(f):
    up, mid, down = f[:-2], f[1:-1], f[2:]
    return (np.minimum(np.abs(mid - up).max(axis=2), np.abs(mid - down).max(axis=2)) > 40) & (np.abs(up - down).max(axis=2) < 10)


counts = [int(stray(stack[i]).sum()) for i in range(0, count, max(1, count // 25))]
print('stray-row pixels a frame: median %d max %d' % (int(np.median(counts)), max(counts)))
# Flicker: a pixel in one frame unlike the frames both sides of it, while those two agree. Works with a moving head.
keep = [0] + [i for i in range(1, count) if np.abs(stack[i] - stack[i - 1]).max() > 0]
u = stack[keep]
scores = []
for i in range(1, len(u) - 1):
    jump = np.minimum(np.abs(u[i] - u[i - 1]).max(axis=2), np.abs(u[i] - u[i + 1]).max(axis=2))
    agree = np.abs(u[i - 1] - u[i + 1]).max(axis=2)
    mask = (jump > 40) & (agree < 12)
    scores.append((int(mask.sum()), i, mask))
scores.sort(key=lambda t: -t[0])
print('flicker: %d distinct frames; pixels flickering, worst frames: %s; median %d' % (len(u), ' '.join(str(t[0]) for t in scores[:6]), int(np.median([t[0] for t in scores])) if scores else 0))
for rank, (n, i, mask) in enumerate(scores[:3]):
    Image.fromarray(np.uint8(u[i])).save(O + '%s_flick%d.png' % (name, rank))
    Image.fromarray(np.uint8(u[i - 1])).save(O + '%s_flick%d_before.png' % (name, rank))
    Image.fromarray(np.uint8(mask) * 255).save(O + '%s_flick%d_mask.png' % (name, rank))
