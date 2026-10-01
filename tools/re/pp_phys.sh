#!/bin/sh
# pp_phys.sh VBLANK TAG: boot the Puppeteer savestate (Kutaro in the cage) with his position (0x99a010) peeked each
# frame; walk right then left; speed (speedline.py, x/y plane).
S=/f/rpsc3/source/rpcs3/bin/savestates/BCUS98227/BCUS98227_1_0.SAVESTAT.zst
printf "Video:\n  Vblank Rate: $1\n" > /f/rpsc3/source/rpcs3/bin/config/custom_configs/config_BCUS98227.yml
G_PEEK="99a010 99a014 99a018" powershell -File gboot.ps1 -Iso "$S" >/dev/null; sleep 9
sh keys.sh 'L 1200 800\nJ 1200 800\n'; sleep 5
cp /f/rpsc3/source/rpcs3/bin/log/RPCS3.log "$TEMP/peek_$2.txt"
echo "$2: $(py -3.13 speedline.py "$TEMP/peek_$2.txt" 99a010 99a014 | tr ' ' '\n' | awk -F: '$2>0.5{print $2}' | sort -n | awk '{a[NR]=$1} END{print "n="NR, "p50="a[int(NR/2)+1], "p90="a[int(NR*0.9)]}') [$(powershell -c '(Get-Process rpcs3).MainWindowTitle' | cut -d'|' -f1)]"
