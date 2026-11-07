#!/bin/sh
# hmdscale.sh "EYE [NAME=VALUE...]" ...: real headset, already running: while driving: the frame's GPU time, FPS, PCIe reads, GPU power. How much of the GPU's time follows the resolution.
T=/f/rpsc3/source/plans/tools/pgr4; P=$T/pg.sh; L=/h/PGR4-ReGPU/thirdparty/ReGPU/out/live.log
for cfg in "$@"; do
    set -- $cfg
    eye=$1; shift
    echo "=== $cfg"
    tasklist | grep -qi pgr4.exe && { echo "pgr4 is running: stopping"; exit 1; }
    sh $T/${RACE:-steamrace.sh} $eye REGPU_PERF=1 "$@" 2>&1 | tail -1 | cut -c1-80
    sleep 6
    $P trigger R 1 >/dev/null
    sleep 8
    nvidia-smi dmon -s tup -c 5 -d 1 2>/dev/null | tail -6 | cut -c1-90
    py -3 -I $T/vrperf.py 8 "$cfg driving" | cut -c1-110
    grep -a 'pipe:' $L | tail -2 | cut -c12-170
    grep -a 'vertices drawn' $L | tail -1 | cut -c12-70
    $P trigger R 0 >/dev/null
    $P stop >/dev/null 2>&1
    sleep 3
done
tasklist | grep -i pgr4.exe
true
