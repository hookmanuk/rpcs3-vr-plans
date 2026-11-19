"""hotspots.py [SECONDS] [THREADS]: where bb-probe.exe's busiest threads (by CPU cycles) spend their time, by
function. Measures every thread's cycles over 2 s, then samples the top THREADS (default 4) round-robin for SECONDS
(default 15; ~1 kHz each: suspend, read RIP, resume) and prints per thread the top functions (bb-probe.exe symbols
from llvm-nm, other modules by name, GUEST = the game's image)."""
import bisect, collections, ctypes, os, subprocess, sys, time
sys.path.insert(0, os.path.dirname(__file__))
from cpusample import threads, modules, rip_of, pid_of, CONTEXT_SIZE  # noqa: E402

secs = float(sys.argv[1]) if len(sys.argv) > 1 else 15.0
ntop = int(sys.argv[2]) if len(sys.argv) > 2 else 4
k32 = ctypes.WinDLL('kernel32', use_last_error=True)
exe = r'H:\uncharted_pc\out\bb-probe.exe'
syms = []
for line in subprocess.run([r'C:\msys64\clang64\bin\llvm-nm.exe', '-n', '--defined-only', '-C', exe],
                           capture_output=True, text=True, errors='replace').stdout.splitlines():
    p = line.split(' ', 2)
    if len(p) == 3 and p[1] in 'tTwW':
        try: syms.append((int(p[0], 16), p[2]))
        except ValueError: pass
syms.sort(); addrs = [a for a, _ in syms]
pid = pid_of(); proc = k32.OpenProcess(0x0410, False, pid); mods = modules(proc)
exe_base = next((b for b, e, n in mods if n.lower() == 'bb-probe.exe'), 0x140000000)


def name(rip):
    for b, e, n in mods:
        if b <= rip < e:
            if n.lower() != 'bb-probe.exe': return n
            a = rip - b + 0x140000000; i = bisect.bisect_right(addrs, a) - 1
            return (syms[i][1] if i >= 0 else '?')[:110]
    return 'GUEST/other'


hs = {}
for tid in threads(pid):
    h = k32.OpenThread(0x0002 | 0x0008 | 0x0040 | 0x0010, False, tid)
    if h: hs[tid] = h


def cyc(h):
    c = ctypes.c_ulonglong(); return c.value if k32.QueryThreadCycleTime(h, ctypes.byref(c)) else 0


c0 = {t: cyc(h) for t, h in hs.items()}; time.sleep(2); c1 = {t: cyc(h) for t, h in hs.items()}
top = sorted(hs, key=lambda t: -(c1[t] - c0[t]))[:ntop]
print('top threads (%% of a core): %s' % ' '.join('%d:%.0f' % (t, (c1[t] - c0[t]) / 2 / 4.7e9 * 100) for t in top))
raw = ctypes.create_string_buffer(CONTEXT_SIZE + 16)
buf = (ctypes.c_char * CONTEXT_SIZE).from_address((ctypes.addressof(raw) + 15) & ~15)
hits = {t: collections.Counter() for t in top}
end = time.time() + secs
while time.time() < end:
    for t in top:
        r = rip_of(hs[t], buf)
        if r: hits[t][name(r)] += 1
    time.sleep(0.001)
for t in top:
    n = sum(hits[t].values()) or 1
    print('\nthread %d (%d samples):' % (t, n))
    for f, c in hits[t].most_common(int(os.environ.get("HOT_N", "14"))):
        print('  %5.1f%%  %s' % (100 * c / n, f))
