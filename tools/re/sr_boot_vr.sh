#!/bin/sh
# sr_boot_vr.sh [VBLANK=72]: as sr_boot.sh, in VR on the OpenXR Simulator (300%, Frame Rate Unlimited): boots SEGA Rally
# Revo from disc, Start > Premier > Amateur > AZA Challenge > Safari > Subaru > race, and leaves it running at the
# grid. gclean.sh BLUS30068 afterwards.
cd "$(dirname "$0")"
sh gsetup.sh BLUS30068 ${1:-72} "  Resolution Scale: 300\n  VR:\n    Enabled: true\n    Frame Rate: Unlimited\nAudio:\n  Renderer: \"Null\"\nSavestate:\n  Compatible Savestate Mode: true\nCore:\n  Disable SPU GETLLAR Spin Optimization: true\n"
py -3.13 simpose.py 0 0 0 >/dev/null
RPCS3_VR_FRAMESTATS=1 timeout 300 powershell -File gboot.ps1 -Iso "F:/rpsc3/games/Sega Rally Revo (USA) (En,Fr,De,Es,It).iso" -Probe render=1 >/dev/null
sleep 8; powershell -File simwin.ps1 >/dev/null 2>&1
sleep 32
for k in Return X X X X X X; do sh keys.sh "$k 200 3000\n"; sleep 8; done
sleep 25; sh keys.sh 'X 200 3000\n'; sleep 15
sh keys.sh 'X 200 3000\n'; sleep 17
sh keys.sh 'X 200 3000\n'
