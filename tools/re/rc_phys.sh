#!/bin/sh
# rc_phys.sh VBLANK [POKEFILE]: boot R&C1 to Veldin with Ratchet's position logged each frame; run forward, jump twice,
# walk back; print run speed and jump airtime (physpeek.py).
W="$TEMP/rpcs3-vrprofile"
printf "Video:\n  Vblank Rate: $1\n" > /f/rpsc3/source/rpcs3/bin/config/custom_configs/config_BCUS98282.yml
RC_PEEK="95db10 95db14 95db18" powershell -File rc_boot.ps1 >/dev/null; sh keys.sh 'X 200 2500\n'; sleep 20; sh keys.sh 'Return 200 3000\nReturn 200 3000\nX 200 3000\n'; sleep 30; sh keys.sh 'Return 200 3000\nReturn 200 3000\n'; sleep 20
py -3.13 shot.py BCUS98282 rcab_chk 320 >/dev/null; py -3.13 rcpaused.py rcab_chk.full.png >/dev/null && { sh keys.sh 'Return 200 2000\n'; sleep 3; }
[ -n "$2" ] && cp "$2" "$W/POKE" && sleep 2
sh keys.sh 'I 1500 1500\nX 400 2500\nX 400 2500\nK 1500 1000\n'; sleep 12
py -3.13 shot.py BCUS98282 rcphys_end 320 >/dev/null
cat /f/rpsc3/source/rpcs3/bin/log/RPCS3.log > "$TEMP/peeklog.txt"; WINDOW=24 py -3.13 physpeek.py "$TEMP/peeklog.txt" 95db10 95db14 95db18
