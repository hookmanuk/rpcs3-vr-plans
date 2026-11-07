"""headmove.py SECONDS [SCALE]: moves the OpenXR Simulator's head slowly and continuously (turn, tilt and a few centimetres of movement), as a head in a headset never keeps still; ends back at 0."""
import json
import math
import os
import sys
import time

d = os.path.join(os.environ['LOCALAPPDATA'], 'OpenXR-Simulator')
seconds = float(sys.argv[1])
scale = float(sys.argv[2]) if len(sys.argv) > 2 else 1.0


def pose(x, y, z, yaw, pitch, roll):
    tmp = os.path.join(d, 'head_pose_command.json.tmp')
    with open(tmp, 'w') as f:
        json.dump({'x': x, 'y': y, 'z': z, 'yaw': yaw, 'pitch': pitch, 'roll': roll}, f)
    try:
        os.replace(tmp, os.path.join(d, 'head_pose_command.json'))
    except PermissionError:
        pass  # (the simulator has last time's open: the next one goes)


start = time.perf_counter()
while True:
    t = time.perf_counter() - start
    if t > seconds:
        break
    pose(0.04 * scale * math.sin(t * 1.1), 0.03 * scale * math.sin(t * 0.7), 0.04 * scale * math.sin(t * 0.9), math.radians(8 * scale * math.sin(t * 0.8)), math.radians(4 * scale * math.sin(t * 0.6)), math.radians(2 * scale * math.sin(t * 1.3)))
    time.sleep(0.02)
pose(0, 0, 0, 0, 0, 0)
