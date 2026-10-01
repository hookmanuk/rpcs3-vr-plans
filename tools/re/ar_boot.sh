#!/bin/sh
# ar_boot.sh [VBLANK]: boot Anarchy Reigns (BLUS30632) to Training > Practice (Jack in the arena). Needs gsetup.sh BLUS30632.
# Jack's position (feet, f32 xyz): 0x1d7fc10.
[ -n "$1" ] && printf "Video:\n  Vblank Rate: $1\n" > /f/rpsc3/source/rpcs3/bin/config/custom_configs/config_BLUS30632.yml
powershell -File gboot.ps1 -Iso "F:/rpsc3/games/Anarchy Reigns (USA) (En,Ja,Fr,Es,It).iso" $AR_ARGS >/dev/null
sleep 12; sh keys.sh 'X 80 2500\nX 80 2500\nX 80 2500\n'; sleep 12
sh keys.sh 'X 80 4000\nReturn 80 7000\n'; sleep 3
sh keys.sh 'Down 60 2000\nDown 60 2000\n'; sleep 1
py -3.13 shot.py BLUS30632 ar_menu 480 >/dev/null
sh keys.sh 'X 80 3000\nX 80 9000\nX 80 3000\n'; sleep 17
