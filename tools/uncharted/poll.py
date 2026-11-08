"""poll.py ADDR SECONDS [STEP=0.25]: prints the running game's dword at ADDR (hex, host address) every STEP seconds, with
the time since start, only when it changes (and every 5 s)."""
import sys, time, struct
sys.path.insert(0, r'H:\uncharted_pc\tools\vr')
import memscan
a = int(sys.argv[1], 16); T = float(sys.argv[2]); step = float(sys.argv[3]) if len(sys.argv) > 3 else 0.25
t0 = time.time(); last = None; lastp = 0
while time.time() - t0 < T:
    d = memscan.read(a, 4)
    v = struct.unpack('<i', d)[0] if len(d) == 4 else None
    t = time.time() - t0
    if v != last or t - lastp > 5:
        print(f'{t:6.1f}s {v}', flush=True); last = v; lastp = t
    time.sleep(step)
