#!/usr/bin/env bash
# reflpos.sh LABEL: a Borneo session (EXTRA= environment), the river, then left-eye dumps with the simulator's head moved
# (no turn): 0; 0.5 m right; 0.5 m up; 0.5 m back; 0.5 m left and 0.4 down; 0 again (/h/uc_tests/rp_LABEL_<n>.raw).
# A real headset's head is never at the origin: a reflection made for another eye point than the picture's slides off.
T=$(cd "$(dirname "$0")" && pwd); L=$1; D="$TEMP/dcvr"; R=/h/uncharted_pc/out/try/u2/run.log; U=/h/uc_tests
nap() { python -c "import time; time.sleep($1)"; }
bash $T/bsess.sh 200 || exit 1
nap 60; n=0; until grep -a -q "3D again" $R 2>/dev/null || [ $n -gt 40 ]; do nap 3; n=$((n+1)); done
nap 28; bash $T/pad.sh "ly=0" 6; nap 2
eye() { rm -f "$D"/eye_*.raw; : > "$D/EYES.tmp"; mv "$D/EYES.tmp" "$D/EYES"
    for i in $(seq 1 100); do [ "$(stat -c %s "$D/eye_1.raw" 2>/dev/null)" = 33177608 ] && break; nap 0.05; done; nap 0.3; mv "$D/eye_0.raw" "$1"; }
pose() { (python $T/simhold.py 0 0 0 2.8 $2 $3 $4 &); nap 1.5; eye $U/rp_${L}_$1.raw; nap 1.6; }
pose 0 0 0 0; pose right 0.5 0 0; pose up 0 0.5 0; pose back 0 0 0.5; pose leftdown -0.5 -0.4 0; pose 0b 0 0 0
taskkill //IM bb-probe.exe //F >/dev/null 2>&1
