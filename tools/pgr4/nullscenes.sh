#!/bin/sh
# nullscenes.sh HZ EYE...: on SteamVR's null headset, each eye size: Tokyo night heavy rain (grid, driving) and Las Vegas Cone Sprint (grid, driving); no screenshots while measuring.
T=/f/rpsc3/source/plans/tools/pgr4; P=$T/pg.sh; O=/h/PGR4-ReGPU/out/exit_out.txt
HZ=$1; shift
measure() { # LABEL
    sleep 6
    py -3 -I $T/vrperf.py 8 "$1 grid"
    grep -E 'vr: [0-9.]+ FPS' $O | tail -1 | cut -c12-120
    $P trigger R 1 >/dev/null; sleep 6
    py -3 -I $T/vrperf.py 8 "$1 driving"
    grep -E 'vr: [0-9.]+ FPS' $O | tail -1 | cut -c12-120
    $P trigger R 0 >/dev/null
}
for eye in "$@"; do
    NO_RACE=1 sh $T/nullvr.sh $HZ $eye >/dev/null 2>&1
    sh $T/rainroute.sh
    measure "SteamVR null $HZ Hz $eye Tokyo night rain"
    NO_RACE=1 sh $T/nullvr.sh $HZ $eye >/dev/null 2>&1
    $P wait 3s >/dev/null
    st() { $P press "$1" >/dev/null; $P wait "$2" >/dev/null; }
    st START 6s; st A 7s; st A 5s; st A 4s
    st RIGHT 2s; st A 4s; st RIGHT 2s; st RIGHT 2s
    st A 4s; st A 4s; st A 6s; st A 15s; st A 12s
    measure "SteamVR null $HZ Hz $eye Vegas cone sprint"
done
sh $T/nullvr.sh stop
