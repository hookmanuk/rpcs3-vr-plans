#!/usr/bin/env bash
# ringtrig.sh LABEL "TRIG=VALUE ..." [SIZE=1024]: one U2 session (RUNTIME=steamvr for Matt's headset; EYE, ROUTE, START as
# ringrun.sh) with the flash ring on; for each condition the dev trigger set (%TEMP%/dcvr; "base" sets nothing), 5 s
# later the ring (the last ~4 s, both eyes) saved to /h/uc_tests/rt_LABEL_N_COND.raw. Same session and spot: a live A/B.
T=$(cd "$(dirname "$0")" && pwd)
LABEL=$1; CONDS=$2; SIZE=${3:-1024}
D="$TEMP/dcvr"; mkdir -p "$D"
tasklist | grep -qi bb-probe.exe && { echo "bb-probe is running: stopping"; exit 1; }
N=$(echo $CONDS | wc -w)
(SESSION_ENV="BB_VR_FLASH_RING=1 BB_VR_FLASH_RING_SIZE=$SIZE $EXTRA" ROUTE="${ROUTE:-wait 45; press cross; wait 4; press cross; wait 55}" \
  HOLD=$((N * 9 + 30)) timeout $((START_S=${START:-115}, START_S + N * 9 + 60)) bash $T/sess.sh > /h/uc_tests/ringtrig_sess.log 2>&1 &)
sleep ${START:-115}
k=0
for c in $CONDS; do
    if [ "$c" != base ]; then printf '%s' "${c#*=}" > "$D/${c%%=*}.tmp"; mv "$D/${c%%=*}.tmp" "$D/${c%%=*}"; fi
    sleep 5
    rm -f "$D/flashring.raw"; : > "$D/FLASHRING.tmp"; mv "$D/FLASHRING.tmp" "$D/FLASHRING"
    for i in $(seq 1 40); do [ -s "$D/flashring.raw" ] && break; sleep 0.25; done
    sleep 2; mv "$D/flashring.raw" "/h/uc_tests/rt_${LABEL}_${k}_${c//=/-}.raw" && echo "   saved $k $c"
    k=$((k + 1))
done
sleep 40; tasklist | grep -qi bb-probe.exe && echo "   (still running)"
