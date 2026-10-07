#!/bin/sh
# sonq.sh TAG: Sonic race at Vblank 120 (temp), 1 s frame stats, accelerate; new frames/s + two HUD shots 5 s apart
S=/f/rpsc3/source/plans/tools/re/sonic
cd /f/rpsc3/source/plans/tools/re
CFGX="Video/Vblank Rate=${RATE:-120}" RPCS3_VR_FRAMESTATS=1 sh $S/up.sh BLUS30839 vrtest_sonic_race >/dev/null
sh keys.sh 'W 60000\n'; sleep 8
t1=$(date +%s.%N); SHOT_MOVE=1 py -3.13 shot.py BLUS30839 sonq_$1_a 1280 >/dev/null; sleep 5
t2=$(date +%s.%N); SHOT_MOVE=1 py -3.13 shot.py BLUS30839 sonq_$1_b 1280 >/dev/null; sleep 2
cp /f/rpsc3/source/rpcs3/bin/log/RPCS3.log $S/sonq.log
grep -a "Applied patch" $S/sonq.log | grep -o "description='[^']*'" | tr '\n' ' '; echo
grep -a "VR frame stats" $S/sonq.log | tail -8 | sed -E 's/.*avg ([0-9.]+) FPS.*new frames ([0-9.]+).*/\1:\2/' | tr '\n' ' '; echo
py -3.13 -c "print('shot gap %.2f s' % ($t2 - $t1))"
sh $S/down.sh BLUS30839 >/dev/null
