"""cycles.py [SECONDS] [SAMPLES]: CPU use of bb-probe.exe by CPU cycles (QueryThreadCycleTime: what Task Manager
counts; thread times from GetThreadTimes miss threads that wake often and run briefly). Per thread over SECONDS
(default 3): cycles as % of all cores at the measured clock, context switches; for the top threads, SAMPLES RIP
samples mapped to module+offset (GUEST = the game's image)."""
import ctypes, ctypes.wintypes as W, collections, os, re, subprocess, sys, time
sys.path.insert(0, os.path.dirname(__file__))
k32 = ctypes.WinDLL('kernel32', use_last_error=True)
ntdll = ctypes.WinDLL('ntdll')
from cpusample import threads, modules, where, rip_of, pid_of, CONTEXT_SIZE  # noqa: E402

secs = float(sys.argv[1]) if len(sys.argv) > 1 else 3.0
nsamp = int(sys.argv[2]) if len(sys.argv) > 2 else 60
pid = pid_of()
proc = k32.OpenProcess(0x0410, False, pid)
log = os.environ.get('LOG', r'H:\uc_tests\matt_chapters\last_run.log')
try:
    m = re.search(r'Guest image at ([0-9a-fA-F]+)', open(log, errors='replace').read(400000)); guest = int(m.group(1), 16) if m else 0
except OSError:
    guest = 0
mods = modules(proc)


class SPI(ctypes.Structure):  # SYSTEM_THREAD_INFORMATION is complex: use per-thread cycle counts only
    pass


def cycles(h):
    c = ctypes.c_ulonglong()
    return c.value if k32.QueryThreadCycleTime(h, ctypes.byref(c)) else None


hs = {}
for tid in threads(pid):
    h = k32.OpenThread(0x0002 | 0x0008 | 0x0040 | 0x0010, False, tid)
    if h: hs[tid] = h
pc = ctypes.c_ulonglong(); k32.QueryProcessCycleTime(proc, ctypes.byref(pc)); p0 = pc.value
c0 = {t: cycles(h) for t, h in hs.items()}
t0 = time.perf_counter(); time.sleep(secs); dt = time.perf_counter() - t0
k32.QueryProcessCycleTime(proc, ctypes.byref(pc)); p1 = pc.value
c1 = {t: cycles(h) for t, h in hs.items()}
hz = 4.7e9  # measured clock (Processor Frequency counter: 4700 MHz)
ncpu = os.cpu_count()
print('process: %.1f%% of all %d cores by cycles (at %.1f GHz)' % (100 * (p1 - p0) / dt / hz / ncpu, ncpu, hz / 1e9))
use = sorted(((t, (c1[t] - c0[t]) / dt / hz * 100) for t in hs if c0[t] is not None and c1[t] is not None), key=lambda x: -x[1])
print('top threads (% of one core): ' + ' '.join('%d:%.0f' % x for x in use[:14]))
raw = ctypes.create_string_buffer(CONTEXT_SIZE + 16)
buf = (ctypes.c_char * CONTEXT_SIZE).from_address((ctypes.addressof(raw) + 15) & ~15)
for tid, u in use[:8]:
    if u < 5: break
    hits = collections.Counter()
    for _ in range(nsamp):
        r = rip_of(hs[tid], buf)
        if r: hits[where(r, mods, guest)] += 1
        time.sleep(0.002)
    print('  thread %d (%.0f%%): %s' % (tid, u, ', '.join('%s x%d' % kv for kv in hits.most_common(8))))
