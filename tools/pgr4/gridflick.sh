#!/bin/sh
# gridflick.sh TAG COLD(0/1) [NAME=VALUE...]: simulator: the race grid, third-person then in-car: frames grabbed from the game's window, flickwin.py's outliers (out/TAG_g*, TAG_c*). COLD=1: the test folder's VR cache moved aside first (out/testuser/vr.warm keeps the warm one), so shaders and pipelines build during the run, as on a first run.
T=/f/rpsc3/source/plans/tools/pgr4; P=$T/pg.sh; V=/h/PGR4-ReGPU/out/testuser/vr
TAG=$1; COLD=$2; shift 2
st() { $P press "$1" >/dev/null; $P wait "$2" >/dev/null; }
tasklist | grep -qi pgr4.exe && { echo "pgr4 is running: stopping"; exit 1; }
if [ "$COLD" = 1 ]; then
    rm -rf "$V/pipelines.bin" "$V/pipelines.manifest" "$V/shadercache"
fi
NO_RACE=1 sh $T/vrrace.sh 3692x3692 SIMXR_HZ=90 "$@" >/dev/null 2>&1
$P wait 3s >/dev/null
st START 6s; st A 6s; st A 4s; st A 4s; st A 4s; st A 6s; st A 15s; st A 12s
echo "--- $TAG grid"
py -3 $T/flickwin.py ${TAG}_g 250 2>&1 | grep -E 'steady'
st LB 2s; st LB 2s
echo "--- $TAG in-car"
py -3 $T/flickwin.py ${TAG}_c 250 2>&1 | grep -E 'steady'
$P stop >/dev/null 2>&1
sleep 3
