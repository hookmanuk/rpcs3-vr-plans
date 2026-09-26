"""threadcycles.py SECONDS: per-thread CPU of rpcs3.exe from QueryThreadCycleTime (100% = one core). GetThreadTimes (threadcpu.py) undercounts RPCS3 threads that run in short bursts."""
import ctypes, sys, time
from ctypes import wintypes as W
k=ctypes.windll.kernel32
class TE(ctypes.Structure): _fields_=[('dwSize',W.DWORD),('cntUsage',W.DWORD),('th32ThreadID',W.DWORD),('th32OwnerProcessID',W.DWORD),('tpBasePri',W.LONG),('tpDeltaPri',W.LONG),('dwFlags',W.DWORD)]
class PE(ctypes.Structure): _fields_=[('dwSize',W.DWORD),('cntUsage',W.DWORD),('th32ProcessID',W.DWORD),('th32DefaultHeapID',ctypes.c_void_p),('th32ModuleID',W.DWORD),('cntThreads',W.DWORD),('th32ParentProcessID',W.DWORD),('pcPriClassBase',W.LONG),('dwFlags',W.DWORD),('szExeFile',ctypes.c_char*260)]
k.CreateToolhelp32Snapshot.restype=W.HANDLE; k.OpenThread.restype=W.HANDLE; k.GetCurrentThread.restype=W.HANDLE; k.QueryThreadCycleTime.argtypes=[W.HANDLE, ctypes.POINTER(ctypes.c_ulonglong)]
def pid():
    s=k.CreateToolhelp32Snapshot(2,0); e=PE(); e.dwSize=ctypes.sizeof(PE); r=k.Process32First(s,ctypes.byref(e))
    while r:
        if e.szExeFile.lower()==b'rpcs3.exe': k.CloseHandle(s); return e.th32ProcessID
        r=k.Process32Next(s,ctypes.byref(e))
def tids(p):
    s=k.CreateToolhelp32Snapshot(4,0); e=TE(); e.dwSize=ctypes.sizeof(TE); out=[]; r=k.Thread32First(s,ctypes.byref(e))
    while r:
        if e.th32OwnerProcessID==p: out.append(e.th32ThreadID)
        r=k.Thread32Next(s,ctypes.byref(e))
    k.CloseHandle(s); return out
def cyc_hz():
    # TSC rate: this thread's cycle count against wall time while spinning.
    h=k.GetCurrentThread(); c0=ctypes.c_ulonglong(); c1=ctypes.c_ulonglong()
    k.QueryThreadCycleTime(h,ctypes.byref(c0)); t0=time.perf_counter()
    while time.perf_counter()-t0<0.3: pass
    k.QueryThreadCycleTime(h,ctypes.byref(c1)); return (c1.value-c0.value)/(time.perf_counter()-t0)
HZ=cyc_hz()
def times(t):
    h=k.OpenThread(0x0800,False,t)
    if not h: return None,'?'
    c=ctypes.c_ulonglong(); k.QueryThreadCycleTime(h,ctypes.byref(c))
    p=ctypes.c_wchar_p(); r=k.GetThreadDescription(h,ctypes.byref(p)); k.CloseHandle(h)
    return c.value/HZ, (p.value if r>=0 and p.value else '')
P=pid(); secs=float(sys.argv[1]) if len(sys.argv)>1 else 5
A={t:times(t) for t in tids(P)}; time.sleep(secs); B={t:times(t) for t in tids(P)}
rows=sorted(((B[t][0]-A[t][0])/secs*100,t,B[t][1]) for t in B if t in A and A[t][0] is not None and B[t][0] is not None)
print(f'tsc {HZ/1e9:.2f} GHz; total {sum(r[0] for r in rows):.0f}%')
for pct,t,n in reversed(rows[-10:]): print(f'{pct:6.1f}% {t:6d} {n}')
