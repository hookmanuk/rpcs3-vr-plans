#!/bin/sh
# rc_newgame.sh VBLANK: boot Ratchet & Clank Collection in VR on the OpenXR Simulator (300%, Null audio, temporary pad
# and config via gsetup.sh; gclean.sh BCUS98282 afterwards) and leave it at the collection menu.
cd "$(dirname "$0")"
sh gsetup.sh BCUS98282 ${1:-90} "  Resolution Scale: 300\n  VR:\n    Enabled: true\n    Frame Rate: Unlimited\nAudio:\n  Renderer: \"Null\"\n"
py -3.13 simpose.py 0 0 0 >/dev/null
RPCS3_VR_FRAMESTATS=1 timeout 300 powershell -File gboot.ps1 -Iso "F:/rpsc3/games/Ratchet & Clank Collection (USA) (En,Fr,Es).iso" -Probe render=1 >/dev/null
sleep 8; powershell -File simwin.ps1 >/dev/null 2>&1
