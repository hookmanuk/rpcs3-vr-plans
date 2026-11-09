#!/usr/bin/env bash
# coldwarm.sh DIR LABEL GAME UCUSER "ROUTE" HOLD: one simulator session using the private GPU cache DIR, its log kept as /h/uc_tests/cw_LABEL.log
T=/f/rpsc3/source/plans/tools/uncharted
DIR=$1; LABEL=$2; G=$3; U=$4; R=$5; H=${6:-5}
tasklist | grep -qi bb-probe.exe && { echo running; exit 1; }
GAME=$G UCUSER=$U EYE=2160 SESSION_ENV="BB_GPU_USER_DIR=$(cygpath -w $DIR) $EXTRA" ROUTE="$R" HOLD=$H timeout 280 bash $T/sess.sh > /h/uc_tests/cw_${LABEL}_sess.log 2>&1
cp /h/uncharted_pc/out/try/$G/run.log /h/uc_tests/cw_$LABEL.log
K=$(find $DIR -name '*.key' | wc -l); S=$(find $DIR -name '*.spv' | wc -l)
echo "$LABEL: keys $K shaders $S"; grep -a -E "Pipeline cache: preloaded" /h/uc_tests/cw_$LABEL.log | cut -c1-120
