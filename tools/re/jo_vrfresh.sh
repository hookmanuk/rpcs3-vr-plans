#!/bin/sh
# jo_vrfresh.sh TAG VBLANK: Journey from a fresh boot in VR on the simulator (300%), to the first dune, walk; frame stats
cd /f/rpsc3/source/plans/tools/re
py -3.13 cfgtemp.py NPUA70218 set "Video/VR/Enabled=true" "Video/VR/Frame Rate=Unlimited" "Video/Resolution Scale=300" "Video/Vblank Rate=$2" "Audio/Renderer=Null" >/dev/null
py -3.13 simpose.py 0 0 0 >/dev/null
RPCS3_VR_FRAMESTATS=8 timeout 90 powershell -File gboot.ps1 -Iso "F:/rpsc3/source/rpcs3/bin/dev_hdd0/game/NPUA70218/USRDIR/EBOOT.BIN" -Probe render=1 >/dev/null 2>&1
powershell -File simwin.ps1 >/dev/null 2>&1
sleep 38; sh keys.sh 'Return 300 2000\n'; sleep 75
L=/f/rpsc3/source/rpcs3/bin/log/RPCS3.log; n0=$(grep -ac "VR frame stats" $L)
sh keys.sh 'I 25000 100\n'; sleep 27
py -3.13 simshot.py jvf_$1 960 >/dev/null 2>&1
echo "$1: $(grep -a 'VR frame stats' $L | tail -n +$((n0 + 2)) | head -2 | sed 's/.*over 8.0 s: //; s/, 0.1%.*late/ late/; s/, new frames.*//' | tr '\n' '|')"
grep -a "Applied patch" $L | grep -o "description='[^']*'" | tr '\n' ' '; echo
powershell -c "Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force"; sleep 2
py -3.13 cfgtemp.py NPUA70218 restore >/dev/null
