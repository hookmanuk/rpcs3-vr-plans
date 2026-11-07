#!/bin/sh
# gridpass.sh LABEL BOOTS [NAME=VALUE...]: real SteamVR, in-car on the race grid: per boot, the 1% low, a shot, the GPU's pass list. Saves out/gridpass_LABEL_N.{png,log}.
T=/f/rpsc3/source/plans/tools/pgr4; P=$T/pg.sh; L=/h/PGR4-ReGPU/thirdparty/ReGPU/out/live.log
LABEL=$1; N=$2; shift 2
for b in $(seq 1 $N); do
    tasklist | grep -qi pgr4.exe && { echo "pgr4 is running: stopping"; exit 1; }
    sh $T/steamrace.sh 5120x5120 REGPU_PERF=1 REGPU_GPU_PASSES=1 "$@" 2>&1 | tail -1 | cut -c1-60
    $P press LB >/dev/null; sleep 2; $P press LB >/dev/null; sleep 4
    py -3 -I $T/vrperf.py 10 "$LABEL boot $b grid" | sed -E 's/.*grid: //; s/, p50 [0-9.]+ ms//; s/, [0-9]+ frames.*//' | cut -c1-90
    $P shot H:/PGR4-ReGPU/out/gridpass_${LABEL}_$b.png >/dev/null
    $P stop >/dev/null 2>&1; sleep 3
    cp $L /h/PGR4-ReGPU/out/gridpass_${LABEL}_$b.log
done
