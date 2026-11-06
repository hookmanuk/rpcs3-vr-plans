#!/bin/sh
# sweep.sh LABEL "EYE [NAME=VALUE...]" ...: for each configuration, the VR race grid and driving: frame rate and GPU time
# (the perf log's "GPU time"), appended to perf.log. Stops the game afterwards.
P=/f/rpsc3/source/plans/tools/pgr4/pg.sh; T=/f/rpsc3/source/plans/tools/pgr4; L=/h/PGR4-ReGPU/thirdparty/ReGPU/out/live.log
LABEL=$1; shift
for cfg in "$@"; do
    set -- $cfg
    eye=$1; shift
    sh $T/vrrace.sh $eye SIMXR_HZ=240 REGPU_PERF=1 "$@" >/dev/null 2>&1
    sleep 12
    python $T/vrperf.py 8 "$LABEL $cfg grid"
    grep -E 'GPU time' $L | tail -1 | cut -c12-110 | tee -a $T/perf.log
    grep -E 'vr: [0-9.]+ FPS' $L | tail -1 | cut -c12-120
    $P trigger R 1 >/dev/null; sleep 5
    python $T/vrperf.py 8 "$LABEL $cfg driving"
    grep -E 'GPU time' $L | tail -1 | cut -c12-110 | tee -a $T/perf.log
    $P trigger R 0 >/dev/null
    $P stop >/dev/null 2>&1
done
