"""simhold.py YAW PITCH ROLL SECONDS [X Y Z]: holds the OpenXR Simulator's real head pose by rewriting its command file
(degrees), then puts 0 back. (One simpose.py command holds too; the poses that "did not stick" on 2026-11-14 were the
port's pose latch freezing the head at exactly zero with a still camera, fixed in uncharted_pc c6d90b4.)"""
import json, math, os, sys, time
d = os.path.join(os.environ['LOCALAPPDATA'], 'OpenXR-Simulator')
yaw, pitch, roll, seconds = (float(a) for a in sys.argv[1:5])
hz = 100
pos = [float(v) for v in sys.argv[5:8]] if len(sys.argv) > 7 else [0.0, 0.0, 0.0]  # X Y Z metres (optional)


def put(y, p, r):
    tmp = os.path.join(d, 'head_pose_command.json.tmp%d' % os.getpid())
    with open(tmp, 'w') as f:
        json.dump({'x': pos[0], 'y': pos[1], 'z': pos[2], 'yaw': math.radians(y), 'pitch': math.radians(p), 'roll': math.radians(r)}, f)
    for _ in range(5):
        try:
            os.replace(tmp, os.path.join(d, 'head_pose_command.json'))
            return
        except PermissionError:
            time.sleep(0.001)


t0 = time.perf_counter()
while time.perf_counter() - t0 < seconds:
    put(yaw, pitch, roll)
    time.sleep(1 / hz)
pos = [0.0, 0.0, 0.0]
put(0, 0, 0)
