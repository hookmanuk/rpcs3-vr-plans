#!/usr/bin/env bash
# wadelog.sh LABEL [RATE_ENV...]: Borneo (bsess.sh), 6 s forward into the river, then a wade left along it; 1.3 s into
# the wade the dev trigger VBLOG (a development build with the vertex logger: BB_VB_LOG=99b45d3e, the wake's vertex
# shader) logs the ripple quads of the next 600 draws with their times -> /h/uc_tests/wade_LABEL.log (ringgrow.py).
T=$(cd "$(dirname "$0")" && pwd); L=$1; shift; D="$TEMP/dcvr"; C=/h/uncharted_pc/out/try/u2
EXTRA="BB_VB_LOG=99b45d3e $*" bash $T/bsess.sh 200 || exit 1
nap() { python -c "import time; time.sleep($1)"; }
nap 60
n=0; until grep -a -q "3D again" $C/run.log 2>/dev/null || [ $n -gt 40 ]; do nap 3; n=$((n+1)); done
nap 28; bash $T/pad.sh "ly=0" 6; nap 3
(bash $T/pad.sh "lx=0" 3.2 &); nap 1.3; : > "$D/VBLOG"; nap 4
grep -a "^VBLOG" $C/run.log > /h/uc_tests/wade_$L.log; grep -a "Frame rate" $C/run.log | tail -1
taskkill //IM bb-probe.exe //F >/dev/null 2>&1; printf '' > $C/pad.txt
wc -l /h/uc_tests/wade_$L.log
