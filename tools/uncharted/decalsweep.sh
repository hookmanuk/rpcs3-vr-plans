#!/usr/bin/env bash
# decalsweep.sh "values": on the running game, for each DECAL value: both eyes with the decal, then with it skipped.
D="$TEMP/dcvr"; N=${N:-2160}
trig() { printf '%s' "$2" > $D/$1.tmp; mv $D/$1.tmp $D/$1; }
dump() { rm -f $D/eye_*.raw; : > $D/EYES.tmp; mv $D/EYES.tmp $D/EYES; for i in $(seq 1 200); do [ "$(stat -c %s $D/eye_1.raw 2>/dev/null)" = $((N*N*4+8)) ] && break; sleep 0.05; done; sleep 0.2; mv $D/eye_0.raw H:/uc_tests/ds_$1_0.raw; mv $D/eye_1.raw H:/uc_tests/ds_$1_1.raw; }
for v in $1; do trig DECAL $v; sleep 0.6; trig SKIP ""; sleep 0.5; dump ${v}_on; trig SKIP f7dd5989; sleep 0.6; dump ${v}_off; trig SKIP ""; sleep 0.3; done
