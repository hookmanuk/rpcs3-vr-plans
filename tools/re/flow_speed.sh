#!/bin/sh
# flow_speed.sh VBLANK: flOw savestate at VBLANK; tilt right + boost 3 s; shots at 1.5 and 3.5 s
printf 'Video:\n  Vblank Rate: %s\n' "$1" > /f/rpsc3/source/rpcs3/bin/config/custom_configs/config_NPUA80001.yml
powershell -File gboot.ps1 -Iso "F:/rpsc3/source/rpcs3/bin/savestates/NPUA80001/vrtest_flow_title.SAVESTAT.zst" >/dev/null
sleep 6; sh keys.sh 'motion 620 512 450 -\nX 3000 100\nmotion 512 512 512 -\n'
py -3.13 shot.py NPUA80001 "fws_$1_a" 480 - 1.2 >/dev/null; py -3.13 shot.py NPUA80001 "fws_$1_b" 480 - 1.3 >/dev/null
