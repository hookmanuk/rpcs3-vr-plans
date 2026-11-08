#!/bin/sh
# modecheck.sh LABEL [SECONDS=20] [NAME=VALUE...]: one SteamVR boot, in-car on the race grid: the game-side frame rate (1% low
# tells the boot's mode: ~55 slow, ~75+ fast), the last stage line, and the threads by CPU over the same window with their
# names (threadcpu.ps1). Saves out/modecheck_LABEL.log. Run a few boots to catch both modes and compare the hot threads.
T=/f/rpsc3/source/plans/tools/pgr4; P=$T/pg.sh; L=/h/PGR4-ReGPU/thirdparty/ReGPU/out/live.log
LABEL=$1; S=${2:-20}; [ $# -gt 0 ] && shift; [ $# -gt 0 ] && shift
tasklist | grep -qi pgr4.exe && { echo "pgr4 is running: stopping"; exit 1; }
sh $T/steamrace.sh 5120x5120 REGPU_PERF=1 REGPU_VR_TRACE=1 "$@" 2>&1 | tail -1 | cut -c1-60
$P press LB >/dev/null; sleep 2; $P press LB >/dev/null; sleep 4
powershell -NoProfile -ExecutionPolicy Bypass -File $T/threadcpu.ps1 $S 14 > /h/PGR4-ReGPU/out/modecheck_threads.txt 2>&1 &
TP=$!
py -3 -I $T/vrperf.py $S "$LABEL grid" | sed -E 's/.*grid: //; s/, p50 [0-9.]+ ms//; s/, [0-9]+ frames.*//' | cut -c1-90
wait $TP
grep -a 'vr stages' $L | tail -1 | sed -E 's/.*p50\/p99\/max ms: //' | cut -c1-190 | sed 's/^/   /'
grep -a -E "cpu t[0-9]+" $L | tail -1 | grep -o -E "cpu t[0-9]+ [0-9.]+%" | sed 's/^/   /'
cat /h/PGR4-ReGPU/out/modecheck_threads.txt
$P stop >/dev/null 2>&1; sleep 2
cp $L /h/PGR4-ReGPU/out/modecheck_$LABEL.log
