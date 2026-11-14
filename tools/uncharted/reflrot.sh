#!/usr/bin/env bash
# reflrot.sh LABEL: a Borneo session (bsess.sh; EXTRA= environment), a 6 s walk into the river, then left-eye dumps with
# the simulator's head at 0, yaw 25, pitch -20, roll 15, yaw 20 + pitch -20 + roll 10, and 0 again
# (/h/uc_tests/rr_LABEL_<pose>.raw), each scored with rotwarp.py against the first (sheets rr_LABEL_<pose>.png).
T=$(cd "$(dirname "$0")" && pwd); L=$1; D="$TEMP/dcvr"; R=/h/uncharted_pc/out/try/u2/run.log; U=/h/uc_tests
nap() { python -c "import time; time.sleep($1)"; }
bash $T/bsess.sh 200 || exit 1
nap 60; n=0; until grep -a -q "3D again" $R 2>/dev/null || [ $n -gt 40 ]; do nap 3; n=$((n+1)); done
nap 28; bash $T/pad.sh "ly=0" 6; nap 2
eye() { rm -f "$D"/eye_*.raw; : > "$D/EYES.tmp"; mv "$D/EYES.tmp" "$D/EYES"
    for i in $(seq 1 100); do [ "$(stat -c %s "$D/eye_1.raw" 2>/dev/null)" = 33177608 ] && break; nap 0.05; done; nap 0.3; mv "$D/eye_0.raw" "$1"; }
pose() { (python $T/simhold.py $2 $3 $4 2.8 &); nap 1.5; eye $U/rr_${L}_$1.raw; nap 1.6; }
pose p0 0 0 0; pose yaw25 25 0 0; pose pitch-20 0 -20 0; pose roll15 0 0 15; pose mix 20 -20 10; pose p0b 0 0 0
taskkill //IM bb-probe.exe //F >/dev/null 2>&1
cd $U
for p in "yaw25 25 0 0" "pitch-20 0 -20 0" "roll15 0 0 15" "mix 20 -20 10" "p0b 0 0 0"; do set -- $p
    echo "$1: $(python $T/rotwarp.py rr_${L}_p0.raw rr_${L}_$1.raw $2 $3 $4 rr_${L}_$1.png)"; done
