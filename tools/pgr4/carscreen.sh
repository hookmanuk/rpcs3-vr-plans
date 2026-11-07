#!/bin/sh
# carscreen.sh OUT.txt: on a game just started, goes to the car select screen and captures one frame's trace into OUT.txt (game stays on that screen).
P=/f/rpsc3/source/plans/tools/pgr4/pg.sh
st() { $P press "$1" >/dev/null; $P wait "$2" >/dev/null; }
$P wait 3s >/dev/null
st START 6s; st A 6s; st A 4s; st A 4s; st A 4s; st A 6s
$P capture >/dev/null
sleep 4
cp /h/PGR4-ReGPU/thirdparty/ReGPU/out/live.log "$1"
$P shot "${1%.txt}.png" >/dev/null
