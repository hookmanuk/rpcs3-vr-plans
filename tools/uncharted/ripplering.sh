#!/usr/bin/env bash
# ripplering.sh LABEL [RATE_ENV...]: Borneo (bsess.sh), a 6 s walk into the river, a pause, then a 2 s walk and a stop;
# 1.3 s after the stop the flash ring (consecutive frames with their times, 1024 px an eye) is saved to
# /h/uc_tests/rr_LABEL.raw: the last walk's ripples at Drake's feet and how they spread after he stops.
# RATE_ENV: e.g. "BB_VBLANK_HZ=60 BB_VR_CAP=0 BB_VR_IMMEDIATE_FLIPS=0" for a true 60 FPS game in VR (default: 90).
# Then ripplestrip.py makes the strips to compare.
T=$(cd "$(dirname "$0")" && pwd); L=$1; shift; D="$TEMP/dcvr"; R=/h/uncharted_pc/out/try/u2/run.log
EXTRA="BB_VR_FLASH_RING=1 BB_VR_FLASH_RING_SIZE=1024 $*" bash $T/bsess.sh 200 || exit 1
nap() { python -c "import time; time.sleep($1)"; }
nap 60
n=0; until grep -a -q "3D again" $R 2>/dev/null || [ $n -gt 40 ]; do nap 3; n=$((n+1)); done
nap ${SETTLE:-28}
bash $T/pad.sh "ly=0" 6
nap 3
if [ -n "$WALKING" ]; then
    # WALKING=1: the ring is taken during a 6.5 s walk along the river (WALK_TOKEN, default lx=0: to the left; forward
    # is blocked by the log on the far bank).
    (bash $T/pad.sh "${WALK_TOKEN:-lx=0}" 6.5 &); nap 3
else
    bash $T/pad.sh "ly=0" 2
    nap 1.3
fi
rm -f "$D/flashring.raw"; : > "$D/FLASHRING.tmp"; mv "$D/FLASHRING.tmp" "$D/FLASHRING"
for i in $(seq 1 60); do [ -s "$D/flashring.raw" ] && break; nap 0.25; done
nap 3; mv "$D/flashring.raw" "/h/uc_tests/rr_$L.raw" && ls -la "/h/uc_tests/rr_$L.raw" | awk '{print "   ring", $5, "bytes"}'
grep -a "Frame rate" $R | tail -2
nap 4
taskkill //IM bb-probe.exe //F >/dev/null 2>&1
printf '' > /h/uncharted_pc/out/try/u2/pad.txt
