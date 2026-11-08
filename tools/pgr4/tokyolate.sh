#!/bin/sh
# tokyolate.sh LABEL [NAME=VALUE...]: real headset, Tokyo night heavy rain, in-car, 30 s driving with REGPU_VR_TRACE and REGPU_GPU_LONG: what the late frames are. Saves out/tokyolate_LABEL.log.
T=/f/rpsc3/source/plans/tools/pgr4; P=$T/pg.sh; L=/h/PGR4-ReGPU/thirdparty/ReGPU/out/live.log
LABEL=$1; shift
tasklist | grep -qi pgr4.exe && { echo "pgr4 is running: stopping"; exit 1; }
NO_RACE=1 sh $T/steamrace.sh 5120x5120 REGPU_PERF=1 REGPU_VR_TRACE=1 REGPU_GPU_PASSES=1 REGPU_GPU_LONG=16 "$@" >/dev/null 2>&1
sh $T/rainroute.sh
$P press LB >/dev/null; sleep 2; $P press LB >/dev/null; sleep 4
[ -n "$POKE" ] && $P poke $POKE >/dev/null # e.g. POKE="82AB538C 00": Car.Render.ShowMirror off
$P trigger R 1 >/dev/null; sleep 3
/h/tools/vrstats.exe 30 2>&1 | grep -E 'cumulative|frames seen' | cut -c1-120 &
py -3 -I $T/vrperf.py 30 "$LABEL Tokyo in-car driving" | sed -E 's/, p50 [0-9.]+ ms//; s/, [0-9]+ frames.*//' | cut -c1-110
wait
$P shot H:/PGR4-ReGPU/out/tokyolate_$LABEL.png >/dev/null
$P trigger R 0 >/dev/null
$P stop >/dev/null 2>&1; sleep 2
cp $L /h/PGR4-ReGPU/out/tokyolate_$LABEL.log
