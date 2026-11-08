#!/usr/bin/env bash
# steamfps.sh LABEL [SECONDS=20]: one session (GAME=u2 default; ROUTE= / START= for others) on SteamVR (Matt's headset; his save, eye ${EYE:-3584}, extra env in
# SESSION_ENV), in play: SteamVR's own count (vrstats: presents and reprojected a second, frames shown more than once)
# and the game's "VR:" line (headset FPS, 1% low, over a period, late). Appends to /h/uc_tests/steamfps.txt.
T=$(cd "$(dirname "$0")" && pwd)
LABEL=$1; S=${2:-20}
L=/h/uncharted_pc/out/try/${GAME:-u2}/run.log; O=/h/uc_tests/steamfps.txt
tasklist | grep -qi bb-probe.exe && { echo "bb-probe is running: stopping"; exit 1; }
(RUNTIME=steamvr ROUTE="${ROUTE:-wait 45; press cross; wait 4; press cross; wait 55}" HOLD=$((S + 8)) timeout 250 bash $T/sess.sh > /h/uc_tests/steamfps_sess.log 2>&1 &)
sleep ${START:-115}
a=$(wc -l < $L)
timeout $((S + 15)) /h/tools/vrstats.exe $S > /h/uc_tests/vrstats_$LABEL.txt 2>&1
b=$(wc -l < $L)
{
    echo "== $LABEL (eye ${EYE:-3584}) $(date +%H:%M)"
    grep -E "cumulative|frames seen" /h/uc_tests/vrstats_$LABEL.txt | sed -E 's/, loading.*//; s/^/   /'
    sed -n "$((a + 1)),${b}p" $L | grep -a "VR: game" | tail -2 | sed -E 's/ \(new frames\)//; s/; [0-9]+ repeated.*//; s/^/   /'
} | tee -a $O
sleep 14; tasklist | grep -qi bb-probe.exe && echo "   (still running)"
