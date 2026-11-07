#!/bin/sh
# gridmode.sh LABEL BOOTS [NAME=VALUE...]: real headset, in-car on the race grid: per boot, 3 windows of 8 s, every frame's length logged (REGPU_VR_TRACE): is the 1% low's mode (55 or 82) per boot or per moment? Saves out/gridmode_LABEL_N.log.
T=/f/rpsc3/source/plans/tools/pgr4; P=$T/pg.sh; L=/h/PGR4-ReGPU/thirdparty/ReGPU/out/live.log
LABEL=$1; N=$2; shift 2
for b in $(seq 1 $N); do
    tasklist | grep -qi pgr4.exe && { echo "pgr4 is running: stopping"; exit 1; }
    sh $T/steamrace.sh 5120x5120 REGPU_PERF=1 REGPU_VR_TRACE=1 "$@" 2>&1 | tail -1 | cut -c1-60
    $P press LB >/dev/null; sleep 2; $P press LB >/dev/null; sleep 4
    for w in 1 2 3; do py -3 -I $T/vrperf.py 8 "$LABEL boot $b win $w grid" | sed -E 's/.*grid: //; s/, p50 [0-9.]+ ms//; s/, [0-9]+ frames.*//' | cut -c1-90; done
    grep -a 'vr: [0-9.]* FPS' $L | tail -1 | cut -c12-105
    $P stop >/dev/null 2>&1; sleep 3
    cp $L /h/PGR4-ReGPU/out/gridmode_${LABEL}_$b.log
done
