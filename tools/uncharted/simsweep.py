"""simsweep.py SECONDS [AMPLITUDE_DEG=25] [PERIOD_S=2.0] [HZ=250]: sweeps the OpenXR Simulator's real head pose in yaw,
amplitude * sin(2 pi t / period), writing its one-shot command file HZ times a second, then puts the head back to 0.
Prints the start time (steady clock, us) so a log's lines can be lined up with the sweep."""
import json, math, os, sys, time
d = os.path.join(os.environ['LOCALAPPDATA'], 'OpenXR-Simulator')
seconds = float(sys.argv[1]) if len(sys.argv) > 1 else 6
amp = float(sys.argv[2]) if len(sys.argv) > 2 else 25
period = float(sys.argv[3]) if len(sys.argv) > 3 else 2.0
hz = float(sys.argv[4]) if len(sys.argv) > 4 else 250


def put(yaw):
    cmd = {'x': 0.0, 'y': 0.0, 'z': 0.0, 'yaw': math.radians(yaw), 'pitch': 0.0, 'roll': 0.0}
    tmp = os.path.join(d, 'head_pose_command.json.tmp')
    with open(tmp, 'w') as f:
        json.dump(cmd, f)
    for _ in range(5):
        try:
            os.replace(tmp, os.path.join(d, 'head_pose_command.json'))
            return
        except PermissionError:
            time.sleep(0.001)


t0 = time.perf_counter()
print('sweep start', int(time.monotonic() * 1e6), flush=True)
while True:
    t = time.perf_counter() - t0
    if t > seconds:
        break
    put(amp * math.sin(2 * math.pi * t / period))
    time.sleep(1 / hz)
put(0)
print('sweep end', flush=True)
