#!/bin/sh
# tox_speed.sh VBLANK: fresh boot to the field, walk forward 3 s with the position logged every frame; prints walking speed
printf "Video:\n  Vblank Rate: $1\n" > /f/rpsc3/source/rpcs3/bin/config/custom_configs/config_BLUS31006.yml
TOX_PEEK="e76d40 e76d48" powershell -File tox_boot.ps1 >/dev/null; sh keys.sh 'X 200 2000\n'; sleep 4; sh keys.sh 'I 3000 500\n'; sleep 5
cat /f/rpsc3/source/rpcs3/bin/log/RPCS3.log > "$TEMP/peeklog.txt"; echo "vblank $1: $(py -3.13 peekspeed.py "$TEMP/peeklog.txt" e76d40 e76d48)"
