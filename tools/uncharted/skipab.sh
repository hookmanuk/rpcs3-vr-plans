#!/usr/bin/env bash
# skipab.sh LABEL WINDOW_S "PGM ..." [ROUNDS=2]: one U2 session on the simulator (Matt's save, eye ${EYE:-3584},
# SIMXR_HZ=${HZ:-144}, BB_VR_CAP=0: uncapped), in play: no skip, then each shader skipped live (BB_SHADER_DEBUG_FILE)
# for WINDOW_S seconds, ROUNDS times, and the per-second "VR: game N FPS" lines of each window averaged. Skipping
# breaks the picture: this only says what each shader costs. Results in /h/uc_tests/skipab_LABEL.txt.
T=$(cd "$(dirname "$0")" && pwd)
LABEL=$1; W=${2:-10}; PGMS=$3; R=${4:-2}
F=/h/uc_tests/skip_live.txt; : > $F
L=/h/uncharted_pc/out/try/u2/run.log; OUT=/h/uc_tests/skipab_$LABEL.txt; : > $OUT
tasklist | grep -qi bb-probe.exe && { echo "bb-probe is running: stopping"; exit 1; }
TOTAL=$(( (1 + $(echo $PGMS | wc -w)) * W * R + 20 ))
(SESSION_ENV="SIMXR_HZ=${HZ:-144} BB_VR_CAP=0 BB_SHADER_DEBUG_FILE=H:\\uc_tests\\skip_live.txt $EXTRA" \
  ROUTE="wait 45; press cross; wait 4; press cross; wait 50" HOLD=$TOTAL timeout $((TOTAL + 130)) bash $T/sess.sh > /h/uc_tests/skipab_sess.log 2>&1 &)
sleep 112
window() { # NAME: lines of the log written during the next W seconds
    local a=$(wc -l < $L); sleep $W; local b=$(wc -l < $L)
    sed -n "$((a + 1)),${b}p" $L | grep -a -o -E "VR: game [0-9.]+ FPS" | grep -o -E "[0-9.]+" | tail -n +2 |
        awk -v n="$1" '{ s += $1; c++; if (min == "" || $1 < min) min = $1 } END { if (c) printf "%-10s %6.1f FPS (min %5.1f, %d s)\n", n, s / c, min, c }' | tee -a $OUT
}
for r in $(seq 1 $R); do
    : > $F; sleep 1; window none
    for p in $PGMS; do echo "skip $p" > $F; sleep 1; window $p; done
done
: > $F
