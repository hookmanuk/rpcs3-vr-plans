"""simpose.py YAW_DEG [PITCH_DEG] [ROLL_DEG]: sets the OpenXR Simulator's head pose (one-shot command file
head_pose_command.json; position 0, 0, 0: the simulator's own start of y = 1.7 m puts the HUD box low). Unlike RPCS3_VR_YAW_FILE this turns the real head, so compositor layers
(the fixed screen, overlays) move with it."""
import json, math, os, sys
d = os.path.join(os.environ['LOCALAPPDATA'], 'OpenXR-Simulator')
yaw, pitch, roll = (float(a) for a in (sys.argv[1:] + ['0', '0', '0'])[:3])
cmd = {'x': 0.0, 'y': 0.0, 'z': 0.0, 'yaw': math.radians(yaw), 'pitch': math.radians(pitch), 'roll': math.radians(roll)}
tmp = os.path.join(d, 'head_pose_command.json.tmp')
with open(tmp, 'w') as f: json.dump(cmd, f)
os.replace(tmp, os.path.join(d, 'head_pose_command.json'))
print('head pose', cmd)
