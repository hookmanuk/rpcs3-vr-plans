#!/bin/sh
# jo_fresh.sh TAG [VBLANK=120]: Journey from a fresh boot (title, Start), flat; walks; prints frame stats and a shot
C=/f/rpsc3/source/rpcs3/bin/config/custom_configs/config_NPUA70218.yml
printf "Video:\n  Vblank Rate: ${2:-120}\n" > "$C"
RPCS3_VR_FRAMESTATS=4 powershell -File gboot.ps1 -Iso "F:/rpsc3/source/rpcs3/bin/dev_hdd0/game/NPUA70218/USRDIR/EBOOT.BIN" >/dev/null
sh keys.sh 'wait 40000\nReturn 200 3000\nX 200 3000\nwait 50000\nI 12000 100\n'
sleep 105
py -3.13 shot.py NPUA70218 "jof_$1" 480 >/dev/null
echo "$1: $(grep -a 'frame stats' /f/rpsc3/source/rpcs3/bin/log/RPCS3.log | tail -3 | sed 's/.*over 4.0 s: //; s/, 0.1%.*RSX/ RSX/' | tr '\n' '|')"
grep -a "Applied patch" /f/rpsc3/source/rpcs3/bin/log/RPCS3.log | grep -o "description='[^']*'" | sort -u
