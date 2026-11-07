#!/bin/sh
# hmdscenes.sh LABEL EYE...: on Matt's real SteamVR and headset (already running, left running): Tokyo night heavy rain and Las Vegas Cone Sprint, grid and driving: SteamVR's own frame account, FPS, new frames.
T=/f/rpsc3/source/plans/tools/pgr4; P=$T/pg.sh; L=/h/PGR4-ReGPU/thirdparty/ReGPU/out/live.log
LABEL=$1; shift
st() { $P press "$1" >/dev/null; $P wait "$2" >/dev/null; }
one() {
    py -3 -I $T/vrperf.py 15 "$LABEL HMD $1" > /h/PGR4-ReGPU/out/hmdperf.txt &
    /h/tools/vrstats.exe 15 2>&1 | grep -E 'cumulative|frames seen' | cut -c1-120
    wait
    cut -c1-135 /h/PGR4-ReGPU/out/hmdperf.txt
    grep -a 'vr: [0-9.]* FPS' $L | tail -1 | cut -c12-120
}
both() {
    sleep 6
    one "$1 grid"
    $P trigger R 1 >/dev/null; sleep 5
    one "$1 driving"
    $P trigger R 0 >/dev/null
    $P stop >/dev/null 2>&1
}
for eye in "$@"; do
    NO_RACE=1 sh $T/steamrace.sh $eye REGPU_PERF=1 >/dev/null 2>&1
    sh $T/rainroute.sh
    both "$eye Tokyo night rain"
    NO_RACE=1 sh $T/steamrace.sh $eye REGPU_PERF=1 >/dev/null 2>&1
    $P wait 3s >/dev/null
    st START 6s; st A 7s; st A 5s; st A 4s
    st RIGHT 2s; st A 4s; st RIGHT 2s; st RIGHT 2s
    st A 4s; st A 4s; st A 6s; st A 15s; st A 12s
    both "$eye Vegas cone sprint"
done
