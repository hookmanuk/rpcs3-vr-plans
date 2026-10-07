#!/bin/sh
# sonstep.sh TAG "ADDR ADDR ...": Sonic race at Vblank 120 (temp config), 1 s frame stats, accelerate; after 12 s poke the
# addresses (f32) to 1/120; prints new frames/s before and after
S=/f/rpsc3/source/plans/tools/re/sonic
cd /f/rpsc3/source/plans/tools/re
CFGX="Video/Vblank Rate=120" RPCS3_VR_FRAMESTATS=1 sh $S/up.sh BLUS30839 vrtest_sonic_race >/dev/null
sh keys.sh 'W 60000\n'; sleep 12
W="$TEMP/rpcs3-vrprofile"; : > $W/POKE.tmp
for a in $2; do printf '%s f32 0.00833333\n' "${a#0x}" >> $W/POKE.tmp; done
mv -f $W/POKE.tmp $W/POKE; sleep 7
L=/f/rpsc3/source/rpcs3/bin/log/RPCS3.log; cp $L /tmp/sonstep.log
echo "$1: $(grep -ac 'VR poke' /tmp/sonstep.log) pokes"
grep -a "VR frame stats\|VR poke" /tmp/sonstep.log | tail -16 | sed -E 's/.*(VR poke [^:]*).*/\1/; s/.*avg ([0-9.]+) FPS.*new frames ([0-9.]+).*/  \1 FPS, new \2/' | tr '\n' ' '; echo
sh $S/down.sh BLUS30839 >/dev/null
