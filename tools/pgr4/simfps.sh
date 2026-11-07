#!/bin/sh
# simfps.sh LABEL "EYE [NAME=VALUE...]" ...: uncapped on the simulator, in-car, St Petersburg: grid and driving FPS; passes when REGPU_GPU_PASSES=1 is given. DLSS off.
T=/f/rpsc3/source/plans/tools/pgr4; P=$T/pg.sh; L=/h/PGR4-ReGPU/thirdparty/ReGPU/out/live.log
LABEL=$1; shift
for cfg in "$@"; do
    set -- $cfg
    eye=$1; shift
    echo "=== $cfg"
    tasklist | grep -qi pgr4.exe && { echo "pgr4 is running: stopping"; exit 1; }
    SIMXR_HZ=${SIMXR_HZ:-240} sh $T/vrrace.sh $eye REGPU_PERF=1 BB_QUARANTINE=0 SIMXR_HZ=${SIMXR_HZ:-240} "$@" 2>&1 | tail -1 | cut -c1-70
    $P press LB >/dev/null; sleep 2; $P press LB >/dev/null; sleep 4
    py -3 -I $T/vrperf.py 8 "$LABEL sim $cfg grid" | cut -c1-140
    grep -a 'waiting on host' $L | tail -1 | cut -c12-100
    $P trigger R 1 >/dev/null; sleep 5
    py -3 -I $T/vrperf.py 10 "$LABEL sim $cfg driving" | cut -c1-140
    grep -a 'waiting on host' $L | tail -1 | cut -c12-100
    grep -a 'pipe:' $L | tail -1 | cut -c12-170
    grep -a 'gpu passes' $L | tail -15 | cut -c12-90
    $P trigger R 0 >/dev/null
    $P stop >/dev/null 2>&1
    sleep 2
done
