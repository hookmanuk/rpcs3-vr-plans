#!/bin/sh
# envab.sh LABEL EYE "A=1 B=2" "C=3" ...: a fresh VR race per environment set, grid and driving frame rate (perf.log). HZ 240.
T=/f/rpsc3/source/plans/tools/pgr4; P=$T/pg.sh; L=/h/PGR4-ReGPU/thirdparty/ReGPU/out/live.log
LABEL=$1; EYE=$2; shift 2
for cfg in "$@"; do
    sh $T/vrrace.sh $EYE SIMXR_HZ=240 PGR4_VR_FOV=1.4 $cfg >/dev/null 2>&1
    sleep 10
    python $T/vrperf.py 8 "$LABEL $EYE [$cfg] grid" | cut -c1-130
    $P trigger R 1 >/dev/null; sleep 5
    python $T/vrperf.py 8 "$LABEL $EYE [$cfg] driving" | cut -c1-130
    $P trigger R 0 >/dev/null; $P stop >/dev/null 2>&1
done
