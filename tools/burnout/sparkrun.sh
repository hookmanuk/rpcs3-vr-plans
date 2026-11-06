#!/usr/bin/env bash
# sparkrun.sh NAME: Swiss Roll's crash event, full throttle into the crash; at the first big sparks (no pause, the game
# running) the head sweeps and the composite is shot back to back. Closes the game, restores the config.
B=/c/Users/matt/AppData/Local/Temp/claude/f--rpsc3-source/4ada4739-f604-4e4a-99d4-1521d85f84f7/scratchpad/bo
V=/c/Users/matt/AppData/Local/Temp/claude/f--rpsc3-source/4442e172-019d-4ce9-a371-7b716d311939/scratchpad/vr
N=$1; cd "$B" || exit 1; taskkill //F //IM burnout.exe >/dev/null 2>&1; sleep 2; : > pad.txt
D=$(cygpath -u "$TEMP")/xerenge_vr; mkdir -p "$D"; rm -f "$D/SPARKS"
export XERENGE_VR_DEV=1 XERENGE_UPLOG=1
(LIMIT=400 bash borun_vp.sh "$N" &)
sleep 24; python -I "$V/simwin.py" 1904 940 >/dev/null
python -I bodrive.py "wait 3; press a; wait 4; press start; wait 4" >/dev/null
python -I bodrive.py "press a; wait 4; press a; wait 8; press a; wait 6; press a; wait 6; press a; wait 6; press right 0.08; wait 2; press a; wait 6; press a" >/dev/null
for i in $(seq 1200); do grep -q "SplashScreen/SplashScreen" "$N.log" 2>/dev/null && break; sleep 0.1; done
python -I bodrive.py "wait 3; press a; wait 2" >/dev/null; python -I bodrive.py "wait 12" >/dev/null; python -I bodrive.py "press a; wait 3" >/dev/null
(python -I bodrive.py "wait ${PREWAIT:-6}; press a 0.5; wait 1; press a 0.5; wait 2.5; hold rt; wait 7; release" >/dev/null &)
for i in $(seq 4000); do [ -f "$D/SPARKS" ] && break; sleep 0.01; done
if [ -f "$D/SPARKS" ]; then
  (SWEEP_T0=$(cygpath -w "$B/${N}.t0") python -I headsweep.py 6 "${AMP:-25}" "${SWEEP:-2}" &)
  [ "${SHOTS:-14}" = 0 ] && sleep 7
  [ "${SHOTS:-14}" = 0 ] || for k in $(seq -w 1 "${SHOTS:-14}"); do python -I simcap.py "${N}_c$k" >/dev/null 2>>"${N}_cap.err"; done
else echo no-sparks; fi
sleep 2; taskkill //F //IM burnout.exe >/dev/null 2>&1; sleep 2; : > pad.txt; cp conf_matt_ycycle.bak /h/Xerenge/xerenge.conf
python /f/rpsc3/source/plans/tools/re/simpose.py 0 0 0 >/dev/null; echo DONE
