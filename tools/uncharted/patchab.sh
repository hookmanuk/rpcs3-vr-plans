#!/usr/bin/env bash
# patchab.sh LABEL [SPV|none] [PGM=cs_0x0000000043b8ee5e_0]: one U2 session on the simulator (Matt's save, eye ${EYE:-3584},
# SIMXR_HZ=${HZ:-144}, BB_VR_CAP=0: uncapped) with SPV loaded in place of the shader PGM (BB_PATCH_SHADERS, a fresh GPU
# cache so it compiles), in play: the average of the "Frame stats" FPS over ${WINDOW:-24} s and a frame (shot LABEL).
# Appends to /h/uc_tests/patchab.txt. Whole run about 3 minutes.
T=$(cd "$(dirname "$0")" && pwd)
LABEL=$1; SPV=${2:-none}; PGM=${3:-cs_0x0000000043b8ee5e_0}; W=${WINDOW:-24}
G=/h/uc_tests/gpu_$LABEL; rm -rf "/h/uc_tests/gpu_$LABEL"; mkdir -p "$G/shader/patch"
[ "$SPV" != none ] && cp "$SPV" "$G/shader/patch/$PGM.spv"
L=/h/uncharted_pc/out/try/u2/run.log
tasklist | grep -qi bb-probe.exe && { echo "bb-probe is running: stopping"; exit 1; }
(SESSION_ENV="SIMXR_HZ=${HZ:-144} BB_VR_CAP=0 BB_PATCH_SHADERS=1 BB_GPU_USER_DIR=$(cygpath -w $G) $EXTRA" \
  ROUTE="wait 45; press cross; wait 4; press cross; wait 60; shot $LABEL" HOLD=$((W + 6)) timeout 230 bash $T/sess.sh > /h/uc_tests/patchab_sess.log 2>&1 &)
sleep 120
a=$(wc -l < $L); sleep $W; b=$(wc -l < $L)
sed -n "$((a + 1)),${b}p" $L | grep -a -o -E "^Frame stats: [0-9.]+ FPS, worst frame [0-9.]+" | sed -E 's/Frame stats: ([0-9.]+) FPS, worst frame ([0-9.]+)/\1 \2/' |
    awk -v n="$LABEL" '{ s += $1; c++; if (min == "" || $1 < min) min = $1; if ($2 > w) w = $2 } END { if (c) printf "%-12s %6.1f FPS (lowest second %5.1f, worst frame %.1f ms, %d samples)\n", n, s / c, min, w, c; else print n " no samples" }' | tee -a /h/uc_tests/patchab.txt
cat $L "$G"/log/* 2>/dev/null | grep -a -c "Loaded patch for" | sed 's/^/   patches loaded: /'
sleep 12; tasklist | grep -qi bb-probe.exe && echo "   (still running)"; cat $L "$G"/log/* 2>/dev/null | grep -a -m1 -i "patch for|shader patch" | cut -c1-150
rm -rf "$G"
