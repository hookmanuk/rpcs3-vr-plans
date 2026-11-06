#!/bin/sh
# flatrace.sh WxH [NAME=VALUE ...]: the flat game, uncapped, driven to the same race grid as vrrace.sh (test user folder).
P=/f/rpsc3/source/plans/tools/pgr4/pg.sh
RES=${1:-1920x1080}; [ $# -gt 0 ] && shift
$P stop >/dev/null 2>&1
$P start PGR4_RESOLUTION=$RES PGR4_VSYNC=0 PGR4_MAX_FPS=360 "$@" | cut -c1-120
for i in $(seq 1 60); do
    f=$($P status 2>/dev/null | sed -E 's/.*"frame": ([0-9]+).*/\1/')
    [ "${f:-0}" -gt 200 ] 2>/dev/null && break
    sleep 5
done
step() { $P press "$1" >/dev/null; $P wait "$2" >/dev/null; }
step START 5s; step A 5s; step A 4s; step A 4s; step A 4s; step A 4s; step A 4s; step A 6s; step A 15s; step A 12s
$P status | cut -c1-120
