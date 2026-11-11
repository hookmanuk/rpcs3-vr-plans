#!/bin/sh
# gt5burst.sh OUT [STATE=gt5_busy_race_2_17] [N=8]: N full-size RPCS3 screenshots in a row of a (paused) GT5 savestate at
# Matt's settings (cfgtemp: VR on, Frame Rate Unlimited, Vblank 90; env EXTRA for more settings), 20 s after the first
# frame, to see frame-to-frame flicker (a paused scene should not change). Saved as scratchpad/frames/OUT_<i>.png.
cd "$(dirname "$0")"
S=/c/Users/matt/AppData/Local/Temp/claude/f--rpsc3-source/883f1cb5-19ec-4918-a966-f3fa44f41ec5/scratchpad/frames
mkdir -p $S
out=$1; st=${2:-gt5_busy_race_2_17}; n=${3:-8}
L=/f/rpsc3/source/rpcs3/bin/log/RPCS3.log
eval py -3.13 cfgtemp.py BCUS98114 set "\"Video/VR/Enabled=true\"" "\"Video/VR/Frame Rate=Unlimited\"" "\"Video/Vblank Rate=90\"" $EXTRA >/dev/null
ok=0
for try in 1 2 3; do
  powershell -NoProfile -Command "Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force"; sleep 3
  RPCS3_VR_FRAMESTATS=1 powershell -File gboot.ps1 -Iso "F:/rpsc3/source/rpcs3/bin/savestates/BCUS98114/$st.SAVESTAT.zst" -Probe "render=1" >/dev/null 2>&1
  for i in $(seq 1 120); do grep -aq "VR frame stats" $L && { ok=1; break; }; sleep 1; done
  [ $ok = 1 ] && break
  echo "$out: load $try showed no frames, retrying"
done
if [ $ok = 1 ]; then
  sleep 20
  for i in $(seq 1 $n); do py -3.13 shot.py BCUS98114 gb_tmp 640 >/dev/null 2>&1 && mv -f gb_tmp.full.png "$S/${out}_$i.png"; rm -f gb_tmp.png; done
  echo "$out: $n shots"
fi
powershell -c "Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force; \$t=0; while ((Get-Process rpcs3 -ErrorAction SilentlyContinue | Where-Object { \$_.Threads.Count -gt 1 }) -and \$t -lt 150) { Start-Sleep -Milliseconds 200; \$t++ }"
sleep 1
py -3.13 cfgtemp.py BCUS98114 restore >/dev/null
true
