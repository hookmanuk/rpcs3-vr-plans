#!/usr/bin/env bash
# skipeyes.sh LABEL "HASH ..." : one U2 session on the simulator (Matt's cliff save copy, eye ${EYE:-3584}; ROUTE /
# START as eyeburst.sh), in play: both eyes dumped REP times (default 1) with nothing skipped, then with each shader skipped live
# (BB_SHADER_DEBUG_FILE "skip HASH"), kept as /h/uc_tests/skipeyes_LABEL_HASH_rN_{0,1}.raw. Finds which pass draws something.
T=$(cd "$(dirname "$0")" && pwd)
LABEL=$1; HASHES="none $2"
D="$TEMP/dcvr"; mkdir -p "$D"
F=/h/uc_tests/skip_live.txt; : > $F
tasklist | grep -qi bb-probe.exe && { echo "bb-probe is running: stopping"; exit 1; }
(SESSION_ENV="BB_SHADER_DEBUG_FILE=H:\\uc_tests\\skip_live.txt $EXTRA" ROUTE="${ROUTE:-wait 45; press cross; wait 4; press cross; wait 55}" \
  HOLD=$(( $(echo $HASHES | wc -w) * (2 + 2 * ${REP:-1}) + 20 )) timeout 260 bash $T/sess.sh > /h/uc_tests/skipeyes_sess.log 2>&1 &)
sleep ${START:-120}
# PRE="TRIGGER=VALUE": a dev trigger set once first (e.g. IPD=0.2: a wide eye distance makes eye errors large).
if [ -n "$PRE" ]; then printf '%s' "${PRE#*=}" > "$D/${PRE%%=*}.tmp"; mv "$D/${PRE%%=*}.tmp" "$D/${PRE%%=*}"; sleep 1; fi
S=$(( ${EYE:-3584} * ${EYE:-3584} * 4 + 8 ))
for h in $HASHES; do
    if [ $h = none ]; then : > $F; else echo "skip $h" > $F; fi
    sleep 1.5
    for r in $(seq 1 ${REP:-1}); do
        rm -f "$D"/eye_*.raw; : > "$D/EYES.tmp"; mv "$D/EYES.tmp" "$D/EYES"
        for i in $(seq 1 200); do [ "$(stat -c %s "$D/eye_1.raw" 2>/dev/null)" = $S ] && break; sleep 0.05; done
        mv "$D/eye_0.raw" /h/uc_tests/skipeyes_${LABEL}_${h}_r${r}_0.raw; mv "$D/eye_1.raw" /h/uc_tests/skipeyes_${LABEL}_${h}_r${r}_1.raw
    done
done
: > $F
ls /h/uc_tests/skipeyes_${LABEL}_*_1.raw | wc -l | sed 's/^/   dumps: /'
sleep 30; tasklist | grep -qi bb-probe.exe && echo "   (still running)"
