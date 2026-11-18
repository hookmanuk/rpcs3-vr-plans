"""WARNING: the CPU figures here come from thread times (GetThreadTimes), which miss threads that wake thousands of
times a second and run briefly (the game's idle job workers): 2-4% here while Task Manager showed 44-70% (2026-11-18).
Use cycles.py / hotspots.py (cycle counts, what Task Manager shows); this file is their helper library.

cpusample.py [OUT.txt] [BUSY_PCT]: runs beside a bb-probe.exe the player is playing (start it any time; it waits
for the game and stops when the game exits). Every 5 s: the process CPU (% of all cores) and each thread's CPU; for
threads over BUSY_PCT (default 25) % of one core, 40 samples of where the thread is (suspend, read RIP, resume),
mapped to module+offset (the guest image is reported as GUEST+offset, from the 'Guest image at' line of the log if
given with LOG=path). Prints and appends to OUT (default H:/uc_tests/cpusample.txt)."""
import ctypes, ctypes.wintypes as W, collections, os, re, subprocess, sys, time

OUT = sys.argv[1] if len(sys.argv) > 1 else r'H:\uc_tests\cpusample.txt'
BUSY = float(sys.argv[2]) if len(sys.argv) > 2 else 25.0
k32 = ctypes.WinDLL('kernel32', use_last_error=True)
ntdll = ctypes.WinDLL('ntdll')
psapi = ctypes.WinDLL('psapi')
TH32CS_SNAPTHREAD = 4
PROCESS_QUERY = 0x0410
THREAD_ALL = 0x0002 | 0x0008 | 0x0040 | 0x0010  # suspend/resume, get context, query info


class THREADENTRY32(ctypes.Structure):
    _fields_ = [('dwSize', W.DWORD), ('cntUsage', W.DWORD), ('th32ThreadID', W.DWORD), ('th32OwnerProcessID', W.DWORD),
                ('tpBasePri', W.LONG), ('tpDeltaPri', W.LONG), ('dwFlags', W.DWORD)]


class CONTEXT(ctypes.Structure):  # x64, only the part up to Rip is read; buffer is the full size and aligned
    pass


CONTEXT_SIZE = 1232
CONTEXT_CONTROL = 0x100001


def pid_of(name='bb-probe.exe'):
    out = subprocess.run(['tasklist', '/FI', f'IMAGENAME eq {name}', '/FO', 'CSV', '/NH'], capture_output=True,
                         text=True).stdout
    m = re.search(r'"%s","(\d+)"' % re.escape(name), out)
    return int(m.group(1)) if m else None


def threads(pid):
    snap = k32.CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0)
    e = THREADENTRY32(); e.dwSize = ctypes.sizeof(e); ids = []
    ok = k32.Thread32First(snap, ctypes.byref(e))
    while ok:
        if e.th32OwnerProcessID == pid: ids.append(e.th32ThreadID)
        ok = k32.Thread32Next(snap, ctypes.byref(e))
    k32.CloseHandle(snap)
    return ids


def thread_time(h):
    c, x, kt, ut = W.FILETIME(), W.FILETIME(), W.FILETIME(), W.FILETIME()
    if not k32.GetThreadTimes(h, ctypes.byref(c), ctypes.byref(x), ctypes.byref(kt), ctypes.byref(ut)): return None
    f = lambda t: (t.dwHighDateTime << 32 | t.dwLowDateTime) / 1e7
    return f(kt) + f(ut)


def modules(proc):
    arr = (ctypes.c_void_p * 2048)(); need = W.DWORD()
    psapi.EnumProcessModulesEx(proc, arr, ctypes.sizeof(arr), ctypes.byref(need), 3)
    mods = []
    for i in range(need.value // 8):
        base = arr[i]; name = ctypes.create_unicode_buffer(260)
        psapi.GetModuleBaseNameW(proc, ctypes.c_void_p(base), name, 260)

        class MI(ctypes.Structure):
            _fields_ = [('base', ctypes.c_void_p), ('size', W.DWORD), ('entry', ctypes.c_void_p)]
        mi = MI(); psapi.GetModuleInformation(proc, ctypes.c_void_p(base), ctypes.byref(mi), ctypes.sizeof(mi))
        mods.append((base, base + mi.size, name.value))
    return mods


def where(rip, mods, guest):
    for b, e, n in mods:
        if b <= rip < e: return '%s+%#x' % (n, rip - b)
    if guest and guest <= rip < guest + 0x10000000: return 'GUEST+%#x' % (rip - guest)
    return '%#x' % (rip & ~0xfff)


def rip_of(h, buf):
    ctypes.memset(buf, 0, CONTEXT_SIZE)
    ctypes.c_uint32.from_address(ctypes.addressof(buf) + 0x30).value = CONTEXT_CONTROL
    if k32.SuspendThread(h) == 0xffffffff: return None
    try:
        if not k32.GetThreadContext(h, buf): return None
        return ctypes.c_uint64.from_address(ctypes.addressof(buf) + 0xF8).value
    finally:
        k32.ResumeThread(h)


def log(line):
    print(line, flush=True)
    with open(OUT, 'a') as f: f.write(line + '\n')


def main():
    raw = ctypes.create_string_buffer(CONTEXT_SIZE + 16)
    buf = (ctypes.c_char * CONTEXT_SIZE).from_address((ctypes.addressof(raw) + 15) & ~15)
    log('--- cpusample %s' % time.strftime('%H:%M:%S'))
    pid = None
    while not pid:
        pid = pid_of(); time.sleep(1) if not pid else None
    proc = k32.OpenProcess(PROCESS_QUERY, False, pid)
    ncpu = os.cpu_count(); handles = {}; last = {}; t0 = time.time(); mods = []; guest = 0
    while k32.WaitForSingleObject(proc, 0) != 0:
        if not guest and os.environ.get('LOG'):
            try:
                m = re.search(r'Guest image at ([0-9a-fA-F]+)', open(os.environ['LOG'], errors='replace').read(200000))
                guest = int(m.group(1), 16) if m else 0
            except OSError: pass
        if not mods or time.time() - t0 < 60: mods = modules(proc)
        now = {}
        for tid in threads(pid):
            if tid not in handles:
                h = k32.OpenThread(THREAD_ALL, False, tid)
                if not h: continue
                handles[tid] = h
            t = thread_time(handles[tid])
            if t is not None: now[tid] = t
        if last:
            dt = 5.0
            use = {tid: 100 * (now[tid] - last.get(tid, now[tid])) / dt for tid in now}
            total = sum(use.values()) / ncpu
            top = sorted(use.items(), key=lambda kv: -kv[1])
            log('%5.0fs  %5.1f%% of %d cores; top threads (%% of a core): %s' % (
                time.time() - t0, total, ncpu, ' '.join('%d:%.0f' % (tid, u) for tid, u in top[:10])))
            for tid, u in top:
                if u < BUSY: break
                hits = collections.Counter()
                for _ in range(40):
                    r = rip_of(handles[tid], buf)
                    if r: hits[where(r, mods, guest)] += 1
                    time.sleep(0.003)
                log('        thread %d (%.0f%%): %s' % (tid, u, ', '.join('%s x%d' % kv for kv in hits.most_common(6))))
        last = now
        time.sleep(5)
    log('--- game exited %s' % time.strftime('%H:%M:%S'))


if __name__ == '__main__':
    main()
