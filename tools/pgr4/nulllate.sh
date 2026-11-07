#!/bin/sh
# nulllate.sh LABEL "HZ EYE [NAME=VALUE...]" ...: SteamVR null headset: 20 s on the grid and 12 s driving: FPS (perf.log) and the share of late frames (latecheck.py).
T=/f/rpsc3/source/plans/tools/pgr4; P=$T/pg.sh; O=/h/PGR4-ReGPU/out
LABEL=$1; shift
for cfg in "$@"; do
    set -- $cfg
    hz=$1
    budget=$(python -c "print(round(1000/$hz+0.5,1))")
    sh $T/nullvr.sh "$@" REGPU_VR_TRACE=1 REGPU_PERF=1 >/dev/null 2>&1
    sleep 8
    py -3 -I $T/vrperf.py 20 "$LABEL SteamVR null $cfg grid" | cut -c1-150
    cp $O/exit_out.txt $O/late.txt
    py -3 -I $T/latecheck.py H:/PGR4-ReGPU/out/late.txt $budget | head -2 | cut -c1-170
    grep -a 'GPU time' $O/late.txt | tail -1 | cut -c12-90
    $P trigger R 1 >/dev/null; sleep 5
    py -3 -I $T/vrperf.py 12 "$LABEL SteamVR null $cfg driving" | cut -c1-150
    cp $O/exit_out.txt $O/late.txt
    py -3 -I $T/latecheck.py H:/PGR4-ReGPU/out/late.txt $budget | head -1 | cut -c1-120
    grep -a 'GPU time' $O/late.txt | tail -1 | cut -c12-90
    $P trigger R 0 >/dev/null
done
sh $T/nullvr.sh stop
