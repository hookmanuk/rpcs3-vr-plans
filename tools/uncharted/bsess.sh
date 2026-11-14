#!/usr/bin/env bash
# bsess.sh [HOLD_S=600]: a U2 session at Matt's Borneo start (chapter 3; his saves of 2026-11-14 copied to
# H:/uc_tests/u2borneo, the savedata put back from u2borneo_savedata_orig before each run), eye ${EYE:-2880}, simulator.
# Runs in the background (log /h/uc_tests/borneo_sess.log, the game's out/try/u2/run.log); play begins ~105 s in.
# Drive it with pad.sh "ly=0" 3 and the dev triggers (%TEMP%/dcvr). EXTRA= more environment.
T=$(cd "$(dirname "$0")" && pwd)
tasklist | grep -qi bb-probe.exe && { echo "bb-probe is running: stopping"; exit 1; }
rm -rf /h/uc_tests/u2borneo/savedata; cp -r /h/uc_tests/u2borneo_savedata_orig /h/uc_tests/u2borneo/savedata
H=${1:-600}
(UCUSER=u2borneo EYE=${EYE:-2880} SESSION_ENV="$EXTRA" ROUTE="wait 45; press cross; wait 4; press cross; wait 50" HOLD=$H \
  timeout $((H + 130)) bash $T/sess.sh > /h/uc_tests/borneo_sess.log 2>&1 &)
