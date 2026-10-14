"""headturn.py SECONDS [YAW_DEG=12] [HZ=1.0] [NECK_M=0.10] [TRANSLATE=1]: turn the OpenXR Simulator's head left and right (yaw
+-YAW at HZ) as a real head does: the eyes on a NECK_M pivot behind them, so they move sideways and back with the turn
(TRANSLATE=0: rotation only). Sets the real pose ~100 times a second; back to straight ahead at the end."""
import json, math, os, sys, time
d = os.path.join(os.environ['LOCALAPPDATA'], 'OpenXR-Simulator')
secs = float(sys.argv[1]); amp = float(sys.argv[2]) if len(sys.argv) > 2 else 12; hz = float(sys.argv[3]) if len(sys.argv) > 3 else 1.0
neck = float(sys.argv[4]) if len(sys.argv) > 4 else 0.10; tr = (sys.argv[5] if len(sys.argv) > 5 else '1') == '1'
def pose(yaw):
    r = math.radians(yaw)
    # pivot neck metres behind the eyes: eye position relative to the straight-ahead pose
    x, z = (-neck * math.sin(r), neck * (1 - math.cos(r))) if tr else (0.0, 0.0)
    cmd = {'x': x, 'y': 0.0, 'z': z, 'yaw': r, 'pitch': 0.0, 'roll': 0.0}
    tmp = os.path.join(d, 'head_pose_command.json.tmp')
    with open(tmp, 'w') as f: json.dump(cmd, f)
    for _ in range(20):
        try:
            os.replace(tmp, os.path.join(d, 'head_pose_command.json')); return
        except PermissionError:
            time.sleep(0.002)
t0 = time.time(); end = t0 + secs
while time.time() < end:
    pose(amp * math.sin((time.time() - t0) * 2 * math.pi * hz)); time.sleep(0.01)
pose(0)
