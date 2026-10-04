#!/bin/sh
# sr_boot.sh [VBLANK=60]: boot SEGA Rally Revo (BLUS30068) from disc with a temporary pad and config (Null audio,
# Compatible Savestate Mode), Start > Premier > Amateur > AZA Challenge > Safari > Subaru > race. Leaves RPCS3 running
# at the grid (~15 s into the race, screenshot sr_bootdone.png).
cd "$(dirname "$0")"
sh gsetup.sh BLUS30068 ${1:-60} "Audio:\n  Renderer: \"Null\"\nSavestate:\n  Compatible Savestate Mode: true\nCore:\n  Disable SPU GETLLAR Spin Optimization: true\n$2"
RPCS3_VR_FRAMESTATS=2 timeout 300 powershell -File gboot.ps1 -Iso "F:/rpsc3/games/Sega Rally Revo (USA) (En,Fr,De,Es,It).iso" >/dev/null
sleep 40
for k in Return X X X X X X; do sh keys.sh "$k 200 3000\n"; sleep 8; done
sleep 25; sh keys.sh 'X 200 3000\n'; sleep 15
sh keys.sh 'X 200 3000\n'; sleep 17
sh keys.sh 'X 200 3000\n'; sleep 15
py -3.13 shot.py BLUS30068 sr_bootdone 640 >/dev/null
