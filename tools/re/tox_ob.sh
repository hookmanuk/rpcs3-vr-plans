#!/bin/sh
# tox_ob.sh VBLANK TAG: fresh boot to the field, screenshot, then dumps around a walk forward and a walk back
# (HOLD ms each, default 1200); prints the out-and-back candidates (player position 0xe78150).
printf "Video:\n  Vblank Rate: $1\n" > /f/rpsc3/source/rpcs3/bin/config/custom_configs/config_BLUS31006.yml
powershell -File tox_boot.ps1 >/dev/null; sh keys.sh 'X 200 2000\n'; sleep 4; py -3.13 shot.py BLUS31006 "ob_$2" 320 | tail -1
H=${HOLD:-1200}
A=$(sh dumpnow.sh tox_dump); sh keys.sh "I $H 800\n"; sleep 3; B=$(sh dumpnow.sh tox_dump); sh keys.sh "K $H 800\n"; sleep 3; C=$(sh dumpnow.sh tox_dump)
py -3.13 outback.py $A $B $C 2>/dev/null
