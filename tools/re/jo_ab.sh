#!/bin/sh
# jo_ab.sh TAG "core lines" "video lines": Journey savestate at Vblank 120 flat with extra settings; prints FPS windows
C=/f/rpsc3/source/rpcs3/bin/config/custom_configs/config_NPUA70218.yml
printf "Core:\n%bVideo:\n  Vblank Rate: 120\n%b" "$2" "$3" > "$C"
RPCS3_VR_FRAMESTATS=4 powershell -File gboot.ps1 -Iso "F:/rpsc3/source/rpcs3/bin/savestates/NPUA70218/vrtest_journey_dune.SAVESTAT.zst" >/dev/null
sleep 6; sh keys.sh 'I 9000 100\n'; sleep 9
echo "$1: $(grep -a 'frame stats' /f/rpsc3/source/rpcs3/bin/log/RPCS3.log | tail -2 | sed 's/.*over 4.0 s: //; s/, 0.1%.*RSX/ RSX/' | tr '\n' '|')"
