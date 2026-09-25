"""threadcpu.py [SECONDS]: per-thread CPU use of the running rpcs3.exe, by thread name (100% = one core)."""
import ctypes, sys, time
from ctypes import wintypes
import psutil
k = ctypes.windll.kernel32
k.OpenThread.restype = wintypes.HANDLE
def name(tid):
    h = k.OpenThread(0x1000, False, tid)  # THREAD_QUERY_LIMITED_INFORMATION
    if not h: return '?'
    p = ctypes.c_wchar_p()
    r = k.GetThreadDescription(h, ctypes.byref(p))
    k.CloseHandle(h)
    return p.value if r >= 0 and p.value else '(unnamed)'
proc = next(p for p in psutil.process_iter(['name']) if p.info['name'] and p.info['name'].lower() == 'rpcs3.exe')
secs = float(sys.argv[1]) if len(sys.argv) > 1 else 5
a = {t.id: t.user_time + t.system_time for t in proc.threads()}
time.sleep(secs)
b = {t.id: t.user_time + t.system_time for t in proc.threads()}
rows = sorted(((b[t] - a.get(t, 0)) / secs * 100, t) for t in b)
for pct, t in reversed(rows[-16:]):
    print(f'{pct:6.1f}%  {t:6d}  {name(t)}')
