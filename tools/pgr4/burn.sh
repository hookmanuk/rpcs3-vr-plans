#!/bin/sh
# burn.sh EYE TAG [NAME=VALUE...]: the race grid in VR, then a burnout (throttle, brake, steering held): the headset view with the
# game running (particles don't show when paused) to out/TAG_1.png, _2.png, with the frame rate, and the log's vr lines.
T=/f/rpsc3/source/plans/tools/pgr4; P=$T/pg.sh; O=H:/PGR4-ReGPU/out; SP=/f/rpsc3/source/plans/tools/re; L=/h/PGR4-ReGPU/thirdparty/ReGPU/out/live.log
EYE=$1; TAG=$2; shift 2
sh $T/vrrace.sh $EYE SIMXR_HZ=240 "$@" 2>&1 | tail -1 | cut -c1-70
$P trigger R 1 >/dev/null; $P trigger L 1 >/dev/null; $P stick L -0.6 0 >/dev/null
sleep 3
python $SP/simshot.py $O/${TAG}_1 1400 | cut -c1-14
sleep 2
python $T/vrperf.py 4 "$EYE burnout $TAG" | cut -c1-96
$P trigger L 0 >/dev/null; sleep 2
python $SP/simshot.py $O/${TAG}_2 1400 | cut -c1-14
$P trigger R 0 >/dev/null; $P stick L 0 0 >/dev/null
grep -E 'vr: smoke|DEVICE|removed|Fatal' $L | head -4 | cut -c12-110
