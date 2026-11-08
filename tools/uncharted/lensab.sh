#!/usr/bin/env bash
# lensab.sh LABEL [WINDOW_S=15] [MODES="0 1 2"] [ROUNDS=2]: one U2 session on SteamVR (Matt's headset; his save, eye
# ${EYE:-3584}), in play: each lens-skip mode (dev trigger LENS: 0 off, 1 computes, 2 computes and fragments) for
# WINDOW_S seconds in turn, ROUNDS times, with SteamVR's count per window (vrstats: presents and reprojected a second,
# frames shown more than once). The same boot for every mode. Appends to /h/uc_tests/lensab.txt.
T=$(cd "$(dirname "$0")" && pwd)
LABEL=$1; W=${2:-15}; MODES=${3:-"0 1 2"}; R=${4:-2}
O=/h/uc_tests/lensab.txt; D="$TEMP/dcvr"; mkdir -p "$D"
tasklist | grep -qi bb-probe.exe && { echo "bb-probe is running: stopping"; exit 1; }
N=$(( $(echo $MODES | wc -w) * R ))
(RUNTIME=steamvr ROUTE="wait 45; press cross; wait 4; press cross; wait 55" HOLD=$((N * (W + 3) + 5)) \
  timeout $((N * (W + 3) + 140)) bash $T/sess.sh > /h/uc_tests/lensab_sess.log 2>&1 &)
sleep 115
echo "== $LABEL (eye ${EYE:-3584}) $(date +%H:%M)" | tee -a $O
for r in $(seq 1 $R); do
    for m in $MODES; do
        printf '%s' "$m" > "$D/LENS.tmp"; mv "$D/LENS.tmp" "$D/LENS"; sleep 2
        timeout $((W + 10)) /h/tools/vrstats.exe $W > /h/uc_tests/lensab_w.txt 2>&1
        c=$(grep -E "cumulative" /h/uc_tests/lensab_w.txt | sed -E 's/cumulative per second: presents ([0-9.]+), dropped [0-9.]+, reprojected ([0-9.]+).*/presents \1, reprojected \2/')
        f=$(grep -E "frames seen" /h/uc_tests/lensab_w.txt | sed -E 's/.*shown more than once ([0-9]+).*/shown twice \1/')
        echo "   mode $m: $c, $f" | tee -a $O
    done
done
rm -f "$D/LENS"
sleep 12; tasklist | grep -qi bb-probe.exe && echo "   (still running)"
