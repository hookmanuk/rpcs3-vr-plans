#!/bin/sh
# fl_speed.sh VBLANK TAG: Flower savestate vrtest_journey_dune at VBLANK; hold Cross (wind) 6 s; shots at 2, 4, 6 s
C=/f/rpsc3/source/rpcs3/bin/config/custom_configs/config_NPUA70218.yml
printf 'Video:\n  Vblank Rate: %s\n' "$1" > "$C"
RPCS3_VR_FRAMESTATS=4 powershell -File gboot.ps1 -Iso "F:/rpsc3/source/rpcs3/bin/savestates/NPUA70218/vrtest_journey_dune.SAVESTAT.zst" >/dev/null
sleep 8
sh keys.sh 'X 6500 100\n'
for t in 2 4 6; do py -3.13 shot.py NPUA70218 "jos_$2_$t" 480 - 1.7 >/dev/null; done
grep "frame stats" /f/rpsc3/source/rpcs3/bin/log/RPCS3.log | tail -2 | sed 's/.*frame stats: //'
