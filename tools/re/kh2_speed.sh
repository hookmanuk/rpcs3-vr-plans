#!/bin/sh
# kh2_speed.sh STATE OUT [RATE] [KEYS]: boot bin/savestates/BLUS31460/STATE flat (Vblank RATE, default 60, via a temporary
# custom config removed after), run KEYS (default: run forward 1.5 s), screenshot OUT. Compare OUT images between the
# 30 FPS state and the patched one: a real-time game moves the same distance.
st=$1; out=$2; rate=${3:-60}; keys=${4:-'I 1500 500\n'}
cd "$(dirname "$0")"
C=/f/rpsc3/source/rpcs3/bin/config/custom_configs/config_BLUS31460.yml
[ -f "$C" ] && { echo "a custom config exists: not touching it"; exit 1; }
printf 'Video:\n  Vblank Rate: %s\n' "$rate" > "$C"
powershell -File ../launch.ps1 -Game "F:/rpsc3/source/rpcs3/bin/savestates/BLUS31460/${st}.SAVESTAT.zst" -NoHeadset | tail -1
sleep 6
sh keys.sh "$keys"; sleep 4
py -3.13 shot.py BLUS31460 "$out" 960 | tail -1
powershell -c "Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force; while (Get-Process rpcs3 -ErrorAction SilentlyContinue) { Start-Sleep -Milliseconds 200 }"
rm -f "$C"; [ -f "$C" ] && echo "WARNING: temporary $C still present"
true
