#!/bin/bash
# icovr_survey.sh HZ SECONDS STAGE...: the ICO VR port at HZ on the simulator from each stage start (no input), one
# FRAMERATE line per stage: the last headset line (FPS, 1% low, late %) and the render thread / GPU per picture.
HZ=$1; S=$2; shift 2
for st in "$@"; do
    out=$(ICOVR_ENV="ICO_START_STAGE=$st" bash /f/rpsc3/source/plans/tools/icovr_rate.sh $HZ $S icovr-idle.txt)
    h=$(echo "$out" | grep -a "headset" | tail -1 | sed 's/.*headset //; s/; loop.*//')
    p=$(echo "$out" | grep -a "perf scene" | tail -1 | sed 's/.*GPU.s work \([0-9.]*\) ms.*render thread.s own CPU \([0-9.]*\) ms (walk \([0-9.]*\).*/GPU \1 ms, render thread \2 ms (walk \3)/')
    echo "FRAMERATE stage $st at $HZ Hz: $h; $p"
done
