#!/bin/sh
# mirrortest.sh OUTPREFIX [EYE]: to the race grid in the in-car view on the simulator; shots of the mirror, stopped and driving. Leaves the game stopped.
OUT=$1; EYE=${2:-2880x2880}
NO_RACE=1 sh vrrace.sh "$EYE" >/dev/null 2>&1
sh pg.sh wait 3s >/dev/null
sh pg.sh press START >/dev/null; sleep 6
for d in 6 4 4 4 6 15 12; do sh pg.sh press A >/dev/null; sleep $d; done
sh pg.sh press LB >/dev/null; sleep 2; sh pg.sh press LB >/dev/null; sleep 2
sh pg.sh shot "${OUT}_grid.png" >/dev/null
sh pg.sh trigger R 1 >/dev/null; sleep 10
sh pg.sh shot "${OUT}_drive.png" >/dev/null
sh pg.sh trigger R 0 >/dev/null
sh pg.sh stop >/dev/null 2>&1; sleep 2
