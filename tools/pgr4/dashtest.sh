#!/bin/sh
# dashtest.sh "NAME=VALUE ..." ...: simulator: for each set of settings (or "-" for none), in-car, the same drive from the race start: bounce.py's figures.
T=/f/rpsc3/source/plans/tools/pgr4; P=$T/pg.sh
st() { $P press "$1" >/dev/null; $P wait "$2" >/dev/null; }
for cfg in "$@"; do
    echo "=== $cfg"
    tasklist | grep -qi pgr4.exe && { echo "pgr4 is running: stopping"; exit 1; }
    if [ "$cfg" = - ]; then NO_RACE=1 sh $T/vrrace.sh 3692x3692 SIMXR_HZ=90 >/dev/null 2>&1; else NO_RACE=1 sh $T/vrrace.sh 3692x3692 SIMXR_HZ=90 $cfg >/dev/null 2>&1; fi
    $P wait 3s >/dev/null
    st START 6s; st A 6s; st A 4s; st A 4s; st A 4s; st A 6s; st A 15s; st A 12s
    :
    st LB 2s; st LB 2s
    $P trigger R 1 >/dev/null
    sleep 3
    py -3 $T/bounce.py a 300 2>&1 | grep BOUNCE | cut -c1-170
    sleep 3
    py -3 $T/bounce.py b 300 2>&1 | grep BOUNCE | cut -c1-170
    sleep 3
    py -3 $T/bounce.py c 300 2>&1 | grep BOUNCE | cut -c1-170
    $P trigger R 0 >/dev/null
    $P stop >/dev/null 2>&1
    sleep 3
done
