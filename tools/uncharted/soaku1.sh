#!/usr/bin/env bash
# soaku1.sh TAG [MINUTES] ["EXTRA ENV"]: U1 soak in VR (simulator, eye 3584) with run.py's U1 settings: Matt's jungle save
# (backup /h/uc_tests/u1_save restored into u1user), Continue (five crosses 6 s apart from 50 s), then walk, jump, turn
# for MINUTES (default 3). Output: /h/uc_tests/soak1_TAG.txt (verdict, frame rates), soak1_TAG.log, soak1_TAG_s1.png.
TAG=$1; MIN=${2:-3}; EXTRA=$3; T=$(cd "$(dirname "$0")" && pwd); U=/h/uc_tests; D=/h/uncharted_pc/out/try/u1
tasklist | grep -qi bb-probe.exe && { echo "bb-probe already running: stop"; exit 1; }
for d in SAVEDATA010 SAVEDATA010.sce_sys SAVEDATA01P SAVEDATA01P.sce_sys; do
    [ -d "$U/u1_save/$d" ] || { echo "no backup $d"; exit 1; }
    rm -rf "$U/u1user/savedata/1/CUSA02343/$d"; cp -r "$U/u1_save/$d" "$U/u1user/savedata/1/CUSA02343/$d"
done
touch "$U/soak1.mark"
R="wait 50"; for i in 1 2 3 4 5; do R="$R; press cross; wait 6"; done
R="$R; wait 15; shot s0"
for i in $(seq 1 $((MIN * 3))); do
    R="$R; hold ly=0; wait 4; hold ly=0 cross; wait 0.2; hold ly=0; wait 2; release; press rx=255 0.8; wait 1"
    R="$R; hold ly=0; wait 4; release; press rx=0 0.8; wait 1; press ry=0 0.5; wait 1; press ry=255 0.5; wait 5"
done
R="$R; shot s1; wait 600"
RUNPY="BB_SCALAR_COPY64_SYNC=2 BB_SCALAR_COPY64_DEFER=1 BB_TOGGLE2=12 BB_WALK_MIN=55 BB_TINY_READBACK=0 BB_READBACK_SMALL_BUFFERS=0"
(cd "$T" && GAME=u1 UCUSER=u1user SESSION_ENV="BB_GPU_USER_DIR=H:\\uc_tests\\u1user BB_FRAME_STATS=1 $RUNPY $EXTRA" \
    ROUTE="$R" HOLD=1 timeout $((200 + MIN * 60 + 120)) bash sess.sh > "$U/soak1_${TAG}_sess.log" 2>&1 &)
for i in $(seq 1 $((80 + MIN * 22))); do
    [ "$D/s1.png" -nt "$U/soak1.mark" ] && break
    tasklist | grep -qi bb-probe.exe || { [ $i -gt 10 ] && break; }
    sleep 3
done
alive=no; tasklist | grep -qi bb-probe.exe && alive=yes
cp "$D/run.log" "$U/soak1_${TAG}.log"
taskkill //F //IM bb-probe.exe >/dev/null 2>&1; sleep 2; : > "$D/pad.txt"
powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='python.exe'\" | Where-Object { \$_.CommandLine -like '*tools/drive.py u1*' } | ForEach-Object { Stop-Process -Id \$_.ProcessId -Force }" >/dev/null 2>&1
reached=no; [ "$D/s1.png" -nt "$U/soak1.mark" ] && reached=yes && cp "$D/s1.png" "$U/soak1_${TAG}_s1.png" && cp "$D/s0.png" "$U/soak1_${TAG}_s0.png"
bad=$(grep -c -i "^Fault\|assert\|device.lost\|VK_ERROR_DEVICE\|GPU crash" "$U/soak1_${TAG}.log")
fps=$(grep "^VR: game" "$U/soak1_${TAG}.log" | tail -n +8 | awk '{g += $3; n++; if (min == "" || $3 < min) min = $3} END {if (n) printf "mean %.1f, lowest 5 s window %.1f", g/n, min}')
echo "$TAG: reached end $reached, alive at end $alive, $bad fault/assert lines; VR game FPS $fps" | tee "$U/soak1_${TAG}.txt"
