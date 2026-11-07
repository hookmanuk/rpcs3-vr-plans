"""bounce.py NAME [COUNT]: in-car view, head still: how much the cockpit moves against the camera from frame to frame: the game's window grabbed COUNT times, each distinct frame's vertical and sideways shift of the steering wheel's area against the first frame (phase correlation, in pixels of an 800 window). A camera fixed to the car gives 0."""
import ctypes
import sys
import time
from ctypes import wintypes

import mss
import numpy as np

ctypes.windll.shcore.SetProcessDpiAwareness(2)
u = ctypes.windll.user32
k = ctypes.windll.kernel32
name = sys.argv[1]
count = int(sys.argv[2]) if len(sys.argv) > 2 else 300
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
W, H = r.right, r.bottom
# The dash's passenger side and its vents: fixed to the car, away from the steering wheel and the driver's arms, with the HUD's route arrow left out.
box = {'left': pt.x + int(W * .07), 'top': pt.y + int(H * .47), 'width': int(W * .19), 'height': int(H * .14)}
if len(sys.argv) > 3:  # 'world': the far scenery through the windscreen instead: the world against the camera
    box = {'left': pt.x + int(W * .25), 'top': pt.y + int(H * .24), 'width': int(W * .50), 'height': int(H * .17)}
frames = []
last = None
with mss.MSS() as s:
    t0 = time.perf_counter()
    while len(frames) < count and time.perf_counter() - t0 < 20:
        f = np.asarray(s.grab(box))[:, :, 1].astype(np.float32)
        if last is None or (f != last).any():
            frames.append(f)
            last = f
    t1 = time.perf_counter()
win = np.outer(np.hanning(box['height']), np.hanning(box['width']))


def fft(f):
    return np.fft.fft2((f - f.mean()) * win)


ref = fft(frames[0])
ys, xs = [], []
for f in frames[1:]:
    c = np.fft.ifft2(ref * np.conj(fft(f)) / (np.abs(ref * np.conj(fft(f))) + 1e-6)).real
    y, x = np.unravel_index(np.argmax(c), c.shape)
    ys.append(y - c.shape[0] if y > c.shape[0] // 2 else y)
    xs.append(x - c.shape[1] if x > c.shape[1] // 2 else x)
ys, xs = np.array(ys, float), np.array(xs, float)
step = np.abs(np.diff(ys))
print('BOUNCE %s: %d frames in %.1f s; vertical: range %d px, sd %.2f, mean change a frame %.2f, biggest %d; sideways: range %d, sd %.2f (window %d high)' % (name, len(frames), t1 - t0, ys.max() - ys.min(), ys.std(), step.mean(), step.max(), xs.max() - xs.min(), xs.std(), H))
