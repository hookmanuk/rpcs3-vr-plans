"""rec100.py NAME [COUNT]: records COUNT frames (default 100) of the game's own window, as fast as they come, no sync with the game. Saves a contact sheet out/NAME_sheet.png and every frame out/NAME/NNN.png, and lists the frames with the most pixels unlike the frames both sides, ignoring the driver's arms and whatever moves a lot."""
import ctypes
import os
import sys
import time
from ctypes import wintypes

import mss
import numpy as np
from PIL import Image

ctypes.windll.shcore.SetProcessDpiAwareness(2)
u = ctypes.windll.user32
k = ctypes.windll.kernel32
name = sys.argv[1]
count = int(sys.argv[2]) if len(sys.argv) > 2 else 100
O = 'H:/PGR4-ReGPU/out/'
found = []
ENUM = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)


def title(h):
    t = ctypes.create_unicode_buffer(256)
    u.GetWindowTextW(h, t, 256)
    return t.value


def visit(hwnd, _):
    if u.IsWindowVisible(hwnd):
        pid = wintypes.DWORD()
        u.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
        h = k.OpenProcess(0x1000, False, pid.value)
        if h:
            buf = ctypes.create_unicode_buffer(512)
            size = wintypes.DWORD(512)
            if k.QueryFullProcessImageNameW(h, 0, buf, ctypes.byref(size)) and buf.value.lower().endswith('\\pgr4.exe'):
                found.append(hwnd)
            k.CloseHandle(h)
    return True


u.EnumWindows(ENUM(visit), 0)
hwnd = next(h for h in found if 'simulator' not in title(h).lower())
u.SetForegroundWindow(hwnd)
time.sleep(0.3)
r = wintypes.RECT()
u.GetClientRect(hwnd, ctypes.byref(r))
pt = wintypes.POINT(0, 0)
u.ClientToScreen(hwnd, ctypes.byref(pt))
box = {'left': pt.x, 'top': pt.y, 'width': r.right, 'height': r.bottom}
frames = []
last = None
with mss.MSS() as s:
    t0 = time.perf_counter()
    while len(frames) < count and time.perf_counter() - t0 < 30:
        f = np.asarray(s.grab(box))[:, :, 2::-1].copy()
        if last is None or (f != last).any():  # (distinct frames only)
            frames.append(f)
            last = f
    t1 = time.perf_counter()
print('%d distinct frames in %.1f s, %dx%d' % (len(frames), t1 - t0, box['width'], box['height']))
stack = np.stack(frames).astype(np.int16)
# Flashes: a 16x16 block of the picture mostly unlike the frames both sides, which agree there.
flashes = []
for i in range(1, len(frames) - 1):
    jump = np.minimum(np.abs(stack[i] - stack[i - 1]).max(axis=2), np.abs(stack[i] - stack[i + 1]).max(axis=2))
    agree = np.abs(stack[i - 1] - stack[i + 1]).max(axis=2)
    m = (jump > 12) & (agree < 8)
    h, w = m.shape
    b = m[:h // 16 * 16, :w // 16 * 16].reshape(h // 16, 16, w // 16, 16).sum(axis=(1, 3))
    flashes.append((int(b.max()), i))
top = sorted(flashes, reverse=True)
print('FLASH %s: frames of %d with a block over 100 pixels %d, over 170 %d; biggest %s' % (name, len(flashes), sum(1 for f in flashes if f[0] > 100), sum(1 for f in flashes if f[0] > 170), ' '.join('%d@%d' % t for t in top[:5])))
if os.environ.get('REC_QUIET'):
    sys.exit(0)
d = O + name
os.makedirs(d, exist_ok=True)
for i, f in enumerate(frames):
    Image.fromarray(f).save('%s/%03d.png' % (d, i))
rows = 10
th = 180
sheet = Image.new('RGB', (th * 10, th * ((len(frames) + 9) // 10)))
for i, f in enumerate(frames):
    sheet.paste(Image.fromarray(f).resize((th, th)), (th * (i % 10), th * (i // 10)))
sheet.save(O + name + '_sheet.png')
scores = []
for i in range(1, len(frames) - 1):
    jump = np.minimum(np.abs(stack[i] - stack[i - 1]).max(axis=2), np.abs(stack[i] - stack[i + 1]).max(axis=2))
    agree = np.abs(stack[i - 1] - stack[i + 1]).max(axis=2)
    mask = (jump > 12) & (agree < 8)
    scores.append((int(mask.sum()), i))
scores.sort(reverse=True)
print('frames most unlike both neighbours (pixels, frame): ' + ' '.join('%d@%d' % s for s in scores[:12]))
print('median %d' % int(np.median([s[0] for s in scores])))
for s, i in scores[:3]:
    jump = np.minimum(np.abs(stack[i] - stack[i - 1]).max(axis=2), np.abs(stack[i] - stack[i + 1]).max(axis=2))
    agree = np.abs(stack[i - 1] - stack[i + 1]).max(axis=2)
    Image.fromarray(np.uint8((jump > 12) & (agree < 8)) * 255).save('%s/mask_%03d.png' % (d, i))
