"""simcap.py OUT: the OpenXR simulator window's client area (its composite, the HUD layer included), DPI aware, PrintWindow
(works when covered) -> OUT.full.png here. Recreated 2026-11-06."""
import ctypes, ctypes.wintypes as wt, subprocess, sys
from PIL import Image
ctypes.windll.user32.SetProcessDpiAwarenessContext(ctypes.c_void_p(-4))
user32, gdi32 = ctypes.windll.user32, ctypes.windll.gdi32
gdi32.CreateCompatibleDC.restype = wt.HDC; gdi32.CreateCompatibleBitmap.restype = wt.HBITMAP; user32.GetDC.restype = wt.HDC
user32.GetDC.argtypes = [wt.HWND]; user32.ReleaseDC.argtypes = [wt.HWND, wt.HDC]; user32.PrintWindow.argtypes = [wt.HWND, wt.HDC, wt.UINT]
gdi32.CreateCompatibleDC.argtypes = [wt.HDC]; gdi32.CreateCompatibleBitmap.argtypes = [wt.HDC, ctypes.c_int, ctypes.c_int]
gdi32.SelectObject.argtypes = [wt.HDC, wt.HGDIOBJ]; gdi32.SelectObject.restype = wt.HGDIOBJ; gdi32.DeleteObject.argtypes = [wt.HGDIOBJ]; gdi32.DeleteDC.argtypes = [wt.HDC]
gdi32.GetDIBits.argtypes = [wt.HDC, wt.HBITMAP, wt.UINT, wt.UINT, ctypes.c_void_p, ctypes.c_void_p, wt.UINT]
out = subprocess.run(['tasklist', '/FI', 'IMAGENAME eq burnout.exe', '/FO', 'CSV', '/NH'], capture_output=True, text=True).stdout
pid = int(out.split(',')[1].strip('"'))
found = []
EnumProc = ctypes.WINFUNCTYPE(wt.BOOL, wt.HWND, wt.LPARAM)
def cb(hwnd, _):
    p = wt.DWORD(); user32.GetWindowThreadProcessId(hwnd, ctypes.byref(p))
    if p.value == pid and user32.IsWindowVisible(hwnd):
        t = ctypes.create_unicode_buffer(256); user32.GetWindowTextW(hwnd, t, 256)
        if 'simulator' in t.value.lower() or 'openxr' in t.value.lower(): found.append(hwnd)
    return True
user32.EnumWindows(EnumProc(cb), 0)
hwnd = found[0]
r = wt.RECT(); user32.GetClientRect(hwnd, ctypes.byref(r)); w, h = r.right, r.bottom
dc = user32.GetDC(hwnd); mem = gdi32.CreateCompatibleDC(dc); bmp = gdi32.CreateCompatibleBitmap(dc, w, h); gdi32.SelectObject(mem, bmp)
user32.PrintWindow(hwnd, mem, 3)
class BI(ctypes.Structure):
    _fields_ = [('s', wt.DWORD), ('w', wt.LONG), ('h', wt.LONG), ('p', wt.WORD), ('b', wt.WORD), ('c', wt.DWORD), ('i', wt.DWORD), ('x', wt.LONG), ('y', wt.LONG), ('u', wt.DWORD), ('m', wt.DWORD)]
bi = BI(40, w, -h, 1, 32, 0, 0, 0, 0, 0, 0); buf = ctypes.create_string_buffer(w * h * 4)
gdi32.GetDIBits(mem, bmp, 0, h, buf, ctypes.byref(bi), 0)
Image.frombuffer('RGBA', (w, h), buf, 'raw', 'BGRA', 0, 1).convert('RGB').save(sys.argv[1] + '.full.png')
gdi32.DeleteObject(bmp); gdi32.DeleteDC(mem); user32.ReleaseDC(hwnd, dc)
