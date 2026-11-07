#!/bin/sh
# pipetest.sh LABEL "HZ EYE [NAME=VALUE...]" ...: SteamVR null headset: on the race grid, then driving: SteamVR's own frame account (vrstats.exe), the frame's timeline ("pipe:") and FPS.
T=/f/rpsc3/source/plans/tools/pgr4; P=$T/pg.sh; O=/h/PGR4-ReGPU/out/exit_out.txt
LABEL=$1; shift
one() { # SCENE
    VR_CONFIG_PATH='H:\PGR4-ReGPU\out\nullvr_config' /h/tools/vrstats.exe 10 2>&1 | grep -E 'cumulative|app frame' | cut -c1-175
    grep -a 'pipe:' $O | tail -1 | cut -c12-165
    py -3 -I $T/vrperf.py 6 "$LABEL SteamVR null $CFG $1" | cut -c1-140
}
for cfg in "$@"; do
    CFG=$cfg
    set -- $cfg
    echo "=== $cfg"
    sh $T/nullvr.sh "$@" REGPU_PERF=1 >/dev/null 2>&1
    sleep 6
    one grid
    $P trigger R 1 >/dev/null; sleep 5
    one driving
    $P trigger R 0 >/dev/null
done
sh $T/nullvr.sh stop
