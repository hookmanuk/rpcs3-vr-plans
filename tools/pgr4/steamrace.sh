#!/bin/sh
# steamrace.sh [EYE or -] [NAME=VALUE...]: as vrrace.sh but on the active OpenXR runtime (SteamVR): the game starts it if needed.
P=/f/rpsc3/source/plans/tools/pgr4/pg.sh
EYE=${1:--}; [ $# -gt 0 ] && shift
$P stop >/dev/null 2>&1
if [ "$EYE" = "-" ]; then $P start PGR4_VR=1 "$@" | cut -c1-120; else $P start PGR4_VR=1 REGPU_VR_EYE=$EYE "$@" | cut -c1-120; fi
for i in $(seq 1 60); do
    f=$($P status 2>/dev/null | sed -E 's/.*"frame": ([0-9]+).*/\1/')
    [ "${f:-0}" -gt 200 ] 2>/dev/null && break
    sleep 5
done
[ -n "$NO_RACE" ] && exit 0
step() { $P press "$1" >/dev/null; $P wait "$2" >/dev/null; }
step START 5s; step A 5s; step A 4s; step A 4s; step A 4s; step A 4s; step A 4s; step A 6s; step A 15s; step A 12s
$P status | cut -c1-120
