#!/usr/bin/env bash
# fightfps.sh [SECONDS] [TAG]: U3 bar fight, running session: square / triangle combos (the throw every 8th) for SECONDS
# (default 60) with no captures, then the "VR: game" reports written meanwhile (/h/uc_tests/fightfps_TAG.txt).
F=/h/uncharted_pc/out/try/u3/pad.txt; L=/h/uncharted_pc/out/try/u3/run.log
put() { printf '%s' "$1" > $F.tmp; mv $F.tmp $F; }
n0=$(grep -c "^VR: game" $L); end=$(( $(date +%s) + ${1:-60} )); k=0
while [ $(date +%s) -lt $end ]; do
    k=$((k + 1)); [ $((k % 8)) = 0 ] && { put "ly=0 circle"; sleep 0.3; put ""; sleep 1.5; }
    for i in 1 2; do put square; sleep 0.12; put ""; sleep 0.25; put triangle; sleep 0.12; put ""; sleep 0.25; done
done
grep "^VR: game" $L | tail -n +$((n0 + 2)) | tee /h/uc_tests/fightfps_${2:-run}.txt
