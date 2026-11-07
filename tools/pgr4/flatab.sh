#!/bin/sh
# flatab.sh LABEL "RES [NAME=VALUE...]" ...: the flat game, uncapped: race grid and driving, FPS and GPU time into perf.log.
T=/f/rpsc3/source/plans/tools/pgr4; P=$T/pg.sh; L=/h/PGR4-ReGPU/thirdparty/ReGPU/out/live.log
LABEL=$1; shift
for cfg in "$@"; do
    set -- $cfg
    res=$1; shift
    sh $T/flatrace.sh $res REGPU_PERF=1 "$@" >/dev/null 2>&1
    sleep 8
    py -3 -I $T/vrperf.py 8 "$LABEL FLAT $cfg grid"
    grep -a 'GPU time' $L | tail -1 | cut -c12-100
    $P trigger R 1 >/dev/null; sleep 6
    py -3 -I $T/vrperf.py 8 "$LABEL FLAT $cfg driving"
    grep -a 'GPU time' $L | tail -1 | cut -c12-100
    $P trigger R 0 >/dev/null
    $P stop >/dev/null 2>&1
done
