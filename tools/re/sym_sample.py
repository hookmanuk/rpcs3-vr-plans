"""sym_sample.py EXE_NAME THREAD SECONDS SYMS [HZ] (THREAD: a substring of the thread's description, or #N for the
N busiest threads by CPU time over one second, each profiled): leaf sampling profiler for a process built without a PDB
(mingw/clang: a `llvm-nm -n` symbol list, static functions included). Finds the process by image name, the thread
whose description (SetThreadDescription, SDL's thread names) contains THREAD_SUBSTR, suspends it HZ times a second
(default 2000), reads RIP and prints the functions by self samples. Addresses are rebased from the preferred image
base 0x140000000 to the loaded module base.
Example: python sym_sample.py ico_pc_x64.exe render 10 H:/ico-pc/dist/x64/ico_pc_x64.syms"""
import ctypes, sys, time, bisect, collections
from ctypes import wintypes as W

k = ctypes.windll.kernel32
psapi = ctypes.windll.psapi
k.OpenProcess.restype = W.HANDLE
k.OpenThread.restype = W.HANDLE
k.CreateToolhelp32Snapshot.restype = W.HANDLE


class TE(ctypes.Structure):
    _fields_ = [('dwSize', W.DWORD), ('cntUsage', W.DWORD), ('th32ThreadID', W.DWORD), ('th32OwnerProcessID', W.DWORD),
                ('tpBasePri', W.LONG), ('tpDeltaPri', W.LONG), ('dwFlags', W.DWORD)]


class PE(ctypes.Structure):
    _fields_ = [('dwSize', W.DWORD), ('cntUsage', W.DWORD), ('th32ProcessID', W.DWORD), ('th32DefaultHeapID', ctypes.c_void_p),
                ('th32ModuleID', W.DWORD), ('cntThreads', W.DWORD), ('th32ParentProcessID', W.DWORD), ('pcPriClassBase', W.LONG),
                ('dwFlags', W.DWORD), ('szExeFile', ctypes.c_char * 260)]


class M128(ctypes.Structure):
    _fields_ = [('lo', ctypes.c_ulonglong), ('hi', ctypes.c_longlong)]


class CONTEXT(ctypes.Structure):
    _pack_ = 16
    _fields_ = [('P1Home', ctypes.c_ulonglong), ('P2Home', ctypes.c_ulonglong), ('P3Home', ctypes.c_ulonglong),
                ('P4Home', ctypes.c_ulonglong), ('P5Home', ctypes.c_ulonglong), ('P6Home', ctypes.c_ulonglong),
                ('ContextFlags', W.DWORD), ('MxCsr', W.DWORD), ('SegCs', W.WORD), ('SegDs', W.WORD), ('SegEs', W.WORD),
                ('SegFs', W.WORD), ('SegGs', W.WORD), ('SegSs', W.WORD), ('EFlags', W.DWORD),
                ('Dr0', ctypes.c_ulonglong), ('Dr1', ctypes.c_ulonglong), ('Dr2', ctypes.c_ulonglong), ('Dr3', ctypes.c_ulonglong),
                ('Dr6', ctypes.c_ulonglong), ('Dr7', ctypes.c_ulonglong),
                ('Rax', ctypes.c_ulonglong), ('Rcx', ctypes.c_ulonglong), ('Rdx', ctypes.c_ulonglong), ('Rbx', ctypes.c_ulonglong),
                ('Rsp', ctypes.c_ulonglong), ('Rbp', ctypes.c_ulonglong), ('Rsi', ctypes.c_ulonglong), ('Rdi', ctypes.c_ulonglong),
                ('R8', ctypes.c_ulonglong), ('R9', ctypes.c_ulonglong), ('R10', ctypes.c_ulonglong), ('R11', ctypes.c_ulonglong),
                ('R12', ctypes.c_ulonglong), ('R13', ctypes.c_ulonglong), ('R14', ctypes.c_ulonglong), ('R15', ctypes.c_ulonglong),
                ('Rip', ctypes.c_ulonglong), ('rest', ctypes.c_byte * 1024)]


def find_pid(name):
    s = k.CreateToolhelp32Snapshot(2, 0); e = PE(); e.dwSize = ctypes.sizeof(PE); r = k.Process32First(s, ctypes.byref(e))
    while r:
        if e.szExeFile.decode(errors='ignore').lower() == name.lower():
            return e.th32ProcessID
        r = k.Process32Next(s, ctypes.byref(e))


def threads(p):
    s = k.CreateToolhelp32Snapshot(4, 0); e = TE(); e.dwSize = ctypes.sizeof(TE); out = []; r = k.Thread32First(s, ctypes.byref(e))
    while r:
        if e.th32OwnerProcessID == p:
            out.append(e.th32ThreadID)
        r = k.Thread32Next(s, ctypes.byref(e))
    return out


def tname(h):
    p = ctypes.c_wchar_p()
    try:
        if k.GetThreadDescription(h, ctypes.byref(p)) >= 0 and p.value:
            v = p.value; k.LocalFree(p); return v
    except Exception:
        pass
    return ''


def main():
    exe, sub, secs, symf = sys.argv[1], sys.argv[2].lower(), float(sys.argv[3]), sys.argv[4]
    hz = float(sys.argv[5]) if len(sys.argv) > 5 else 2000.0
    addrs, names = [], []
    for line in open(symf):
        a = line.split()
        if len(a) >= 3:
            addrs.append(int(a[0], 16)); names.append(a[2])
    pid = find_pid(exe)
    if not pid:
        print('no process', exe); return
    hp = k.OpenProcess(0x0410, False, pid)
    mods = (ctypes.c_void_p * 1)(); need = W.DWORD()
    psapi.EnumProcessModules(hp, mods, ctypes.sizeof(mods), ctypes.byref(need))
    base = mods[0] or 0x140000000
    delta = base - 0x140000000
    class FT(ctypes.Structure):
        _fields_ = [('lo', W.DWORD), ('hi', W.DWORD)]

    def cpu(h):
        c, e, kt, ut = FT(), FT(), FT(), FT()
        k.GetThreadTimes(h, ctypes.byref(c), ctypes.byref(e), ctypes.byref(kt), ctypes.byref(ut))
        return ((kt.hi << 32) | kt.lo) + ((ut.hi << 32) | ut.lo)

    hs = []
    for t in threads(pid):
        h = k.OpenThread(0x0002 | 0x0008 | 0x0040 | 0x0800, False, t)
        if h:
            hs.append((t, h, tname(h)))
    if sub.startswith('#'):
        n = int(sub[1:] or '1')
        c0 = {t: cpu(h) for t, h, _ in hs}
        time.sleep(1.0)
        ranked = sorted(hs, key=lambda x: cpu(x[1]) - c0[x[0]], reverse=True)
        busy = {x[0]: (cpu(x[1]) - c0[x[0]]) / 1e5 for x in ranked}
        targets = ranked[:n]
    else:
        targets = [x for x in hs if sub in x[2].lower()][:1]
        busy = {}
    if not targets:
        print('no thread matching', sub, [x[2] for x in hs]); return
    print(f'pid {pid} base {base:#x}')
    ctx = CONTEXT(); ctx.ContextFlags = 0x100001  # CONTEXT_AMD64 | CONTROL
    hits = {t: collections.Counter() for t, _, _ in targets}
    total = collections.Counter(); outside = collections.Counter()
    end = time.perf_counter() + secs; step = 1.0 / hz
    while time.perf_counter() < end:
        for t, h, _ in targets:
            if k.SuspendThread(h) == 0xFFFFFFFF:
                continue
            if k.GetThreadContext(h, ctypes.byref(ctx)):
                rip = ctx.Rip - delta
                i = bisect.bisect_right(addrs, rip) - 1
                if 0 <= i < len(addrs) and (i + 1 >= len(addrs) or rip < addrs[i + 1]) and rip - addrs[i] < 0x100000:
                    hits[t][names[i]] += 1
                else:
                    outside[t] += 1
                total[t] += 1
            k.ResumeThread(h)
        t0 = time.perf_counter()
        while time.perf_counter() - t0 < step:
            pass
    for t, _, nm in targets:
        n = total[t] or 1
        print(f'--- thread {t} "{nm}" CPU {busy.get(t, 0):.0f}% : {total[t]} samples, {100.0 * outside[t] / n:.1f}% outside the exe (system, driver, waits)')
        for f, c in hits[t].most_common(25):
            print(f'{100.0 * c / n:6.2f}%  {f}')


main()
