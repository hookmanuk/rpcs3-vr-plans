#!/usr/bin/env bash
# soaku2.sh TAG [MINUTES] ["EXTRA ENV"]: U2 soak in VR (simulator) after Borneo's bomb cutscene, with run.py's U2 settings.
# Restores Matt's checkpoint copy (/h/uc_tests/bomb_save), runs benchu2.sh's route to the cutscene, then walks, turns
# and jumps for MINUTES (default 5). Pass: the game is still running at the end, and its log has no fault, assert or
# lost device. Output: /h/uc_tests/soak_TAG.txt (verdict and frame rates) and soak_TAG.log (the game's log).
TAG=$1; MIN=${2:-5}; EXTRA=$3; T=$(cd "$(dirname "$0")" && pwd); U=/h/uc_tests; D=/h/uncharted_pc/out/try/u2
tasklist | grep -qi bb-probe.exe && { echo "bb-probe already running: stop"; exit 1; }
for d in SAVEDATA020 SAVEDATA020.sce_sys SAVEDATA02P SAVEDATA02P.sce_sys; do
    [ -d "$U/bomb_save/$d" ] || { echo "no backup $d"; exit 1; }
    rm -rf "$U/mc_copy/savedata/1/CUSA02343/$d"; cp -r "$U/bomb_save/$d" "$U/mc_copy/savedata/1/CUSA02343/$d"
done
touch "$U/soak.mark"
R="wait 70; press cross; wait 5; press cross; wait 55; press rx=200 0.3; wait 1; hold ly=0"
for i in 1 2 3 4; do R="$R; wait 2; hold ly=0 cross; wait 0.15; hold ly=0; wait 1.85"; done
R="$R; release; wait 45; shot s0"
# One cycle ~20 s: walk, jump, turn, walk back, look around.
n=$((MIN * 3))
for i in $(seq 1 $n); do
    R="$R; hold ly=0; wait 4; hold ly=0 cross; wait 0.2; hold ly=0; wait 2; release; press rx=255 0.8; wait 1"
    R="$R; hold ly=0; wait 4; release; press rx=0 0.8; wait 1; press ry=0 0.5; wait 1; press ry=255 0.5; wait 5"
done
R="$R; shot s1; wait 600"
RUNPY="BB_GPU_MERGE=0 BB_TINY_READBACK=1 BB_READBACK_SMALL_BUFFERS=1 BB_SCALAR_COPY64_SYNC=2 BB_SCALAR_COPY64_DEFER=1"
(cd "$T" && GAME=u2 UCUSER=mc_copy SESSION_ENV="BB_GPU_USER_DIR=H:\\uc_tests\\mc_copy BB_FRAME_STATS=1 $RUNPY $EXTRA" \
    ROUTE="$R" HOLD=1 timeout $((300 + MIN * 60 + 120)) bash sess.sh > "$U/soak_${TAG}_sess.log" 2>&1 &)
for i in $(seq 1 $((100 + MIN * 22))); do
    [ "$D/s1.png" -nt "$U/soak.mark" ] && break
    tasklist | grep -qi bb-probe.exe || { [ $i -gt 10 ] && break; }
    sleep 3
done
alive=no; tasklist | grep -qi bb-probe.exe && alive=yes
cp "$D/run.log" "$U/soak_${TAG}.log"
taskkill //F //IM bb-probe.exe >/dev/null 2>&1; sleep 2; : > "$D/pad.txt"
powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='python.exe'\" | Where-Object { \$_.CommandLine -like '*tools/drive.py u2*' } | ForEach-Object { Stop-Process -Id \$_.ProcessId -Force }" >/dev/null 2>&1
reached=no; [ "$D/s1.png" -nt "$U/soak.mark" ] && reached=yes && cp "$D/s1.png" "$U/soak_${TAG}_s1.png"
bad=$(grep -c -i "^Fault\|assert\|device.lost\|VK_ERROR_DEVICE\|GPU crash" "$U/soak_${TAG}.log")
fps=$(grep "^VR: game" "$U/soak_${TAG}.log" | tail -n +8 | awk '{g += $3; n++; if (min == "" || $3 < min) min = $3} END {if (n) printf "mean %.1f, lowest 5 s window %.1f", g/n, min}')
echo "$TAG: reached end $reached, alive at end $alive, $bad fault/assert lines; VR game FPS $fps" | tee "$U/soak_${TAG}.txt"
