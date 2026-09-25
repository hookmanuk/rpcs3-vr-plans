"""flicker.py SECONDS OUTPREFIX: record RPCS3's game window and find one-frame blips.

A blip is a frame that differs from both neighbours while the neighbours agree with each other
(geometry that vanishes for a frame). Saves the worst blips as prev|blip|next strips and prints scores.
"""
import ctypes, sys, time
from ctypes import wintypes
import numpy as np
import mss
from PIL import Image

ctypes.windll.user32.SetProcessDpiAwarenessContext(ctypes.c_void_p(-4))
u = ctypes.windll.user32

def game_rect():
    found = []
    @ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    def cb(h, _):
        buf = ctypes.create_unicode_buffer(512)
        u.GetWindowTextW(h, buf, 512)
        if u.IsWindowVisible(h) and buf.value.startswith('FPS:'):
            found.append(h)
        return True
    u.EnumWindows(cb, 0)
    h = found[0]
    r = wintypes.RECT(); u.GetClientRect(h, ctypes.byref(r))
    p = wintypes.POINT(0, 0); u.ClientToScreen(h, ctypes.byref(p))
    return {'left': p.x, 'top': p.y, 'width': r.right, 'height': r.bottom}

secs = float(sys.argv[1]); out = sys.argv[2]
rect = game_rect()
frames, times = [], []
with mss.mss() as s:
    t0 = time.perf_counter()
    while time.perf_counter() - t0 < secs:
        img = np.asarray(s.grab(rect))[:, :, :3]
        frames.append(img[::4, ::4, ::-1].copy()); times.append(time.perf_counter() - t0)
n = len(frames)
print(f'{n} frames in {secs}s ({n / secs:.1f}/s), window {rect}')
g = [f.astype(np.int16).mean(axis=2) for f in frames]
def d(a, b):
    # fraction of pixels that changed a lot (holes are large, flat, high-contrast)
    return float((np.abs(g[a] - g[b]) > 40).mean())
scores = []
for i in range(1, n - 1):
    blip = min(d(i, i - 1), d(i, i + 1)) - d(i - 1, i + 1)
    scores.append((blip, i))
scores.sort(reverse=True)
print('top blips (score, frame, t):', [(round(sc, 4), i, round(times[i], 2)) for sc, i in scores[:12]])
print('blips > 0.005:', sum(1 for sc, _ in scores if sc > 0.005), 'of', n)
for k, (sc, i) in enumerate(scores[:4]):
    h, w, _ = frames[i].shape
    strip = Image.new('RGB', (w * 3, h))
    for j, f in enumerate((frames[i - 1], frames[i], frames[i + 1])):
        strip.paste(Image.fromarray(f), (j * w, 0))
    strip.save(f'{out}_{k}.png')
