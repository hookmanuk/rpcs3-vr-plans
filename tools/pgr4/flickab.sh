#!/bin/sh
# flickab.sh "EYE [NAME=VALUE...]" ...: simulator, main menu: frames grabbed from the window, head still, then moving. flickwin.py's stray-row and flicker counts for each configuration, out/ab<n>_*.png.
T=/f/rpsc3/source/plans/tools/pgr4; P=$T/pg.sh
st() { $P press "$1" >/dev/null; $P wait "$2" >/dev/null; }
n=0
for cfg in "$@"; do
    n=$((n+1))
    set -- $cfg
    eye=$1; shift
    echo "=== $cfg"
    tasklist | grep -qi pgr4.exe && { echo "pgr4 is running: stopping"; exit 1; }
    NO_RACE=1 sh $T/vrrace.sh $eye SIMXR_HZ=90 "$@" >/dev/null 2>&1
    $P wait 3s >/dev/null
    st START 6s; st A 6s
    py -3 $T/flickwin.py ab${n}s 100 2>&1 | grep -E 'stray-row'
    py -3 -I $T/headmove.py 6 &
    py -3 $T/flickwin.py ab${n}m 120 2>&1 | grep -E 'stray-row|flicker'
    wait
    $P stop >/dev/null 2>&1
    sleep 3
done
