#!/bin/sh
# nullsweep.sh LABEL "HZ EYE [NAME=VALUE...]" ...: for each configuration on SteamVR's null headset: grid and driving, FPS and the runtime's times, into perf.log.
T=/f/rpsc3/source/plans/tools/pgr4; P=$T/pg.sh; O=/h/PGR4-ReGPU/out/exit_out.txt
LABEL=$1; shift
for cfg in "$@"; do
    set -- $cfg
    sh $T/nullvr.sh "$@" >/dev/null 2>&1
    sleep 8
    py -3 -I $T/vrperf.py 10 "$LABEL SteamVR null $cfg grid"
    grep -E 'vr: [0-9.]+ FPS' $O | tail -1 | cut -c12-150
    $P trigger R 1 >/dev/null; sleep 6
    py -3 -I $T/vrperf.py 10 "$LABEL SteamVR null $cfg driving"
    grep -E 'vr: [0-9.]+ FPS' $O | tail -1 | cut -c12-150
    $P trigger R 0 >/dev/null
done
sh $T/nullvr.sh stop
