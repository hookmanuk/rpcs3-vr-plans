#!/bin/sh
# tox_ab.sh TAG VBLANK: boot ToX to the field at that vblank, close the controls screen, take 3 dumps 4 s apart into keep/TAG.{0,1,2}
W="$TEMP/rpcs3-vrprofile"; mkdir -p "$W/keep"
printf "Video:\n  Vblank Rate: $2\n" > /f/rpsc3/source/rpcs3/bin/config/custom_configs/config_BLUS31006.yml
powershell -File tox_boot.ps1 >/dev/null; sh keys.sh 'X 200 2000\n'; sleep 4
py -3.13 shot.py BLUS31006 "tox_$1" 320 | tail -1
for n in 0 1 2; do D=$(sh dumpnow.sh tox_dump); for e in bin idx txt; do mv -f "$D.$e" "$W/keep/$1.$n.$e"; done; sleep 3; done
