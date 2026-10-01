#!/bin/sh
# rc_ab.sh TAG VBLANK [POKEFILE]: boot R&C1 to Veldin, optional poke, 3 dumps 4 s apart into keep/TAG.{0,1,2}
W="$TEMP/rpcs3-vrprofile"; mkdir -p "$W/keep"
printf "Video:\n  Vblank Rate: $2\n" > /f/rpsc3/source/rpcs3/bin/config/custom_configs/config_BCUS98282.yml
powershell -File rc_boot.ps1 >/dev/null; sh keys.sh 'X 200 2500\n'; sleep 20; sh keys.sh 'Return 200 3000\nReturn 200 3000\nX 200 3000\n'; sleep 30; sh keys.sh 'Return 200 3000\nReturn 200 3000\n'; sleep 20
py -3.13 shot.py BCUS98282 rcab_chk 320 >/dev/null; py -3.13 rcpaused.py rcab_chk.full.png && { sh keys.sh 'Return 200 2000
'; sleep 3; }
[ -n "$3" ] && cp "$3" "$W/POKE" && sleep 2
py -3.13 shot.py BCUS98282 "rcab_$1" 320 | tail -1
for n in 0 1 2; do D=$(sh dumpnow.sh rc_dump); for e in bin idx txt; do mv -f "$D.$e" "$W/keep/$1.$n.$e"; done; sleep 3; done
