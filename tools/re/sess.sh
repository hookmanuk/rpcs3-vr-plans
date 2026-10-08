#!/bin/sh
# sess.sh start ID STATE [SCALE=300] | stop ID: an interactive VR session on the OpenXR Simulator for driving a game step
# by step (keys.sh for input, simshot.py / simpose.py for looks). start: as posecheck.sh (cfgtemp VR on, Frame Rate
# Unlimited, Null audio, keyboard pad from the template when the game has none) and returns once frame stats appear.
# stop: kills rpcs3, restores the config and removes a pad it added (marker file .sess_pad_ID).
cd "$(dirname "$0")"
cmd=$1; id=$2; st=$3; sc=${4:-300}
L=/f/rpsc3/source/rpcs3/bin/log/RPCS3.log
P=/f/rpsc3/source/rpcs3/bin/config/input_configs/$id
if [ "$cmd" = start ]; then
  [ -d "$P" ] || { mkdir -p "$P"; cp ../keyboard-pad-template.yml "$P/Default.yml"; touch ".sess_pad_$id"; }
  py -3.13 cfgtemp.py $id set "Video/VR/Enabled=true" "Video/VR/Frame Rate=Unlimited" "Video/Resolution Scale=$sc" "Audio/Renderer=Null" >/dev/null
  py -3.13 simpose.py 0 0 0 >/dev/null
  RPCS3_VR_FRAMESTATS=1 timeout 60 powershell -File gboot.ps1 -Iso "F:/rpsc3/source/rpcs3/bin/savestates/$id/$st.SAVESTAT.zst" -Probe ${PROBE:-render=1} >/dev/null 2>&1
  sleep 8; powershell -File simwin.ps1 >/dev/null 2>&1
  for i in $(seq 1 240); do grep -aq "VR frame stats" $L && break; sleep 0.5; done
  echo started
else
  py -3.13 simpose.py 0 0 0 >/dev/null
  powershell -c "Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force; \$t=0; while ((Get-Process rpcs3 -ErrorAction SilentlyContinue) -and \$t -lt 150) { Start-Sleep -Milliseconds 200; \$t++ }"
  sleep 1; py -3.13 cfgtemp.py $id restore >/dev/null
  [ -f ".sess_pad_$id" ] && { rm -r "${P:?}"; rm ".sess_pad_$id"; }
  echo stopped
fi
