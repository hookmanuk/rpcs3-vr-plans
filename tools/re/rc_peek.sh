#!/bin/sh
# rc_peek.sh STATE OUT: load an R&C savestate flat (Vblank 60, pad), log the words in dumps/statevar_peek.txt every 15
# frames for 40 s (RPCS3_VR_PEEK through gboot's G_PEEK), copy the peek lines to OUT.
cd "$(dirname "$0")"
L=/f/rpsc3/source/rpcs3/bin/log/RPCS3.log
P=/f/rpsc3/source/rpcs3/bin/config/input_configs/BCUS98282; mkdir -p "$P"; cp ../keyboard-pad-template.yml "$P/Default.yml"
py -3.13 cfgtemp.py BCUS98282 set "Video/VR/Enabled=false" "Video/Vblank Rate=60" "Audio/Renderer=Null" >/dev/null
G_PEEK="$(cat dumps/statevar_peek.txt)" RPCS3_VR_PEEK_EVERY=15 RPCS3_VR_FRAMESTATS=1 timeout 60 powershell -File gboot.ps1 -Iso "F:/rpsc3/source/rpcs3/bin/savestates/BCUS98282/$1.SAVESTAT.zst" -Desktop >/dev/null 2>&1
for i in $(seq 1 240); do grep -aq "VR frame stats" $L && break; sleep 0.5; done
sleep ${PEEKWAIT:-40}
powershell -c "Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force"; sleep 2
py -3.13 cfgtemp.py BCUS98282 restore >/dev/null; rm -r "${P:?}"
grep -a "VR peek" $L > "$2"; wc -l "$2"
