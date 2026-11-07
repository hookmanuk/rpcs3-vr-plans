#!/bin/sh
# menuflick.sh "NAME=VALUE..." ...: simulator, main menu, head moving: per configuration, flickwin.py's flicker count and out/mfN_* frames, and how many pixels of the menu's text area flicker in the worst frames.
T=/f/rpsc3/source/plans/tools/pgr4; P=$T/pg.sh
st() { $P press "$1" >/dev/null; $P wait "$2" >/dev/null; }
n=0
for cfg in "$@"; do
    n=$((n+1))
    set -- $cfg
    echo "=== [$cfg]"
    tasklist | grep -qi pgr4.exe && { echo "pgr4 is running: stopping"; exit 1; }
    NO_RACE=1 sh $T/vrrace.sh 3692x3692 SIMXR_HZ=90 "$@" >/dev/null 2>&1
    $P wait 3s >/dev/null
    st START 6s; st A 6s
    py -3 -I $T/headmove.py 10 1 &
    py -3 $T/flickwin.py mf$n 300 2>&1 | grep -E 'flicker'
    wait
    $P stop >/dev/null 2>&1
    sleep 3
done
