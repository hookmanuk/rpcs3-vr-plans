#!/bin/sh
# simspikes.sh LABEL "flat|EYE [NAME=VALUE...]" ...: where the frame's CPU time goes, on the simulator (never SteamVR): the time a frame takes to record ("pipe:"), which xrEndFrame can't touch.
# Stops before each run if SteamVR or a game is running: Matt may be in VR.
T=/f/rpsc3/source/plans/tools/pgr4; P=$T/pg.sh; L=/h/PGR4-ReGPU/thirdparty/ReGPU/out/live.log
LABEL=$1; shift
busy() {
    powershell -NoProfile -Command "if ((Get-Process vrserver,vrcompositor,pgr4 -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0) { 'busy' }" | grep -q busy
}
for cfg in "$@"; do
    if busy; then echo "STOPPED: SteamVR or the game is running, not touching it"; exit 3; fi
    set -- $cfg
    what=$1; shift
    if [ "$what" = flat ]; then
        sh $T/flatrace.sh 1280x720 REGPU_PERF=1 "$@" >/dev/null 2>&1
    else
        sh $T/vrrace.sh $what SIMXR_HZ=90 REGPU_PERF=1 "$@" >/dev/null 2>&1
    fi
    sleep 7
    py -3 -I $T/vrperf.py 12 "$LABEL $cfg grid" | cut -c1-140
    grep -a 'pipe:' $L | tail -2 | cut -c12-165
    $P stop >/dev/null 2>&1
done
