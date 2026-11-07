#!/bin/sh
# earlyab.sh TAG [NAME=VALUE...]: simulator, St Petersburg and Tokyo night rain, paused after a few seconds of driving: shots with early
# depth off for every draw, on for every draw, and off again (control), live through REGPU_EARLY_RANGE (a test build). Prints how many
# pixels differ. Out: out/ea_TAG_<scene>_{none,early,none2}.png and _diff.png.
T=/f/rpsc3/source/plans/tools/pgr4; P=$T/pg.sh; O=H:/PGR4-ReGPU/out
TAG=$1; shift
for scene in stp tokyo; do
    tasklist | grep -qi pgr4.exe && { echo "pgr4 is running: stopping"; exit 1; }
    if [ $scene = stp ]; then
        sh $T/vrrace.sh 2880x2880 "$@" >/dev/null 2>&1
        $P wait 8s >/dev/null
    else
        NO_RACE=1 sh $T/vrrace.sh 2880x2880 "$@" >/dev/null 2>&1
        sh $T/rainroute.sh
        $P wait 6s >/dev/null
    fi
    $P trigger R 1 >/dev/null; sleep 6; $P trigger R 0 >/dev/null
    $P press START >/dev/null; sleep 4
    for s in none:0-0 early:0-99999 none2:0-0; do
        $P env REGPU_EARLY_RANGE ${s#*:} >/dev/null; sleep 2
        $P shot $O/ea_${TAG}_${scene}_${s%%:*}.png >/dev/null
    done
    $P stop >/dev/null 2>&1; sleep 2
done
py -3 $T/eadiff.py $TAG
