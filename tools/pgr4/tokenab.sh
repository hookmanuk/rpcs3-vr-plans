#!/bin/sh
# tokenab.sh LABEL PAIRS [NAME=VALUE...]: one boot on SteamVR (headset awake or in standby, both paced), in-car on the race grid: the token
# switch (SWITCH=, default REGPU_VR_TOKEN_DELAY, live) off and on in turn, WINDOW s each (default 20): the game-side 1% low, every frame's stages, SteamVR's
# reprojected/s and its view of each late frame (VRSTATS_LATE). The same boot for both, so the boot's mode cancels out.
T=/f/rpsc3/source/plans/tools/pgr4; P=$T/pg.sh; L=/h/PGR4-ReGPU/thirdparty/ReGPU/out/live.log; W=${WINDOW:-20}; SW=${SWITCH:-REGPU_VR_TOKEN_DELAY}
LABEL=$1; N=$2; shift 2
tasklist | grep -qi pgr4.exe && { echo "pgr4 is running: stopping"; exit 1; }
sh $T/steamrace.sh 5120x5120 REGPU_PERF=1 REGPU_VR_TRACE=1 "$@" 2>&1 | tail -1 | cut -c1-60
$P press LB >/dev/null; sleep 2; $P press LB >/dev/null; sleep 4
one() {
    $P switch $SW $1 >/dev/null; sleep 2
    VRSTATS_LATE=1 VRSTATS_TYPICAL=1 /h/tools/vrstats.exe $W > /h/PGR4-ReGPU/out/tokenab_${LABEL}_$2_$1.txt 2>&1 &
    py -3 -I $T/vrperf.py $W "$LABEL delay $1 pair $2 grid" | sed -E 's/.*grid: //; s/, p50 [0-9.]+ ms//; s/, [0-9]+ frames.*//' | cut -c1-90
    wait
    grep -E 'cumulative|frames seen|typical' /h/PGR4-ReGPU/out/tokenab_${LABEL}_$2_$1.txt | sed -E 's/cumulative per second: presents [0-9.]+, dropped [0-9.]+, /   SteamVR /; s/, loading.*//; s/^frames seen/   frames seen/; s/^typical/   typical/' | cut -c1-200
    grep -a 'vr stages' $L | tail -1 | sed -E 's/.*\| late/   late/' | cut -c1-100
}
for p in $(seq 1 $N); do
    echo "== pair $p: delay off"; one 0 $p
    echo "== pair $p: delay on"; one 1 $p
done
$P stop >/dev/null 2>&1; sleep 2
cp $L /h/PGR4-ReGPU/out/tokenab_$LABEL.log
