#!/bin/sh
# vrrace.sh [eye WxH] [NAME=VALUE ...]: PGR4 in VR on the OpenXR Simulator, driven through the menus to the
# St Petersburg street race grid (Arcade, chapter 1, event 1). Uses the test user folder, never Matt's saves.
# Then: pg.sh <command>, simshot (simpose.py YAW PITCH ROLL for the real head pose).
P=/f/rpsc3/source/plans/tools/pgr4/pg.sh
EYE=${1:-2880x2880}; [ $# -gt 0 ] && shift
$P stop >/dev/null 2>&1
py -3 -I /f/rpsc3/source/plans/tools/re/simpose.py 0 0 0 >/dev/null
$P start REGPU_VR=1 'XR_RUNTIME_JSON=F:\rpsc3\source\OpenXR-Simulator\bin\openxr_simulator.json' XRFG_DISABLE_OFXR_BRIDGE=1 \
   REGPU_VR_EYE=$EYE "$@" | cut -c1-120
# Wait for frames (the first boot of a build compiles shaders).
for i in $(seq 1 60); do
    f=$($P status 2>/dev/null | sed -E 's/.*"frame": ([0-9]+).*/\1/')
    [ "${f:-0}" -gt 200 ] 2>/dev/null && break
    sleep 5
done
[ -n "$NO_RACE" ] && exit 0
step() { $P press "$1" >/dev/null; $P wait "$2" >/dev/null; }
step START 5s; step A 5s
step A 4s   # main menu: single player
step A 4s   # arcade
step A 4s   # chapter 1
step A 4s   # event 1
step A 4s   # first car
step A 6s   # difficulty
step A 15s  # the event card
step A 12s  # the grid
$P status | cut -c1-120
