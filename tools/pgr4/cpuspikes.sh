#!/bin/sh
# cpuspikes.sh LABEL "HZ EYE [NAME=VALUE...]" ...: SteamVR null headset, small eyes so the GPU has room: frame rate and spikes on the grid, and the timeline ("pipe:").
T=/f/rpsc3/source/plans/tools/pgr4; O=/h/PGR4-ReGPU/out/exit_out.txt
LABEL=$1; shift
for cfg in "$@"; do
    set -- $cfg
    sh $T/nullvr.sh "$@" REGPU_PERF=1 >/dev/null 2>&1
    sleep 7
    py -3 -I $T/vrperf.py 12 "$LABEL SteamVR null $cfg grid" | cut -c1-150
    grep -a 'pipe:' $O | tail -1 | cut -c12-165
    grep -a 'vr: [0-9.]* FPS' $O | tail -1 | cut -c12-125
done
sh $T/nullvr.sh stop
