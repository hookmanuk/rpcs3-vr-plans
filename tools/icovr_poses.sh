#!/bin/bash
# icovr_poses.sh STAGE [SECONDS] [ENV=VALUE ...]: the ICO VR port on the simulator from ICO_START_STAGE=STAGE; after
# SECONDS (default 22) the head is turned by simpose.py (real simulator pose) to straight, yaw -20, yaw +20, pitch 10,
# roll 15 and both eyes dumped at each (pose_<STAGE>_<name>_L/R.png in the eyes folder). Head pose reset to straight
# at the end.
ST=$1; S=${2:-22}; shift 2
E=/c/Users/matt/AppData/Local/Temp/claude/4d94c0b8726ad438/a2506519-9380-442c-9fe4-e4dd90a66203/scratchpad/eyes
D='C:\Users\matt\AppData\Local\Temp\claude\4d94c0b8726ad438\a2506519-9380-442c-9fe4-e4dd90a66203\scratchpad\eyes'
P=/f/rpsc3/source/plans/tools/re/simpose.py
ENVS="ICO_VR_DUMP_DIR='$D'; ICO_START_STAGE='$ST'"
for kv in "$@"; do ENVS="$ENVS; ${kv%%=*}='${kv#*=}'"; done
python3 $P 0 0 0 >/dev/null
rm -f $E/eye_*.png $E/pid.txt
powershell.exe -NoProfile -Command "& F:\rpsc3\source\plans\tools\icovr_sim.ps1 -Env @{$ENVS} | Out-File -Encoding ascii '$D\pid.txt'" </dev/null >/dev/null 2>&1
id=$(tr -d '\r\n' < $E/pid.txt)
echo "game pid $id"
sleep $S
for pose in "straight 0 0 0" "yawL -20 0 0" "yawR 20 0 0" "pitch 0 10 0" "roll 0 0 15"; do
    set -- $pose
    python3 $P $2 $3 $4 >/dev/null
    sleep 2
    printf 1 > $E/dump
    sleep 3
    l=$(ls -t $E/eye_*_L.png 2>/dev/null | head -1); r=$(ls -t $E/eye_*_R.png 2>/dev/null | head -1)
    if [ -n "$l" ]; then mv "$l" $E/pose_${ST}_$1_L.png; mv "$r" $E/pose_${ST}_$1_R.png; echo "$1 dumped"; else echo "$1: no dump"; fi
done
python3 $P 0 0 0 >/dev/null
taskkill //F //PID $id >/dev/null 2>&1
rm -f $E/chain_*.png
