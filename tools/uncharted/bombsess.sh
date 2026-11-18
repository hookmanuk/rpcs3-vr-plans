#!/usr/bin/env bash
# bombsess.sh "EXTRA ENV" [HOLD]: U2 on SteamVR from a copy of Matt's saves (H:/uc_tests/mc_copy, Borneo Continue) to
# the green-bomb cutscene and past it: Continue, the camera nudged a little right (the desk headset looks left of the
# path), forward with a jump tap every 2 s for 8 s (reaches Sully and the bomb: the cutscene), then standing where it
# ends. Matt 2026-11-18: after this cutscene the game drops (SteamVR at 45 Hz, CPU spikes). Pictures b0 (before),
# b1 (in the cutscene), b2 (after) in out/try/u2. The session stays up for HOLD seconds (default 1200) for live work.
T=$(dirname "$0")
R="wait 70; press cross; wait 5; press cross; wait 55; press rx=200 0.25; wait 1; shot b0; hold ly=0"
for i in 1 2 3 4; do R="$R; wait 2; hold ly=0 cross; wait 0.15; hold ly=0; wait 1.85"; done
R="$R; release; wait 2; shot b1; wait 40; shot b2"
RUNTIME=steamvr UCUSER=mc_copy SESSION_ENV="BB_GPU_USER_DIR=H:\\uc_tests\\mc_copy BB_FRAME_STATS=1 $1" ROUTE="$R" HOLD=${2:-1200} \
  timeout $(( ${2:-1200} + 400 )) bash $T/sess.sh > /h/uc_tests/bombsess.log 2>&1
