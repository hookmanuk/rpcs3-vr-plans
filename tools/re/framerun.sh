#!/bin/sh
# framerun.sh OUT STATE [XAT] [DUR]: one measured GT5 run with the per-frame log (RPCS3_VR_FRAMELOG) at Matt's settings:
# his GT5 config (Resolution Scale as configured) with cfgtemp VR on, Frame Rate Unlimited, Vblank 90 (uncapped), the
# simulator at his eye resolution (settings.json 2880x2880). Boots bin/savestates/BCUS98114/STATE, records DUR seconds
# (default 60) from the first frame, presses X once XAT seconds in (0: never; a temporary keyboard pad is added for it),
# takes no screenshots while measuring (the SHOT hook forces a GPU sync), one at the end (OUT_end.png). A load that
# shows no frame in 120 s is retried (up to 3 times). Config and pad restored. Then framelog.py: OUT.csv, OUT.png, table.
# Env EXTRA: more cfgtemp "Section/Key=value" settings for the run (e.g. "Video/MSAA=Disabled").
cd "$(dirname "$0")"
S=/c/Users/matt/AppData/Local/Temp/claude/f--rpsc3-source/883f1cb5-19ec-4918-a966-f3fa44f41ec5/scratchpad/frames
mkdir -p $S
out=$1; st=$2; xat=${3:-0}; dur=${4:-60}
L=/f/rpsc3/source/rpcs3/bin/log/RPCS3.log
P=/f/rpsc3/source/rpcs3/bin/config/input_configs/BCUS98114
padhad=0; [ -d "$P" ] && padhad=1
[ $padhad = 0 ] && [ "$xat" != 0 ] && { mkdir -p "$P"; cp ../keyboard-pad-template.yml "$P/Default.yml"; }
eval py -3.13 cfgtemp.py BCUS98114 set "\"Video/VR/Enabled=true\"" "\"Video/VR/Frame Rate=Unlimited\"" "\"Video/Vblank Rate=90\"" $EXTRA >/dev/null
# Performance runs measure the game, never DLSS or frame generation (env DLSS=1 keeps the game's DLSS settings).
[ "${DLSS:-0}" = 1 ] || py -3.13 cfgtemp.py BCUS98114 set "Video/VR/DLSS (experimental)=Off" "Video/VR/DLSS Frame Generation (experimental)=false" >/dev/null
ok=0
for try in 1 2 3; do
  powershell -NoProfile -Command "Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force"; sleep 3
  rm -f "$S/$out.csv"
  RPCS3_VR_FRAMELOG="C:\\Users\\matt\\AppData\\Local\\Temp\\claude\\f--rpsc3-source\\883f1cb5-19ec-4918-a966-f3fa44f41ec5\\scratchpad\\frames\\$out.csv" \
    powershell -File gboot.ps1 -Iso "F:/rpsc3/source/rpcs3/bin/savestates/BCUS98114/$st.SAVESTAT.zst" -Probe "render=1" >/dev/null 2>&1
  for i in $(seq 1 120); do [ "$(grep -c '^flip' "$S/$out.csv" 2>/dev/null)" -gt 5 ] && { ok=1; break; }; sleep 1; done
  [ $ok = 1 ] && break
  echo "$out: load $try showed no frames, retrying"
done
if [ $ok = 1 ]; then
  echo "$out: eyes $(grep -a 'Eye swapchains' $L | tail -1 | sed 's/.*swapchains //' | cut -c1-10), $(grep -a '  Resolution Scale:' $L | head -1 | tr -s ' '), $(grep -a '  MSAA:' $L | head -1 | tr -s ' ')"
  s=$SECONDS
  if [ "$xat" != 0 ]; then
    until [ $((SECONDS - s)) -ge "$xat" ]; do sleep 0.5; done
    sh keys.sh 'X 150 300\n'
  fi
  until [ $((SECONDS - s)) -ge "$dur" ]; do sleep 0.5; done
  py -3.13 shot.py BCUS98114 frames_end 960 >/dev/null 2>&1 && mv -f frames_end.png "$S/${out}_end.png" 2>/dev/null; rm -f frames_end.full.png
fi
powershell -c "Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force; \$t=0; while ((Get-Process rpcs3 -ErrorAction SilentlyContinue | Where-Object { \$_.Threads.Count -gt 1 }) -and \$t -lt 150) { Start-Sleep -Milliseconds 200; \$t++ }"
sleep 1
py -3.13 cfgtemp.py BCUS98114 restore >/dev/null
[ $padhad = 0 ] && [ -d "$P" ] && rm -r "${P:?}"
[ $ok = 1 ] && py -3.13 framelog.py "$S/$out.csv" "$S/$out.png"
true
