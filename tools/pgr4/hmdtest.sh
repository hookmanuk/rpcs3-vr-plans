#!/bin/sh
# hmdtest.sh LABEL "EYE|- [NAME=VALUE...]" ...: on Matt's real SteamVR and headset, which must already be running: grid and driving, SteamVR's own frame account (vrstats.exe), the frame's timeline ("pipe:"), FPS.
# Leaves SteamVR running: it is his. Only the game is closed. Only with his say-so (he may be wearing it).
T=/f/rpsc3/source/plans/tools/pgr4; P=$T/pg.sh; L=/h/PGR4-ReGPU/thirdparty/ReGPU/out/live.log
LABEL=$1; shift
one() {
    # (At the same time: a client leaving SteamVR may itself disturb the pacing.)
    py -3 -I $T/vrperf.py ${WINDOW:-20} "$LABEL HMD $CFG $1" > /h/PGR4-ReGPU/out/hmdperf.txt &
    /h/tools/vrstats.exe ${WINDOW:-20} 2>&1 | grep -E 'cumulative|frames seen|app frame' | cut -c1-185
    wait
    cut -c1-140 /h/PGR4-ReGPU/out/hmdperf.txt
    grep -a 'pipe:' $L | tail -1 | cut -c12-165
    grep -a 'vr: [0-9.]* FPS\|changed the frame period' $L | tail -2 | cut -c12-175
    sleep 3
}
for cfg in "$@"; do
    CFG=$cfg
    set -- $cfg
    eye=$1; shift
    echo "=== $cfg"
    sh $T/steamrace.sh $eye REGPU_PERF=1 "$@" 2>&1 | tail -1 | cut -c1-80
    grep -a -E 'vr: runtime|vr: eyes|display period|vr: eye 0|vr: eye 1|vertex data in video' $L | cut -c12-120
    [ -n "$NOFENCE" ] && case "$cfg" in *NOFENCE*) $P poke 82A80B5C 00 >/dev/null;; esac # Debug.WaitForFence off for this run
    [ -n "$INCAR" ] && { $P press LB >/dev/null; sleep 2; $P press LB >/dev/null; sleep 2; } # the in-car view
    sleep 6
    one grid
    $P trigger R 1 >/dev/null; sleep 5
    one driving
    $P trigger R 0 >/dev/null
    $P stop >/dev/null 2>&1
done
