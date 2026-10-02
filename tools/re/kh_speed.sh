#!/bin/sh
# kh_speed.sh RATE OUT [KEYS]: boot vrtest_kh1_dive flat at Vblank RATE (temporary custom config, removed after), walk
# (default: forward 2 s), screenshot OUT. Compare OUT images across rates: a real-time game walks the same distance.
rate=$1; out=$2; keys=${3:-'I 2000 500\n'}
cd "$(dirname "$0")"
C=/f/rpsc3/source/rpcs3/bin/config/custom_configs/config_BLUS31212.yml
[ -f "$C" ] && { echo "a custom config exists: not touching it"; exit 1; }
printf 'Video:\n  Vblank Rate: %s\n' "$rate" > "$C"
powershell -File ../launch.ps1 -Game 'F:\rpsc3\source\rpcs3\bin\savestates\BLUS31212\vrtest_kh1_dive.SAVESTAT.zst' -NoHeadset | tail -1
sleep 6
sh keys.sh "$keys"; sleep 4
py -3.13 shot.py BLUS31212 "$out" 960 | tail -1
grep -a 'Vblank Rate' /f/rpsc3/source/rpcs3/bin/log/RPCS3.log | head -1
powershell -c "Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force; while (Get-Process rpcs3 -ErrorAction SilentlyContinue) { Start-Sleep -Milliseconds 200 }"
rm -f "$C"; [ -f "$C" ] && echo "WARNING: temporary $C still present"
true
