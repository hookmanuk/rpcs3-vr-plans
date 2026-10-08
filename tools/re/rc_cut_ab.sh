#!/bin/sh
# rc_cut_ab.sh TAG VBLANK [STATE]: load an R&C savestate flat (VR off, Null audio) at that Vblank Rate, shots at 3 s
# and 8 s after the first frame (rc_cut_TAG_3, rc_cut_TAG_8), then stop and restore the config.
cd "$(dirname "$0")"
L=/f/rpsc3/source/rpcs3/bin/log/RPCS3.log
P=/f/rpsc3/source/rpcs3/bin/config/input_configs/BCUS98282; padhad=0; [ -d "$P" ] && padhad=1
[ $padhad = 0 ] && { mkdir -p "$P"; cp ../keyboard-pad-template.yml "$P/Default.yml"; }
py -3.13 cfgtemp.py BCUS98282 set "Video/VR/Enabled=${VR:-false}" "Video/VR/Frame Rate=Unlimited" "Video/Vblank Rate=$2" "Audio/Renderer=Null" >/dev/null
ARG=-Desktop; [ "${VR:-false}" = true ] && ARG="-Probe render=1"
RPCS3_VR_FRAMESTATS=1 timeout 60 powershell -File gboot.ps1 -Iso "F:/rpsc3/source/rpcs3/bin/savestates/BCUS98282/${3:-rc3_open_cutscene}.SAVESTAT.zst" $ARG >/dev/null 2>&1
for i in $(seq 1 240); do grep -aq "VR frame stats" $L && break; sleep 0.5; done
sleep 2; SHOT_MOVE=1 py -3.13 shot.py BCUS98282 rc_cut_$1_3 960 >/dev/null 2>&1
sleep 4.5; SHOT_MOVE=1 py -3.13 shot.py BCUS98282 rc_cut_$1_8 960 >/dev/null 2>&1
powershell -c "Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force"; sleep 2
py -3.13 cfgtemp.py BCUS98282 restore >/dev/null
[ $padhad = 0 ] && rm -r "${P:?}"
