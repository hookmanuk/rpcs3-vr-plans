# Sampling profiler for a running process: suspends threads, walks stacks with dbghelp, aggregates.
import ctypes, ctypes.wintypes as wt, sys, time, collections
k32 = ctypes.WinDLL('kernel32', use_last_error=True)
dbg = ctypes.WinDLL(r'C:\Windows\System32\dbghelp.dll', use_last_error=True)
TH32CS_SNAPTHREAD = 4
class THREADENTRY32(ctypes.Structure):
    _fields_ = [('dwSize', wt.DWORD), ('cntUsage', wt.DWORD), ('th32ThreadID', wt.DWORD), ('th32OwnerProcessID', wt.DWORD),
                ('tpBasePri', ctypes.c_long), ('tpDeltaPri', ctypes.c_long), ('dwFlags', wt.DWORD)]
class ADDRESS64(ctypes.Structure):
    _fields_ = [('Offset', ctypes.c_uint64), ('Segment', ctypes.c_uint16), ('Mode', ctypes.c_uint32)]
class KDHELP64(ctypes.Structure):
    _fields_ = [('Thread', ctypes.c_uint64), ('ThCallbackStack', wt.DWORD), ('ThCallbackBStore', wt.DWORD), ('NextCallback', wt.DWORD),
                ('FramePointer', wt.DWORD), ('KiCallUserMode', ctypes.c_uint64), ('KeUserCallbackDispatcher', ctypes.c_uint64),
                ('SystemRangeStart', ctypes.c_uint64), ('KiUserExceptionDispatcher', ctypes.c_uint64), ('StackBase', ctypes.c_uint64),
                ('StackLimit', ctypes.c_uint64), ('BuildVersion', wt.DWORD), ('RetpolineStubFunctionTableSize', wt.DWORD),
                ('RetpolineStubFunctionTable', ctypes.c_uint64), ('RetpolineStubOffset', wt.DWORD), ('RetpolineStubSize', wt.DWORD),
                ('Reserved0', ctypes.c_uint64 * 2)]
class STACKFRAME64(ctypes.Structure):
    _fields_ = [('AddrPC', ADDRESS64), ('AddrReturn', ADDRESS64), ('AddrFrame', ADDRESS64), ('AddrStack', ADDRESS64),
                ('AddrBStore', ADDRESS64), ('FuncTableEntry', ctypes.c_void_p), ('Params', ctypes.c_uint64 * 4), ('Far', wt.BOOL),
                ('Virtual', wt.BOOL), ('Reserved', ctypes.c_uint64 * 3), ('KdHelp', KDHELP64)]
CONTEXT_SIZE = 1232
CONTEXT_FULL = 0x10000B
class SYMBOL_INFO(ctypes.Structure):
    _fields_ = [('SizeOfStruct', wt.ULONG), ('TypeIndex', wt.ULONG), ('Reserved', ctypes.c_uint64 * 2), ('Index', wt.ULONG), ('Size', wt.ULONG),
                ('ModBase', ctypes.c_uint64), ('Flags', wt.ULONG), ('Value', ctypes.c_uint64), ('Address', ctypes.c_uint64), ('Register', wt.ULONG),
                ('Scope', wt.ULONG), ('Tag', wt.ULONG), ('NameLen', wt.ULONG), ('MaxNameLen', wt.ULONG), ('Name', ctypes.c_char * 512)]
k32.OpenProcess.restype = wt.HANDLE; k32.OpenThread.restype = wt.HANDLE
dbg.SymFunctionTableAccess64.restype = ctypes.c_void_p; dbg.SymFunctionTableAccess64.argtypes = [wt.HANDLE, ctypes.c_uint64]
dbg.SymGetModuleBase64.restype = ctypes.c_uint64; dbg.SymGetModuleBase64.argtypes = [wt.HANDLE, ctypes.c_uint64]
dbg.StackWalk64.argtypes = [wt.DWORD, wt.HANDLE, wt.HANDLE, ctypes.POINTER(STACKFRAME64), ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p]
FTA = ctypes.WINFUNCTYPE(ctypes.c_void_p, wt.HANDLE, ctypes.c_uint64)(lambda h, a: dbg.SymFunctionTableAccess64(h, a))
GMB = ctypes.WINFUNCTYPE(ctypes.c_uint64, wt.HANDLE, ctypes.c_uint64)(lambda h, a: dbg.SymGetModuleBase64(h, a))

def main(pid, seconds, depth, bindir, pat=''):
    hp = k32.OpenProcess(0x1F0FFF, False, pid)
    dbg.SymSetOptions(0x2 | 0x10)  # UNDNAME | DEFERRED_LOADS
    assert dbg.SymInitialize(hp, bindir.encode(), True), ctypes.get_last_error()
    snap = k32.CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0)
    te = THREADENTRY32(); te.dwSize = ctypes.sizeof(te); tids = []
    ok = k32.Thread32First(snap, ctypes.byref(te))
    while ok:
        if te.th32OwnerProcessID == pid: tids.append(te.th32ThreadID)
        ok = k32.Thread32Next(snap, ctypes.byref(te))
    threads = {}
    k32.GetThreadDescription.argtypes = [wt.HANDLE, ctypes.POINTER(ctypes.c_wchar_p)]
    for tid in tids:
        h = k32.OpenThread(0x0002 | 0x0008 | 0x0040 | 0x0800, False, tid)
        if not h: continue
        p = ctypes.c_wchar_p(); k32.GetThreadDescription(h, ctypes.byref(p)); name = p.value or str(tid)
        if pat and not any(x in name for x in pat.split(',')): continue
        threads[tid] = (h, name)
    buf = ctypes.create_string_buffer(CONTEXT_SIZE + 16)
    base = (ctypes.addressof(buf) + 15) & ~15
    stacks = collections.defaultdict(collections.Counter); nsamp = collections.Counter()
    end = time.perf_counter() + seconds
    while time.perf_counter() < end:
        for tid, (h, name) in threads.items():
            if k32.SuspendThread(h) == 0xFFFFFFFF: continue
            ctypes.memset(base, 0, CONTEXT_SIZE)
            ctypes.c_uint32.from_address(base + 0x30).value = CONTEXT_FULL
            frames = []
            if k32.GetThreadContext(h, ctypes.c_void_p(base)):
                sf = STACKFRAME64()
                sf.AddrPC.Offset = ctypes.c_uint64.from_address(base + 0xF8).value; sf.AddrPC.Mode = 3
                sf.AddrStack.Offset = ctypes.c_uint64.from_address(base + 0x98).value; sf.AddrStack.Mode = 3
                sf.AddrFrame.Offset = ctypes.c_uint64.from_address(base + 0xA0).value; sf.AddrFrame.Mode = 3
                for _ in range(depth):
                    if not dbg.StackWalk64(0x8664, hp, h, ctypes.byref(sf), ctypes.c_void_p(base), None, FTA, GMB, None): break
                    if not sf.AddrPC.Offset: break
                    frames.append(sf.AddrPC.Offset)
            k32.ResumeThread(h)
            stacks[name][tuple(frames)] += 1; nsamp[name] += 1
        time.sleep(0.0005)
    cache = {}
    def sym(a):
        if a in cache: return cache[a]
        si = SYMBOL_INFO(); si.SizeOfStruct = 88; si.MaxNameLen = 511
        disp = ctypes.c_uint64()
        r = dbg.SymFromAddr(hp, ctypes.c_uint64(a), ctypes.byref(disp), ctypes.byref(si))
        cache[a] = si.Name.decode(errors='replace') if r else hex(a)
        return cache[a]
    def modbase(a):
        return dbg.SymGetModuleBase64(hp, a)
    return stacks, nsamp, sym, modbase

if __name__ == '__main__':
    pid = int(sys.argv[1]); secs = float(sys.argv[2]); pat = sys.argv[3] if len(sys.argv) > 3 else ''
    stacks, nsamp, sym, modbase = main(pid, secs, 40, 'F:/rpsc3/source/rpcs3/bin', pat)
    for name in sorted(nsamp, key=lambda n: -nsamp[n]):
        if pat and not any(p in name for p in pat.split(',')): continue
        total = nsamp[name]
        leaf = collections.Counter(); incl = collections.Counter()
        for st, c in stacks[name].items():
            names = [sym(a) for a in st]
            leaf[names[0] if names else '?'] += c
            for n in set(names): incl[n] += c
        print(f'=== {name}: {total} samples')
        print('  leaf:'); [print(f'    {c*100/total:5.1f}% {n[:110]}') for n, c in leaf.most_common(12)]
        print('  inclusive:'); [print(f'    {c*100/total:5.1f}% {n[:110]}') for n, c in incl.most_common(30)]
        # external (driver/OS) time attributed to the first rpcs3 caller, with the caller's caller
        rb = None
        for st in stacks[name]:
            for a in st:
                if 'named_thread' in sym(a): rb = modbase(a); break
            if rb: break
        ext = collections.Counter()
        for st, c in stacks[name].items():
            if not st or modbase(st[0]) == rb: continue
            chain = [sym(a) for a in st if modbase(a) == rb][:3]
            ext[' <- '.join(x[:60] for x in chain)] += c
        print('  outside rpcs3, by caller:'); [print(f'    {c*100/total:5.1f}% {n}') for n, c in ext.most_common(25)]
