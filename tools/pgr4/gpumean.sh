#!/bin/sh
# gpumean.sh LABEL "EYE [NAME=VALUE...]" ...: simulator at 90 Hz: 20 s on the race grid: FPS, the mean GPU span of a frame and the number over 13 ms (REGPU_GPU_LONG).
T=/f/rpsc3/source/plans/tools/pgr4; P=$T/pg.sh; L=/h/PGR4-ReGPU/thirdparty/ReGPU/out/live.log
LABEL=$1; shift
for cfg in "$@"; do
    set -- $cfg
    eye=$1; shift
    sh $T/vrrace.sh $eye SIMXR_HZ=90 REGPU_GPU_PASSES=1 REGPU_GPU_LONG=13 "$@" >/dev/null 2>&1
    sleep 6
    a=$(grep -ac 'gpu long' $L)
    py -3 -I $T/vrperf.py 20 "$LABEL simulator 90 Hz $cfg grid" | cut -c1-140
    b=$(grep -ac 'gpu long' $L)
    echo "   GPU over 13 ms in those 20 s: $((b-a)); $(grep -a 'gpu long' $L | tail -1 | sed -E 's/.*\(mean ([0-9.]+)\).*/mean span \1 ms/')"
    grep -a 'gpu passes: ' $L | tail -15 | head -5 | sed -E 's/^\[ *[0-9.]+\] gpu passes: *//' | cut -c1-70 | sed 's/^/     /'
    $P stop >/dev/null 2>&1
done
