"""headsweep.py SECONDS AMP HZ: sweeps the simulator's real head yaw (sine); back to 0 at the end. Run while the game is up."""
import json, math, os, sys, time
d = os.path.join(os.environ['LOCALAPPDATA'], 'OpenXR-Simulator'); secs, amp, hz = float(sys.argv[1]), float(sys.argv[2]), float(sys.argv[3])
t0 = time.time(); open(os.environ.get("SWEEP_T0", os.devnull), "w").write(repr(t0))
def put(y):
    tmp = os.path.join(d, 'head_pose_command.json.tmp')
    with open(tmp, 'w') as f: json.dump({'x': 0.0, 'y': 0.0, 'z': 0.0, 'yaw': math.radians(y), 'pitch': 0.0, 'roll': 0.0}, f)
    for _ in range(5):
        try: os.replace(tmp, os.path.join(d, 'head_pose_command.json')); break
        except OSError: time.sleep(0.002)
while time.time() - t0 < secs:
    put(amp * math.sin(2 * math.pi * hz * (time.time() - t0))); time.sleep(0.01)
put(0)
