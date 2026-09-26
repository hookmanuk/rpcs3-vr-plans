"""rsx_sample.py THREAD_SUBSTR SECONDS [HZ]: sampling profiler for one named rpcs3.exe thread (no admin needed).
Suspends the thread, walks its stack (dbghelp StackWalk64 + rpcs3.pdb), and prints the top leaf
functions (self) and the top functions anywhere on the stack (inclusive)."""
import ctypes, sys, time, collections
from ctypes import wintypes as W

k = ctypes.windll.kernel32
d = ctypes.WinDLL('dbghelp.dll')
k.OpenProcess.restype = W.HANDLE
k.OpenThread.restype = W.HANDLE
k.CreateToolhelp32Snapshot.restype = W.HANDLE

class TE(ctypes.Structure): _fields_ = [('dwSize', W.DWORD), ('cntUsage', W.DWORD), ('th32ThreadID', W.DWORD), ('th32OwnerProcessID', W.DWORD), ('tpBasePri', W.LONG), ('tpDeltaPri', W.LONG), ('dwFlags', W.DWORD)]
class PE(ctypes.Structure): _fields_ = [('dwSize', W.DWORD), ('cntUsage', W.DWORD), ('th32ProcessID', W.DWORD), ('th32DefaultHeapID', ctypes.c_void_p), ('th32ModuleID', W.DWORD), ('cntThreads', W.DWORD), ('th32ParentProcessID', W.DWORD), ('pcPriClassBase', W.LONG), ('dwFlags', W.DWORD), ('szExeFile', ctypes.c_char * 260)]

def pid():
    s = k.CreateToolhelp32Snapshot(2, 0); e = PE(); e.dwSize = ctypes.sizeof(PE); r = k.Process32First(s, ctypes.byref(e))
    while r:
        if e.szExeFile.lower() == b'rpcs3.exe': return e.th32ProcessID
        r = k.Process32Next(s, ctypes.byref(e))

def threads(p):
    s = k.CreateToolhelp32Snapshot(4, 0); e = TE(); e.dwSize = ctypes.sizeof(TE); out = []; r = k.Thread32First(s, ctypes.byref(e))
    while r:
        if e.th32OwnerProcessID == p: out.append(e.th32ThreadID)
        r = k.Thread32Next(s, ctypes.byref(e))
    return out

def tname(tid):
    h = k.OpenThread(0x0800, False, tid); p = ctypes.c_wchar_p(); r = k.GetThreadDescription(h, ctypes.byref(p)); k.CloseHandle(h)
    return p.value if r >= 0 and p.value else ''

P = pid()
want = sys.argv[1]; secs = float(sys.argv[2]); hz = float(sys.argv[3]) if len(sys.argv) > 3 else 400
tid = next(t for t in threads(P) if want in tname(t))
hp = k.OpenProcess(0x0410, False, P)
ht = k.OpenThread(0x0002 | 0x0008 | 0x0040, False, tid)

d.SymSetOptions(0x2 | 0x10 | 0x200)  # UNDNAME | LOAD_LINES off? DEFERRED_LOADS | ...
d.SymInitialize.argtypes = [W.HANDLE, ctypes.c_char_p, W.BOOL]
d.SymInitialize(hp, b'F:\\rpsc3\\source\\rpcs3\\bin', True)
d.SymFunctionTableAccess64.restype = ctypes.c_void_p
d.SymGetModuleBase64.restype = ctypes.c_ulonglong
fta = ctypes.cast(d.SymFunctionTableAccess64, ctypes.c_void_p).value
gmb = ctypes.cast(d.SymGetModuleBase64, ctypes.c_void_p).value
d.StackWalk64.argtypes = [W.DWORD, W.HANDLE, W.HANDLE, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p]

class SYM(ctypes.Structure):
    _fields_ = [('SizeOfStruct', W.ULONG), ('TypeIndex', W.ULONG), ('Reserved', ctypes.c_ulonglong * 2), ('Index', W.ULONG), ('Size', W.ULONG), ('ModBase', ctypes.c_ulonglong), ('Flags', W.ULONG), ('Value', ctypes.c_ulonglong), ('Address', ctypes.c_ulonglong), ('Register', W.ULONG), ('Scope', W.ULONG), ('Tag', W.ULONG), ('NameLen', W.ULONG), ('MaxNameLen', W.ULONG), ('Name', ctypes.c_char * 512)]
d.SymFromAddr.argtypes = [W.HANDLE, ctypes.c_ulonglong, ctypes.POINTER(ctypes.c_ulonglong), ctypes.POINTER(SYM)]
cache = {}
def sym(a):
    if a in cache: return cache[a]
    s = SYM(); s.SizeOfStruct = 88; s.MaxNameLen = 511; disp = ctypes.c_ulonglong()
    n = s.Name.decode(errors='replace') if d.SymFromAddr(hp, a, ctypes.byref(disp), ctypes.byref(s)) else f'?{a:x}'
    cache[a] = n; return n

ctx_raw = ctypes.create_string_buffer(1232 + 16)
ctx_addr = (ctypes.addressof(ctx_raw) + 15) & ~15
frame = ctypes.create_string_buffer(512)
own = collections.Counter(); self_c = collections.Counter(); incl = collections.Counter(); pairs = collections.Counter(); n = 0
end = time.perf_counter() + secs
while time.perf_counter() < end:
    if k.SuspendThread(ht) == 0xFFFFFFFF: break
    try:
        ctypes.memset(ctx_addr, 0, 1232)
        ctypes.c_uint32.from_address(ctx_addr + 0x30).value = 0x10000B  # CONTEXT_FULL (AMD64)
        if not k.GetThreadContext(ht, ctypes.c_void_p(ctx_addr)): continue
        rip = ctypes.c_uint64.from_address(ctx_addr + 0xF8).value
        rsp = ctypes.c_uint64.from_address(ctx_addr + 0x98).value
        rbp = ctypes.c_uint64.from_address(ctx_addr + 0xA0).value
        ctypes.memset(frame, 0, 512)
        for off, val in ((0, rip), (32, rbp), (48, rsp)):
            ctypes.c_uint64.from_buffer(frame, off).value = val
            ctypes.c_uint32.from_buffer(frame, off + 12).value = 3
        stack = []
        for _ in range(40):
            if not d.StackWalk64(0x8664, hp, ht, frame, ctx_addr, None, fta, gmb, None): break
            pc = ctypes.c_uint64.from_buffer(frame, 0).value
            if not pc: break
            stack.append(pc)
    finally:
        k.ResumeThread(ht)
    names = [sym(a) for a in stack]
    if not names: continue
    n += 1
    self_c[names[0]] += 1
    first = next((nm for nm in names if not (nm.startswith(('vk', 'Nt', 'Zw', 'Rtl', '?', 'Drv', 'memcpy', 'memset', 'malloc', '_malloc', 'free', 'operator new', 'operator delete', 'std::')) or 'Heap' in nm)), names[0])
    own[first] += 1
    for nm in set(names): incl[nm] += 1
    if len(names) > 1: pairs[names[0] + '  <-  ' + names[1]] += 1
    time.sleep(1 / hz)

print(f'{n} samples of {tname(tid)} over {secs:.0f} s')
print('-- self'); [print(f'{c * 100 / n:5.1f}%  {s}') for s, c in self_c.most_common(25)]
print('-- first rpcs3 frame (driver/CRT time charged to its caller)'); [print(f'{c * 100 / n:5.1f}%  {s}') for s, c in own.most_common(40)]
print('-- inclusive'); [print(f'{c * 100 / n:5.1f}%  {s}') for s, c in incl.most_common(70)]
print('-- leaf <- caller'); [print(f'{c * 100 / n:5.1f}%  {s}') for s, c in pairs.most_common(15)]
