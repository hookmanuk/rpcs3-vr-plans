#!/bin/sh
# gridfree.sh LABEL BOOTS [NAME=VALUE...]: SteamVR with the headset in standby (free running, no pacing): per boot, in-car on the race
# grid, a 24 s window: the 1% low (the boot's mode, about 57 or about 80), every frame's stages ("vr stages:"), the timer probe.
# Saves out/gridfree_LABEL_N.log. The mode shows free running too, so this needs no one in the headset.
T=/f/rpsc3/source/plans/tools/pgr4; P=$T/pg.sh; L=/h/PGR4-ReGPU/thirdparty/ReGPU/out/live.log
LABEL=$1; N=$2; shift 2
for b in $(seq 1 $N); do
    tasklist | grep -qi pgr4.exe && { echo "pgr4 is running: stopping"; exit 1; }
    sh $T/steamrace.sh 5120x5120 REGPU_PERF=1 REGPU_VR_TRACE=1 "$@" 2>&1 | tail -1 | cut -c1-60
    $P press LB >/dev/null; sleep 2; $P press LB >/dev/null; sleep 4
    py -3 -I $T/vrperf.py 24 "$LABEL boot $b grid" | sed -E 's/.*grid: //; s/, p50 [0-9.]+ ms//; s/, [0-9]+ frames.*//' | cut -c1-90
    grep -a 'vr stages' $L | tail -3 | cut -c12-260
    grep -a 'timer:' $L | tail -2 | cut -c12-80 | tr '\n' ' '; echo
    grep -a 'vr: [0-9.]* FPS' $L | tail -1 | cut -c12-80
    $P stop >/dev/null 2>&1; sleep 3
    cp $L /h/PGR4-ReGPU/out/gridfree_${LABEL}_$b.log
done
