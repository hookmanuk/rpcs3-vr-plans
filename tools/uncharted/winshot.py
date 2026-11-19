"""winshot.py OUT.png: DPI-aware capture of bb-probe.exe's desktop window (what Matt screenshots: the left eye with the
HUD composited by Stereo::RecordMirror), via PrintWindow(PW_RENDERFULLCONTENT) so it works behind other windows."""
import ctypes, ctypes.wintypes as W, subprocess, re, sys
from PIL import Image
ctypes.windll.shcore.SetProcessDpiAwareness(2)
u32, g32 = ctypes.windll.user32, ctypes.windll.gdi32
out = subprocess.run(['tasklist', '/FI', 'IMAGENAME eq bb-probe.exe', '/FO', 'CSV', '/NH'], capture_output=True, text=True).stdout
pid = int(re.search(r'"bb-probe.exe","(\d+)"', out).group(1))
found = []
@ctypes.WINFUNCTYPE(W.BOOL, W.HWND, W.LPARAM)
def cb(h, _):
    p = W.DWORD(); u32.GetWindowThreadProcessId(h, ctypes.byref(p))
    if p.value == pid and u32.IsWindowVisible(h):
        r = W.RECT(); u32.GetClientRect(h, ctypes.byref(r))
        found.append((r.right * r.bottom, h, r.right, r.bottom))
    return True
u32.EnumWindows(cb, 0)
_, h, w, hh = max(found)
dc = u32.GetDC(h); mdc = g32.CreateCompatibleDC(dc); bmp = g32.CreateCompatibleBitmap(dc, w, hh)
g32.SelectObject(mdc, bmp)
u32.PrintWindow(h, mdc, 3)  # PW_CLIENTONLY | PW_RENDERFULLCONTENT
class BIH(ctypes.Structure):
    _fields_ = [('size', W.DWORD), ('w', W.LONG), ('h', W.LONG), ('planes', W.WORD), ('bits', W.WORD), ('comp', W.DWORD),
                ('isize', W.DWORD), ('xp', W.LONG), ('yp', W.LONG), ('cu', W.DWORD), ('ci', W.DWORD)]
bi = BIH(ctypes.sizeof(BIH), w, -hh, 1, 32, 0, 0, 0, 0, 0, 0)
buf = ctypes.create_string_buffer(w * hh * 4)
g32.GetDIBits(mdc, bmp, 0, hh, buf, ctypes.byref(bi), 0)
Image.frombuffer('RGBA', (w, hh), buf, 'raw', 'BGRA', 0, 1).convert('RGB').save(sys.argv[1])
g32.DeleteObject(bmp); g32.DeleteDC(mdc); u32.ReleaseDC(h, dc)
print(w, hh)
