#!/bin/sh
# gridpin.sh LABEL BOOTS [NAME=VALUE...]: real SteamVR, in-car: per boot, the 1% low on the grid and driving, and where the busy threads were placed.
T=/f/rpsc3/source/plans/tools/pgr4; P=$T/pg.sh; L=/h/PGR4-ReGPU/thirdparty/ReGPU/out/live.log
LABEL=$1; N=$2; shift 2
for b in $(seq 1 $N); do
    tasklist | grep -qi pgr4.exe && { echo "pgr4 is running: stopping"; exit 1; }
    sh $T/steamrace.sh 5120x5120 REGPU_PERF=1 "$@" >/dev/null 2>&1
    $P press LB >/dev/null; sleep 2; $P press LB >/dev/null; sleep 4
    py -3 -I $T/vrperf.py 10 "$LABEL boot $b grid" | sed -E 's/.*grid: //; s/, p50 [0-9.]+ ms//; s/, [0-9]+ frames.*//' | cut -c1-70
    $P trigger R 1 >/dev/null; sleep 5
    /h/tools/vrstats.exe 12 2>&1 | grep -E 'cumulative|frames seen' | sed -E 's/cumulative per second: presents [0-9.]+, dropped [0-9.]+, /   /; s/, loading.*//; s/frames seen ([0-9]+) in .*: shown more than once/   of : doubled/; s/, reprojection flags.*//' | cut -c1-80 &
    py -3 -I $T/vrperf.py 12 "$LABEL boot $b driving" | sed -E 's/.*driving: /   driving /; s/, p50 [0-9.]+ ms//; s/, [0-9]+ frames.*//' | cut -c1-80
    wait
    $P trigger R 0 >/dev/null
    grep -a 'thread .*: ideal processor' $L | sed -E 's/.*thread //; s/: ideal processor / /; s/ \(pinned\)//' | tr '\n' ',' | cut -c1-170; echo
    $P stop >/dev/null 2>&1; sleep 3
done
