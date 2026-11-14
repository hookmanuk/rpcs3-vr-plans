#!/usr/bin/env bash
# borneoab.sh LABEL: one Borneo session (bsess.sh), a 6 s walk into the river, then on the same scene:
#  reflections: dev trigger DERIVED 0 / 1 / 0 / 1, each with eye dumps at head yaw 0, 25, 0 (rf_LABEL_<n>_d<D>_{a,y25,c}.raw
#               in /h/uc_tests: worldlock.py's names; left eye);
#  culling: dev trigger GAMEVIEW 0 / 2 / 0 / 2, head held 35 left, the camera turned right 3 s (rx=255), two dumps 0.8 s in
#           (cu_LABEL_<n>_g<G>_{1,2}.raw), then turned back.
T=$(cd "$(dirname "$0")" && pwd); L=$1; D="$TEMP/dcvr"; R=/h/uncharted_pc/out/try/u2/run.log; U=/h/uc_tests
nap() { python -c "import time; time.sleep($1)"; }
bash $T/bsess.sh 330 || exit 1
nap 60; n=0; until grep -a -q "3D again" $R 2>/dev/null || [ $n -gt 40 ]; do nap 3; n=$((n+1)); done
nap 28; bash $T/pad.sh "ly=0" 6; nap 2
trig() { printf '%s' "$2" > "$D/$1.tmp"; mv "$D/$1.tmp" "$D/$1"; nap 0.5; }
eye() { rm -f "$D"/eye_*.raw; : > "$D/EYES.tmp"; mv "$D/EYES.tmp" "$D/EYES"
    for i in $(seq 1 100); do [ "$(stat -c %s "$D/eye_1.raw" 2>/dev/null)" = 33177608 ] && break; nap 0.05; done; nap 0.3; mv "$D/eye_0.raw" "$1"; }
pose() { (python $T/simhold.py $2 0 0 2.6 &); nap 1.3; eye $1; nap 1.6; }
n=0; for d in 0 1 0 1; do n=$((n+1)); trig DERIVED $d; P=$U/rf_${L}_${n}_d$d; pose ${P}_a.raw 0; pose ${P}_y25.raw 25; pose ${P}_c.raw 0; done
n=0; for g in 0 2 0 2; do n=$((n+1)); trig GAMEVIEW $g; (python $T/simhold.py 35 0 0 7 &); nap 1.5
    (bash $T/pad.sh "rx=255" 3 &); nap 0.8; eye $U/cu_${L}_${n}_g${g}_1.raw; eye $U/cu_${L}_${n}_g${g}_2.raw; nap 1.5; bash $T/pad.sh "rx=0" 3; nap 2.5; done
grep -a "VR camera: derived\|VR camera: the game's own\|no mirror" $R | head -4; grep -a "Frame rate" $R | tail -2
taskkill //IM bb-probe.exe //F >/dev/null 2>&1
