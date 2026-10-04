#!/bin/sh
# xmen_boot.sh [VBLANK=60] [EXTRA]: boot X-Men Origins: Wolverine (BLUS30268) from the disc with a temporary pad and
# config (Null audio, Compatible Savestate Mode), skip the logos, New Game > Normal, wait out the unskippable intro
# (~2 min) to the first control in the jungle. Leaves RPCS3 running (screenshot x_boot.png to check).
cd "$(dirname "$0")"
sh gsetup.sh BLUS30268 ${1:-60} "Audio:\n  Renderer: \"Null\"\nSavestate:\n  Compatible Savestate Mode: true\n$2"
L=/f/rpsc3/source/rpcs3/bin/log/RPCS3.log
RPCS3_VR_FRAMESTATS=2 timeout 400 powershell -File gboot.ps1 -Iso "F:/rpsc3/games/X-Men Origins - Wolverine - Uncaged Edition (USA) (En,Fr).iso" >/dev/null
sleep 25
sh keys.sh 'Return 200 3000\nX 200 2000\nReturn 200 2000\nX 200 2000\nReturn 200 4000\nX 200 3000\nX 200 3000\n'
sleep 150
SHOT_MOVE=1 py -3.13 shot.py BLUS30268 x_boot 640
