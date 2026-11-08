#!/usr/bin/env bash
# ringrun.sh LABEL [SIZE=768] [WAIT_S=10]: one session (GAME=u2 default; RUNTIME=steamvr for Matt's headset; ROUTE /
# START as sess.sh / lenseyes.sh) with the flash ring on (both eyes of the last ~3.3 s, SIZE px each), saved WAIT_S into
# play (dev trigger FLASHRING) to /h/uc_tests/ring_LABEL.raw, then flashring.py on it (sheets in ring_LABEL_frames/).
# SWEEP=1 sweeps the simulator's head during the recording (simsweep.py).
T=$(cd "$(dirname "$0")" && pwd)
LABEL=$1; SIZE=${2:-768}; WAIT=${3:-10}
D="$TEMP/dcvr"; mkdir -p "$D"
tasklist | grep -qi bb-probe.exe && { echo "bb-probe is running: stopping"; exit 1; }
(SESSION_ENV="BB_VR_FLASH_RING=1 BB_VR_FLASH_RING_SIZE=$SIZE $EXTRA" ROUTE="${ROUTE:-wait 45; press cross; wait 4; press cross; wait 55}" \
  HOLD=$((WAIT + 25)) timeout 240 bash $T/sess.sh > /h/uc_tests/ringrun_sess.log 2>&1 &)
sleep ${START:-115}
if [ "$SWEEP" = 1 ]; then py -3 $T/simsweep.py $((WAIT + 2)) 25 2.0 >/dev/null & fi
sleep $WAIT
rm -f "$D/flashring.raw"; printf '' > "$D/FLASHRING.tmp"; mv "$D/FLASHRING.tmp" "$D/FLASHRING"
for i in $(seq 1 60); do [ -s "$D/flashring.raw" ] && break; sleep 0.5; done
sleep 3; mv "$D/flashring.raw" /h/uc_tests/ring_$LABEL.raw && ls -la /h/uc_tests/ring_$LABEL.raw | awk '{print "   ring", $5, "bytes"}'
wait
py -3 /h/uncharted_pc/tools/vr/flashring.py /h/uc_tests/ring_$LABEL.raw /h/uc_tests/ring_${LABEL}_frames 2>&1 | head -20
sleep 15; tasklist | grep -qi bb-probe.exe && echo "   (still running)"
