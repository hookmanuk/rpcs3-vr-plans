#!/usr/bin/env bash
# trigregion.sh LABEL TRIGGER "VALUE ..." [RESET]: on a running VR session, the dev trigger TRIGGER set to each value,
# both eyes dumped, saved as /h/uc_tests/trr_LABEL_VALUE_{0,1}.raw. RESET (default: the first value) is set at the end.
# A knob sweep on the same frames; compare with crops (h16png / eye crops).
LABEL=$1; TRIG=$2; VALUES=$3; RESET=${4:-${3%% *}}
D="$TEMP/dcvr"; mkdir -p "$D"; S=$(( ${EYE:-3584} * ${EYE:-3584} * 4 + 8 ))
set_trig() { printf '%s' "$1" > "$D/$TRIG.tmp"; mv "$D/$TRIG.tmp" "$D/$TRIG"; sleep 1.5; }
for v in $VALUES; do
    set_trig "$v"
    rm -f "$D"/eye_*.raw; : > "$D/EYES.tmp"; mv "$D/EYES.tmp" "$D/EYES"
    for i in $(seq 1 200); do [ "$(stat -c %s "$D/eye_1.raw" 2>/dev/null)" = $S ] && break; sleep 0.05; done
    mv "$D/eye_0.raw" /h/uc_tests/trr_${LABEL}_${v}_0.raw; mv "$D/eye_1.raw" /h/uc_tests/trr_${LABEL}_${v}_1.raw
    echo "$TRIG=$v dumped"
done
set_trig "$RESET"
