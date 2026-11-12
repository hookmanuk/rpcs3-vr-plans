#!/bin/bash
# icovr_survey.sh HZ SECONDS STAGE...: the ICO VR port at HZ on the simulator from each stage start (no input), one
# FRAMERATE line per stage: FPS, the display side (1% low by display times, skipped slots, frames over budget,
# picture wait p99), the render thread's p99 a picture and the GPU / render thread per picture.
HZ=$1; S=$2; shift 2
L=/h/ico-pc/dist/x64/logs/ico-pc.log
for st in "$@"; do
    ICOVR_ENV="ICO_START_STAGE=$st" bash /f/rpsc3/source/plans/tools/icovr_rate.sh $HZ $S icovr-idle.txt >/dev/null
    h=$(grep -a "vr: headset" $L | tail -1 | sed 's/.*headset \([0-9.]*\) FPS.*/\1 FPS/')
    d=$(grep -a "vr: display" $L | tail -1 | sed 's/.*display: 1% low \([0-9.]*\) FPS.*worst gap \([0-9.]*\) ms), \([0-9]*\) display slots skipped of \([0-9]*\), \([0-9]*\) frames over.*p99 \([0-9.]*\) ms/1% low \1 (worst gap \2 ms), skipped \3\/\4, over budget \5, picture p99 \6 ms/')
    r=$(grep -a "render thread a picture" $L | tail -1 | sed 's/.*interpolated [0-9]* p99 \([0-9.]*\) max \([0-9.]*\) ms; a new game frame.s [0-9]* p99 \([0-9.]*\) max \([0-9.]*\).*/render p99 \1 (max \2), new-frame p99 \3 (max \4)/')
    p=$(grep -a "perf scene" $L | tail -1 | sed 's/.*GPU.s work \([0-9.]*\) ms.*render thread.s own CPU \([0-9.]*\) ms (walk \([0-9.]*\).*/GPU \1 ms, render thread \2 ms (walk \3)/')
    echo "FRAMERATE stage $st at $HZ Hz: $h, $d; $r; $p"
done
