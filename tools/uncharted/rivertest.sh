#!/usr/bin/env bash
# rivertest.sh LABEL: a Borneo session (bsess.sh; EXTRA= environment), a 6 s walk forward into the river, then both
# eyes dumped (/h/uc_tests/rt_LABEL_<pose>_{0,1}.raw, eye 2880) with the simulator's head held at: p0 (0), yaw25, pitch-15,
# roll20; then the culling check: yaw35 standing (cull_still), and with the camera turning right (rx=255: cull_turn1..3).
T=$(cd "$(dirname "$0")" && pwd); L=$1; D="$TEMP/dcvr"; R=/h/uncharted_pc/out/try/u2/run.log
bash $T/bsess.sh 200 || exit 1
python -c "import time; time.sleep(60)"
n=0; until grep -a -q "3D again" $R 2>/dev/null || [ $n -gt 40 ]; do python -c "import time; time.sleep(3)"; n=$((n+1)); done
python -c "import time; time.sleep(${SETTLE:-28})"
bash $T/pad.sh "ly=0" 6
eyes() {
    rm -f "$D"/eye_*.raw; : > "$D/EYES.tmp"; mv "$D/EYES.tmp" "$D/EYES"
    for i in $(seq 1 100); do [ "$(stat -c %s "$D/eye_1.raw" 2>/dev/null)" = 33177608 ] && break; python -c "import time; time.sleep(0.05)"; done
    python -c "import time; time.sleep(0.3)"
    for e in 0 1; do mv "$D/eye_$e.raw" /h/uc_tests/rt_${L}_$1_$e.raw; done
}
pose() { (python $T/simhold.py $2 $3 $4 3.5 &); python -c "import time; time.sleep(1.5)"; eyes $1; python -c "import time; time.sleep(2.3)"; }
pose p0 0 0 0; pose yaw25 25 0 0; pose pitch-15 0 -15 0; pose roll20 0 0 20
(python $T/simhold.py 35 0 0 12 &); python -c "import time; time.sleep(2)"; eyes cull_still
(bash $T/pad.sh "rx=255" 6 &); python -c "import time; time.sleep(1.5)"; eyes cull_turn1; eyes cull_turn2; eyes cull_turn3
python -c "import time; time.sleep(6)"
grep -a "VR camera: derived\|no mirror" $R | head -3; grep -a "Frame rate" $R | tail -2
taskkill //IM bb-probe.exe //F >/dev/null 2>&1
