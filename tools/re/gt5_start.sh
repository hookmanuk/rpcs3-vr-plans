#!/bin/sh
# gt5_start.sh OUT [VBLANK=90] [SCALE=400] [PROBE=render=1]: GT5 race start on the OpenXR Simulator with Matt's own game
# config (cfgtemp: VR on, Frame Rate Unlimited, Vblank, scale, Null audio; restored after). Boots the pre-race savestate
# gt5_indy_prerace (Arcade, Superspeedway Indy, Fiat 500, rolling start), waits 6 s on the grid screen, presses X and
# holds R2. Logs one frame-stats line per second to OUT.txt and simulator shots OUT_<s>.png at 3, 8, 15, 25 s.
# Env GBOOT_ARGS (e.g. -Desktop), EXTRA (more cfgtemp "Section/Key=value" args), STATE (default gt5_indy_prerace).
cd "$(dirname "$0")"
out=$1; vb=${2:-90}; sc=${3:-400}; probe=${4:-render=1}; st=${STATE:-gt5_indy_prerace}
L=/f/rpsc3/source/rpcs3/bin/log/RPCS3.log
P=/f/rpsc3/source/rpcs3/bin/config/input_configs/BCUS98114
padhad=0; [ -d "$P" ] && padhad=1
[ $padhad = 0 ] && { mkdir -p "$P"; cp ../keyboard-pad-template.yml "$P/Default.yml"; }
eval py -3.13 cfgtemp.py BCUS98114 set "\"Video/VR/Enabled=true\"" "\"Video/VR/Frame Rate=Unlimited\"" "\"Video/Vblank Rate=$vb\"" "\"Video/Resolution Scale=$sc\"" "\"Audio/Renderer=\\\"Null\\\"\"" $EXTRA >/dev/null
RPCS3_VR_FRAMESTATS=1 timeout 300 powershell -File gboot.ps1 -Iso "F:/rpsc3/source/rpcs3/bin/savestates/BCUS98114/$st.SAVESTAT.zst" -Probe "$probe" $GBOOT_ARGS >/dev/null 2>&1
for i in $(seq 1 240); do grep -aq "VR frame stats" $L && break; sleep 0.5; done
powershell -File simwin.ps1 >/dev/null 2>&1
sleep 6
n0=$(grep -a -c "VR frame stats" $L)
sh keys.sh 'X 150 300\nW 30000 100\n'
s=$SECONDS
for t in 3 8 15 25; do until [ $((SECONDS-s)) -ge $t ]; do sleep 0.5; done; py -3.13 simshot.py "${out}_$t" 640 >/dev/null 2>&1; done
until [ $((SECONDS-s)) -ge 32 ]; do sleep 1; done
grep -a "VR frame stats" $L | tail -n +$((n0-5)) | sed 's/.*stats: //' | cut -c1-150 > "$out.txt"
powershell -c "Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force; while (Get-Process rpcs3 -ErrorAction SilentlyContinue) { Start-Sleep -Milliseconds 200 }"
sleep 1
py -3.13 cfgtemp.py BCUS98114 restore >/dev/null
[ $padhad = 0 ] && rm -r "${P:?}"
true
