#!/bin/sh
# simscreen.sh ID ISO OUT [WAIT] [SHOTS]: boot a disc on the OpenXR Simulator at Vblank 90 (merged into the game's
# config for the run, restored after) with a temporary keyboard pad, then SHOTS times (default 1), WAIT seconds apart
# (default 20): capture the headset view with the head straight (OUT_<n>_y0) and turned 25 degrees (OUT_<n>_y25).
# A screen fixed in the world moves between the two; a head-locked one does not. Prints the log's fixed-screen lines.
# No RPCS3 screenshots (the SHOT hook forces a GPU sync and hides stalls). Leaves RPCS3 closed.
id=$1; iso=$2; out=$3; wait=${4:-20}; shots=${5:-1}
cd "$(dirname "$0")"
C=/f/rpsc3/source/rpcs3/bin/config/custom_configs/config_$id.yml
had=0; [ -f "$C" ] && { had=1; cp "$C" "$C.simscreen.bak"; }
py -3.13 - "$C" <<'PY'
import sys, os, re
p = sys.argv[1]
s = open(p, encoding='utf8').read() if os.path.exists(p) else ''
if not re.search(r'^Video:\s*$', s, re.M):
    s = s + ('' if s.endswith('\n') or not s else '\n') + 'Video:\n'
if re.search(r'^  Vblank Rate:.*$', s, re.M):
    s = re.sub(r'^  Vblank Rate:.*$', '  Vblank Rate: 90', s, flags=re.M)
else:
    s = re.sub(r'^Video:\s*$', 'Video:\n  Vblank Rate: 90', s, count=1, flags=re.M)
open(p, 'w', encoding='utf8', newline='\n').write(s)
PY
P=/f/rpsc3/source/rpcs3/bin/config/input_configs/$id; padhad=0; [ -d "$P" ] && padhad=1
[ $padhad = 0 ] && { mkdir -p "$P"; cp ../keyboard-pad-template.yml "$P/Default.yml"; }
powershell -File simboot.ps1 -Iso "$iso" -Probe render=1 | tail -1
D="$LOCALAPPDATA/OpenXR-Simulator"
pose() { printf '{"x": 0, "y": 0, "z": 0, "yaw": %s, "pitch": 0, "roll": 0}' "$1" > "$D/head_pose_command.json.tmp" && mv "$D/head_pose_command.json.tmp" "$D/head_pose_command.json"; sleep 1.5; }
n=1
while [ $n -le $shots ]; do
  sleep "$wait"
  pose 0; py -3.13 simshot.py "${out}_${n}_y0" 960 >/dev/null
  pose 0.436; py -3.13 simshot.py "${out}_${n}_y25" 960 >/dev/null  # 25 degrees (the pose command takes radians)
  pose 0
  n=$((n + 1))
done
grep -a "VR: frames without camera draws\|VR: camera draws again\|OpenXR: Headset" /f/rpsc3/source/rpcs3/bin/log/RPCS3.log | cut -c1-140 | head -12
powershell -c "Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force; while (Get-Process rpcs3 -ErrorAction SilentlyContinue) { Start-Sleep -Milliseconds 200 }"; sleep 1
if [ $had = 1 ]; then mv -f "$C.simscreen.bak" "$C"; else rm -f "$C"; fi
[ $padhad = 0 ] && rm -r "${P:?}"
# Verify the clean-up: a leftover temporary config once survived a failed removal.
[ $had = 0 ] && [ -f "$C" ] && echo "WARNING: temporary $C still present"
[ $padhad = 0 ] && [ -d "$P" ] && echo "WARNING: temporary pad $P still present"
true
