#!/bin/sh
# gt5shots.sh OUT [STATE=gt5_rome_prerace]: full-size RPCS3 screenshots of GT5's pre-race sequence at Matt's settings
# (cfgtemp: VR on, Frame Rate Unlimited, Vblank 90; env EXTRA for more settings, e.g. '"Video/MSAA=Disabled"'):
# the grid flyby 12 s after the first frame, then X, the TV-camera view 4 s later and the race 14 s later.
# Saved as scratchpad/frames/OUT_{grid,tv,race}.png (full size). Config and temporary keyboard pad restored.
cd "$(dirname "$0")"
S=/c/Users/matt/AppData/Local/Temp/claude/f--rpsc3-source/883f1cb5-19ec-4918-a966-f3fa44f41ec5/scratchpad/frames
mkdir -p $S
out=$1; st=${2:-gt5_rome_prerace}
L=/f/rpsc3/source/rpcs3/bin/log/RPCS3.log
P=/f/rpsc3/source/rpcs3/bin/config/input_configs/BCUS98114
padhad=0; [ -d "$P" ] && padhad=1
[ $padhad = 0 ] && { mkdir -p "$P"; cp ../keyboard-pad-template.yml "$P/Default.yml"; }
eval py -3.13 cfgtemp.py BCUS98114 set "\"Video/VR/Enabled=true\"" "\"Video/VR/Frame Rate=Unlimited\"" "\"Video/Vblank Rate=90\"" $EXTRA >/dev/null
ok=0
for try in 1 2 3; do
  powershell -NoProfile -Command "Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force"; sleep 3
  RPCS3_VR_FRAMESTATS=1 powershell -File gboot.ps1 -Iso "F:/rpsc3/source/rpcs3/bin/savestates/BCUS98114/$st.SAVESTAT.zst" -Probe "render=1" >/dev/null 2>&1
  for i in $(seq 1 120); do grep -aq "VR frame stats" $L && { ok=1; break; }; sleep 1; done
  [ $ok = 1 ] && break
  echo "$out: load $try showed no frames, retrying"
done
shot() { py -3.13 shot.py BCUS98114 gs_tmp 640 >/dev/null 2>&1 && mv -f gs_tmp.full.png "$S/${out}_$1.png"; rm -f gs_tmp.png; }
if [ $ok = 1 ]; then
  sleep 12; shot grid
  sh keys.sh 'X 150 300\n'; sleep 4; shot tv
  sleep 10; shot race
  echo "$out: shots taken"
fi
powershell -c "Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force; \$t=0; while ((Get-Process rpcs3 -ErrorAction SilentlyContinue | Where-Object { \$_.Threads.Count -gt 1 }) -and \$t -lt 150) { Start-Sleep -Milliseconds 200; \$t++ }"
sleep 1
py -3.13 cfgtemp.py BCUS98114 restore >/dev/null
[ $padhad = 0 ] && [ -d "$P" ] && rm -r "${P:?}"
true
