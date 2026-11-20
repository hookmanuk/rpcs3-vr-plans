#!/usr/bin/env bash
# benchu3.sh TAG [SECONDS] ["EXTRA ENV"]: U3 bar fight in VR (simulator, eye 3584) with run.py's U3 settings. Restores
# the checkpoint copy (/h/uc_tests/bar_save: Continue lands at the throw tutorial), Continues, throws (ly=0 circle),
# then fights (square / triangle combos, a throw every 8th, as fightfps.sh) for SECONDS (default 60), taking a window
# shot every 15 s (the choke hold shows in them). Output: /h/uc_tests/bench3_TAG.txt (the VR reports written during the
# fight and a summary line), bench3_TAG_N.png.
TAG=$1; SECS=${2:-60}; EXTRA=$3; T=$(cd "$(dirname "$0")" && pwd); U=/h/uc_tests; D=/h/uncharted_pc/out/try/u3
tasklist | grep -qi bb-probe.exe && { echo "bb-probe already running: stop"; exit 1; }
for d in SAVEDATA030 SAVEDATA030.sce_sys SAVEDATA03P SAVEDATA03P.sce_sys; do
    [ -d "$U/bar_save/$d" ] || { echo "no backup $d"; exit 1; }
    rm -rf "$U/mc_copy/savedata/1/CUSA02343/$d"; cp -r "$U/bar_save/$d" "$U/mc_copy/savedata/1/CUSA02343/$d"
done
touch "$U/bench3.mark"
R="wait 50"; for i in 1 2 3 4 5; do R="$R; press cross; wait 6"; done
R="$R; wait 20; shot t0; wait 900"
# run.py's U3 settings (the launcher's Play).
RUNPY="BB_TINY_READBACK=1 BB_READBACK_SMALL_GATE=1 BB_READBACK_SMALL_BUFFERS=1 BB_COPY64_EOP_READBACK=1 BB_TOGGLE2=12"
RUNPY="$RUNPY BB_SCALAR_COPY64_SYNC=0 BB_SCALAR_COPY64_DEFER=0"
(cd "$T" && GAME=u3 UCUSER=mc_copy SESSION_ENV="BB_GPU_USER_DIR=H:\\uc_tests\\mc_copy BB_FRAME_STATS=1 $RUNPY $EXTRA" \
    ROUTE="$R" HOLD=1 timeout 900 bash sess.sh > "$U/bench3_${TAG}_sess.log" 2>&1 &)
for i in $(seq 1 100); do [ "$D/t0.png" -nt "$U/bench3.mark" ] && break; tasklist | grep -qi bb-probe.exe || { [ $i -gt 10 ] && break; }; sleep 3; done
[ "$D/t0.png" -nt "$U/bench3.mark" ] || { echo "never reached t0"; taskkill //F //IM bb-probe.exe >/dev/null 2>&1; exit 1; }
cp "$D/t0.png" "$U/bench3_${TAG}_t0.png"
F=$D/pad.txt; L=$D/run.log
put() { printf '%s' "$1" > $F.tmp; mv $F.tmp $F; }
put "ly=0 circle"; sleep 0.4; put ""; sleep 3
n0=$(grep -c "^VR: game" $L); start=$(date +%s); end=$((start + SECS)); k=0; shot=0
while [ $(date +%s) -lt $end ]; do
    k=$((k + 1)); [ $((k % 8)) = 0 ] && { put "ly=0 circle"; sleep 0.3; put ""; sleep 1.5; }
    for i in 1 2; do put square; sleep 0.12; put ""; sleep 0.25; put triangle; sleep 0.12; put ""; sleep 0.25; done
    if [ $(( $(date +%s) - start )) -ge $(( (shot + 1) * 15 )) ]; then
        shot=$((shot + 1)); python "$T/winshot.py" "$(cygpath -w "$U/bench3_${TAG}_$shot.png")" >/dev/null 2>&1
    fi
done
put ""
grep "^VR: game\|^Frame stats" $L | tail -n +$((n0 + 1)) > "$U/bench3_${TAG}.txt"
alive=no; tasklist | grep -qi bb-probe.exe && alive=yes
bad=$(grep -c -i "^Fault\|assert\|device.lost\|VK_ERROR_DEVICE" $L)
cp $L "$U/bench3_${TAG}.log"
taskkill //F //IM bb-probe.exe >/dev/null 2>&1; sleep 2; : > "$F"
powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='python.exe'\" | Where-Object { \$_.CommandLine -like '*tools/drive.py u3*' } | ForEach-Object { Stop-Process -Id \$_.ProcessId -Force }" >/dev/null 2>&1
grep "^VR: game" "$U/bench3_${TAG}.txt" | tail -n +2 | awk -v t="$TAG" -v a="$alive" -v b="$bad" '{g += $3; l += $(NF-0); n++; if (min == "" || $3 < min) min = $3}
    END {printf "%s: VR game mean %.1f FPS, lowest 5 s window %.1f (%d reports); alive %s, %d fault/assert lines\n", t, g/n, min, n, a, b}' | tee -a "$U/bench3_${TAG}.txt"
