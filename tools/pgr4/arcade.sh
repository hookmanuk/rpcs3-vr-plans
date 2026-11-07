#!/bin/sh
# arcade.sh CHAPTER_RIGHTS EVENT_RIGHTS TAG: on a game at the title screen: Arcade, that chapter and event, to the grid; drives a while, shots
# to out/TAG0..2.png (left eye in VR). Back with the game running.
P=/f/rpsc3/source/plans/tools/pgr4/pg.sh; O=H:/PGR4-ReGPU/out
st() { $P press "$1" >/dev/null; $P wait "$2" >/dev/null; }
CH=${1:-0}; EV=${2:-0}; TAG=${3:-arc}
$P wait 3s >/dev/null
st START 6s; st A 7s; st A 5s; st A 4s
i=0; while [ $i -lt $CH ]; do st RIGHT 2s; i=$((i+1)); done
st A 4s
i=0; while [ $i -lt $EV ]; do st RIGHT 2s; i=$((i+1)); done
$P shot $O/${TAG}0.png >/dev/null
st A 4s; st A 4s; st A 6s; st A 15s
$P shot $O/${TAG}1.png >/dev/null
st A 12s
$P trigger R 1 >/dev/null
sleep 6
$P shot $O/${TAG}2.png >/dev/null
sleep 5
$P shot $O/${TAG}3.png >/dev/null
$P trigger R 0 >/dev/null
