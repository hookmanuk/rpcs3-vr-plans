#!/usr/bin/env bash
# texsweep.sh LABEL VS ADDR "TRIGGER=VALUE[,TRIGGER=VALUE] ..." : one U2 session on the simulator (Matt's cliff save copy,
# eye ${EYE:-3584}; ROUTE / START as eyeburst.sh), in play: for each step the dev triggers set (comma-separated pairs),
# then TEXDUMP VS (both layers of the images the draw samples) and the image at ADDR kept as
# /h/uc_tests/tex_LABEL_STEP_{0,1}.raw (STEP = the step's text, = and , as _). Finds which knob moves a pass's input.
T=$(cd "$(dirname "$0")" && pwd)
LABEL=$1; VS=$2; ADDR=$3; STEPS=$4
D="$TEMP/dcvr"; mkdir -p "$D"
tasklist | grep -qi bb-probe.exe && { echo "bb-probe is running: stopping"; exit 1; }
# PATCH_SPV=file PATCH_PGM=fs_0x..._0: that SPIR-V in place of the shader (BB_PATCH_SHADERS, a fresh GPU cache).
if [ -n "$PATCH_SPV" ]; then
    G=/h/uc_tests/gpu_$LABEL; rm -rf "$G"; mkdir -p "$G/shader/patch"; cp "$PATCH_SPV" "$G/shader/patch/$PATCH_PGM.spv"
    EXTRA="BB_PATCH_SHADERS=1 BB_GPU_USER_DIR=$(cygpath -w $G) $EXTRA"
fi
(SESSION_ENV="$EXTRA" ROUTE="${ROUTE:-wait 45; press cross; wait 4; press cross; wait 55}" \
  HOLD=$(( $(echo $STEPS | wc -w) * 14 + 20 )) timeout 270 bash $T/sess.sh > /h/uc_tests/texsweep_sess.log 2>&1 &)
sleep ${START:-120}
trig() { printf '%s' "$2" > "$D/$1.tmp"; mv "$D/$1.tmp" "$D/$1"; }
for step in $STEPS; do
    for pair in ${step//,/ }; do trig "${pair%%=*}" "${pair#*=}"; done
    sleep 2
    rm -f "$D"/tex_*.raw; trig TEXDUMP "$VS"
    for i in $(seq 1 100); do [ -s "$D/tex_${ADDR}_1.raw" ] && break; sleep 0.1; done
    sleep 1
    name=$(echo "$step" | tr '=,' '__')
    mv "$D/tex_${ADDR}_0.raw" /h/uc_tests/tex_${LABEL}_${name}_0.raw; mv "$D/tex_${ADDR}_1.raw" /h/uc_tests/tex_${LABEL}_${name}_1.raw
    rm -f "$D"/tex_*.raw
done
rm -f "$D/IPD" "$D/SHSCALE" "$D/LIGHTEYE"
ls /h/uc_tests/tex_${LABEL}_*_1.raw | wc -l | sed 's/^/   dumps: /'
sleep 25; tasklist | grep -qi bb-probe.exe && echo "   (still running)"
