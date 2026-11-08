#!/usr/bin/env bash
# lenseyes.sh: one session on SteamVR (GAME=u2 default, Matt's save; eye ${EYE:-3584}; ROUTE= and START= seconds to play), in play: both eyes dumped (dev trigger EYES)
# with the lens skip off, on (mode 2), and off again; then lenscheck.py on the left eyes. Files in /h/uc_tests/lens_*.
T=$(cd "$(dirname "$0")" && pwd)
D="$TEMP/dcvr"; mkdir -p "$D"
tasklist | grep -qi bb-probe.exe && { echo "bb-probe is running: stopping"; exit 1; }
(RUNTIME=steamvr ROUTE="${ROUTE:-wait 45; press cross; wait 4; press cross; wait 55}" HOLD=40 timeout 240 bash $T/sess.sh > /h/uc_tests/lenseyes_sess.log 2>&1 &)
sleep ${START:-115}
trig() { printf '%s' "$2" > "$D/$1.tmp"; mv "$D/$1.tmp" "$D/$1"; }
shot() { # NAME: the next eyes, kept as /h/uc_tests/lens_NAME_eye0.raw
    rm -f "$D"/eye_*.raw; trig EYES ""
    for i in $(seq 1 40); do [ -s "$D/eye_0.raw" ] && break; sleep 0.25; done
    sleep 1; cp "$D/eye_0.raw" /h/uc_tests/lens_${GAME:-u2}_$1_eye0.raw && echo "   $1: eye 0 dumped"
}
trig LENS 0; sleep 3; shot offA
trig LENS 2; sleep 3; shot on
trig LENS 0; sleep 3; shot offB
rm -f "$D/LENS"
py -3 $T/lenscheck.py /h/uc_tests/lens_${GAME:-u2}_offA_eye0.raw /h/uc_tests/lens_${GAME:-u2}_on_eye0.raw /h/uc_tests/lens_${GAME:-u2}_offB_eye0.raw
sleep 25; tasklist | grep -qi bb-probe.exe && echo "   (still running)"
