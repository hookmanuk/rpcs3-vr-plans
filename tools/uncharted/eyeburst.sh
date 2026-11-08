#!/usr/bin/env bash
# eyeburst.sh LABEL [N=10]: one U2 session on the simulator (Matt's cliff save copy, eye ${EYE:-3584}, extra env in
# EXTRA, a fresh GPU cache so shader changes compile), in play: N full-size dumps of both eyes back to back (dev trigger
# EYES, about 2 s apart), kept as /h/uc_tests/burst_LABEL_K_{0,1}.raw. Whole run about 3.5 minutes.
T=$(cd "$(dirname "$0")" && pwd)
LABEL=$1; N=${2:-10}
D="$TEMP/dcvr"; mkdir -p "$D"
G=/h/uc_tests/gpu_$LABEL; rm -rf "/h/uc_tests/gpu_$LABEL"; mkdir -p "$G/shader/patch"
# PATCH_SPV=file PATCH_PGM=cs_0x..._0: that SPIR-V in place of the shader (BB_PATCH_SHADERS, a dev visualisation).
[ -n "$PATCH_SPV" ] && cp "$PATCH_SPV" "$G/shader/patch/$PATCH_PGM.spv" && EXTRA="BB_PATCH_SHADERS=1 $EXTRA"
tasklist | grep -qi bb-probe.exe && { echo "bb-probe is running: stopping"; exit 1; }
(SESSION_ENV="BB_GPU_USER_DIR=$(cygpath -w $G) $EXTRA" ROUTE="${ROUTE:-wait 45; press cross; wait 4; press cross; wait 55}" \
  HOLD=60 timeout 230 bash $T/sess.sh > /h/uc_tests/eyeburst_sess.log 2>&1 &)
sleep ${START:-120}
F=$(( ${EYE:-3584} * ${EYE:-3584} * 4 + 8 ))
for k in $(seq 0 $((N - 1))); do
    rm -f "$D"/eye_*.raw; : > "$D/EYES.tmp"; mv "$D/EYES.tmp" "$D/EYES"
    for i in $(seq 1 200); do [ "$(stat -c %s "$D/eye_1.raw" 2>/dev/null)" = $F ] && break; sleep 0.05; done
    mv "$D/eye_0.raw" /h/uc_tests/burst_${LABEL}_${k}_0.raw; mv "$D/eye_1.raw" /h/uc_tests/burst_${LABEL}_${k}_1.raw
done
ls /h/uc_tests/burst_${LABEL}_*_1.raw | wc -l | sed 's/^/   dumps: /'
sleep 50; tasklist | grep -qi bb-probe.exe && echo "   (still running)"
[ "$KEEP" = 1 ] || rm -rf "$G"
