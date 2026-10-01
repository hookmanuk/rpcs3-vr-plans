#!/bin/sh
# ar_phys.sh VBLANK [POKEFILE]: boot the Anarchy Reigns practice savestate (made at 90 FPS: characters hold dt 1/90) with
# Jack's position logged each frame; run forward, jump twice, run back; print run speed and jump airtime (physpeek.py).
W="$TEMP/rpcs3-vrprofile"; S=/f/rpsc3/source/rpcs3/bin/savestates/BLUS30632/ar_practice.SAVESTAT.zst
printf "Video:\n  Vblank Rate: $1\n" > /f/rpsc3/source/rpcs3/bin/config/custom_configs/config_BLUS30632.yml
G_PEEK="1d7fc10 1d7fc18 1d7fc14" powershell -File gboot.ps1 -Iso "$S" >/dev/null; sleep 8
[ -n "$2" ] && cp "$2" "$W/POKE" && sleep 2
sh keys.sh 'I 1500 1500\nX 100 1500\nX 100 2000\nK 1500 1000\n'; sleep 9
py -3.13 shot.py BLUS30632 arphys_end 320 >/dev/null
cat /f/rpsc3/source/rpcs3/bin/log/RPCS3.log > "$TEMP/peeklog.txt"; cp "$TEMP/peeklog.txt" "$TEMP/peek_${3:-last}.txt"; WINDOW=12 py -3.13 physpeek.py "$TEMP/peeklog.txt" 1d7fc10 1d7fc18 1d7fc14
echo "$(powershell -c '(Get-Process rpcs3).MainWindowTitle' | cut -d'|' -f1)"
