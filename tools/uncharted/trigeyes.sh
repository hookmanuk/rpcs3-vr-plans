#!/usr/bin/env bash
# trigeyes.sh LABEL TRIGGER "VALUE ..." [REP=4]: one U2 session on the simulator (Matt's cliff save copy, eye ${EYE:-3584};
# ROUTE / START as eyeburst.sh), in play: for each value the dev trigger TRIGGER (%TEMP%/dcvr) set to it, then both eyes
# dumped REP times, kept as /h/uc_tests/trig_LABEL_VALUE_rN_{0,1}.raw. A knob sweep on the same frames (e.g. LIGHTEYE).
T=$(cd "$(dirname "$0")" && pwd)
LABEL=$1; TRIG=$2; VALUES=$3; REP=${4:-4}
D="$TEMP/dcvr"; mkdir -p "$D"
tasklist | grep -qi bb-probe.exe && { echo "bb-probe is running: stopping"; exit 1; }
(SESSION_ENV="$EXTRA" ROUTE="${ROUTE:-wait 45; press cross; wait 4; press cross; wait 55}" \
  HOLD=$(( $(echo $VALUES | wc -w) * (2 + 2 * REP) + 20 )) timeout 270 bash $T/sess.sh > /h/uc_tests/trigeyes_sess.log 2>&1 &)
sleep ${START:-120}
# PRE="TRIGGER=VALUE": another trigger set once first (e.g. IPD=0.2: a wide eye distance makes eye errors large).
if [ -n "$PRE" ]; then printf '%s' "${PRE#*=}" > "$D/${PRE%%=*}.tmp"; mv "$D/${PRE%%=*}.tmp" "$D/${PRE%%=*}"; sleep 1; fi
S=$(( ${EYE:-3584} * ${EYE:-3584} * 4 + 8 ))
for v in $VALUES; do
    printf '%s' "$v" > "$D/$TRIG.tmp"; mv "$D/$TRIG.tmp" "$D/$TRIG"
    sleep 1.5
    for r in $(seq 1 $REP); do
        rm -f "$D"/eye_*.raw; : > "$D/EYES.tmp"; mv "$D/EYES.tmp" "$D/EYES"
        for i in $(seq 1 200); do [ "$(stat -c %s "$D/eye_1.raw" 2>/dev/null)" = $S ] && break; sleep 0.05; done
        mv "$D/eye_0.raw" /h/uc_tests/trig_${LABEL}_${v}_r${r}_0.raw; mv "$D/eye_1.raw" /h/uc_tests/trig_${LABEL}_${v}_r${r}_1.raw
    done
done
rm -f "$D/$TRIG"
ls /h/uc_tests/trig_${LABEL}_*_1.raw | wc -l | sed 's/^/   dumps: /'
sleep 30; tasklist | grep -qi bb-probe.exe && echo "   (still running)"
