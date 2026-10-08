"""thread_cpu.py [SECONDS=5] [TOP=20]: per-thread CPU use of the running rpcs3.exe over SECONDS (thread names from
GetThreadDescription), busiest first, as % of one core. Finds the thread a game is bound by."""
import ctypes, sys, time, subprocess
from ctypes import wintypes as W
k = ctypes.windll.kernel32
k.OpenThread.restype = W.HANDLE
sec = float(sys.argv[1]) if len(sys.argv) > 1 else 5; top = int(sys.argv[2]) if len(sys.argv) > 2 else 20
pid = int(subprocess.check_output(['powershell', '-c', '(Get-Process rpcs3).Id']).split()[0])
class TE(ctypes.Structure):
    _fields_ = [('dwSize', W.DWORD), ('cntUsage', W.DWORD), ('th32ThreadID', W.DWORD), ('th32OwnerProcessID', W.DWORD),
                ('tpBasePri', W.LONG), ('tpDeltaPri', W.LONG), ('dwFlags', W.DWORD)]
def tids():
    snap = k.CreateToolhelp32Snapshot(4, 0); e = TE(); e.dwSize = ctypes.sizeof(TE); out = []
    ok = k.Thread32First(snap, ctypes.byref(e))
    while ok:
        if e.th32OwnerProcessID == pid: out.append(e.th32ThreadID)
        ok = k.Thread32Next(snap, ctypes.byref(e))
    k.CloseHandle(snap); return out
def times(tid):
    h = k.OpenThread(0x0800 | 0x0040, False, tid)  # QUERY_LIMITED_INFORMATION | QUERY_INFORMATION
    if not h: return None, ''
    c, e, kt, ut = (W.FILETIME() for _ in range(4))
    k.GetThreadTimes(h, ctypes.byref(c), ctypes.byref(e), ctypes.byref(kt), ctypes.byref(ut))
    name = ctypes.c_wchar_p()
    try:
        k.GetThreadDescription(h, ctypes.byref(name)); n = name.value or ''
    except Exception: n = ''
    k.CloseHandle(h)
    f = lambda t: (t.dwHighDateTime << 32 | t.dwLowDateTime) / 1e7
    return f(kt) + f(ut), n
a = {t: times(t) for t in tids()}; time.sleep(sec); b = {t: times(t) for t in tids()}
rows = []
for t, (v, n) in b.items():
    if v is None or t not in a or a[t][0] is None: continue
    rows.append(((v - a[t][0]) / sec * 100, t, n))
rows.sort(reverse=True)
for pct, t, n in rows[:top]: print('%6.1f%%  %6d  %s' % (pct, t, n))
