#!/bin/sh
# flashab.sh hmd|sim "NAME=VALUE..." ...: in-car view, driving from the race start: two runs of 300 frames grabbed from the game's window, rec100.py's count of frames with a one-frame flash (the stray triangles Matt reported) for each configuration.
T=/f/rpsc3/source/plans/tools/pgr4; P=$T/pg.sh
WHERE=$1; shift
st() { $P press "$1" >/dev/null; $P wait "$2" >/dev/null; }
n=0
for cfg in "$@"; do
    n=$((n+1))
    set -- $cfg
    echo "=== [$cfg]"
    tasklist | grep -qi pgr4.exe && { echo "pgr4 is running: stopping"; exit 1; }
    if [ "$WHERE" = flat ]; then NO_RACE=1 sh $T/flatrace.sh 1920x1080 "$@" >/dev/null 2>&1; elif [ "$WHERE" = hmd ]; then NO_RACE=1 sh $T/steamrace.sh - "$@" >/dev/null 2>&1; else NO_RACE=1 sh $T/vrrace.sh 3692x3692 SIMXR_HZ=90 "$@" >/dev/null 2>&1; fi
    $P wait 3s >/dev/null
    st START 6s; st A 6s; st A 4s; st A 4s; st A 4s; st A 6s; st A 15s; st A 12s
    st LB 2s; st LB 2s
    $P trigger R 1 >/dev/null
    sleep 3
    REC_QUIET=1 py -3 $T/rec100.py fa${n}a 300 2>&1 | grep FLASH | cut -c1-130
    sleep 2
    REC_QUIET=1 py -3 $T/rec100.py fa${n}b 300 2>&1 | grep FLASH | cut -c1-130
    $P trigger R 0 >/dev/null
    $P stop >/dev/null 2>&1
    sleep 3
done
tasklist | grep -i pgr4.exe
true
