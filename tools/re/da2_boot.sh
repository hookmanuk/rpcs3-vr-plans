#!/bin/sh
# da2_boot.sh: boot Dragon Age II (BLUS30645) from the disc with a temporary pad and config (Null audio, Compatible
# Savestate Mode), New Game, Male Warrior, quick start, X through the prologue to the first fight (~4 min).
# Leaves RPCS3 running (screenshot da2_bootdone.png).
cd "$(dirname "$0")"
sh gsetup.sh BLUS30645 60 "Audio:\n  Renderer: \"Null\"\nSavestate:\n  Compatible Savestate Mode: true\n"
RPCS3_VR_FRAMESTATS=2 timeout 300 powershell -File gboot.ps1 -Iso "F:/rpsc3/games/Dragon Age II (USA) (En,Fr,De,Es,It,Pl,Ru).iso" >/dev/null
sleep 45
for i in 1 2 3 4 5 6 7 8 9 10; do sh keys.sh 'Return 200 1500\nX 200 1500\n'; sleep 12; done
sleep 30
for i in 1 2 3 4 5 6; do sh keys.sh 'X 200 1200\nX 200 1200\nX 200 1200\n'; sleep 12; done
py -3.13 shot.py BLUS30645 da2_bootdone 640 >/dev/null
