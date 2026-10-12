#!/bin/sh
# prerace_seq.sh OUT [STATE=gt5_rome_prerace] [VBLANK=60] [SCALE=400]: GT5 from a pre-race grid savestate: X after 6 s,
# then 40 s of 1 s frame stats and a desktop shot (shot.py) every 3 s, to see each pre-race scene's frame rate.
# Matt's GT5 config with cfgtemp (VR on, Frame Rate Unlimited, Vblank, scale), temporary keyboard pad; both restored.
cd "$(dirname "$0")"
out=$1; st=${2:-gt5_rome_prerace}; vb=${3:-60}; sc=${4:-400}
L=/f/rpsc3/source/rpcs3/bin/log/RPCS3.log
P=/f/rpsc3/source/rpcs3/bin/config/input_configs/BCUS98114
padhad=0; [ -d "$P" ] && padhad=1
[ $padhad = 0 ] && { mkdir -p "$P"; cp ../keyboard-pad-template.yml "$P/Default.yml"; }
py -3.13 cfgtemp.py BCUS98114 set "Video/VR/Enabled=true" "Video/VR/Frame Rate=Unlimited" "Video/Vblank Rate=$vb" "Video/Resolution Scale=$sc" >/dev/null
RPCS3_VR_FRAMESTATS=1 powershell -File gboot.ps1 -Iso "F:/rpsc3/source/rpcs3/bin/savestates/BCUS98114/$st.SAVESTAT.zst" -Probe "render=1" >/dev/null 2>&1
for i in $(seq 1 240); do grep -aq "VR frame stats" $L && break; sleep 0.5; done
if ! grep -aq "VR frame stats" $L; then
  echo "no frames (load failed)"
  powershell -c "Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force"; sleep 2
  py -3.13 cfgtemp.py BCUS98114 restore >/dev/null; [ $padhad = 0 ] && rm -r "${P:?}"
  exit 2
fi
sleep 6
n0=$(grep -a -c "VR frame stats" $L)
sh keys.sh 'X 150 300\n'
s=$SECONDS
for t in 3 6 9 12 15 18 21 24 27 30 33 36 39; do until [ $((SECONDS-s)) -ge $t ]; do sleep 0.5; done; py -3.13 shot.py BCUS98114 "${out}_$t" 640 >/dev/null 2>&1; done
grep -a "VR frame stats" $L | tail -n +$((n0+1)) | sed 's/.*stats: //' | cut -c1-60 > "$out.txt"
grep -a "inner scale\|Cinematic\|camera draws again\|frames without camera" $L | tail -n 20 | sed 's/^.*} //' > "$out.events.txt"
powershell -c "Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force; \$t=0; while ((Get-Process rpcs3 -ErrorAction SilentlyContinue | Where-Object { \$_.Threads.Count -gt 1 }) -and \$t -lt 150) { Start-Sleep -Milliseconds 200; \$t++ }"
sleep 1
py -3.13 cfgtemp.py BCUS98114 restore >/dev/null
[ $padhad = 0 ] && rm -r "${P:?}"
true
