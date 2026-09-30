#!/bin/sh
# gt_quick.sh OUT 'probe' [msaa]: boot the GT5 race-start savestate, screenshot as soon as frames flow (car still alongside)
C=/f/rpsc3/source/rpcs3/bin/config/custom_configs/config_BCUS98114.yml; cp "$C" "$TEMP/gtq.bak"
[ -n "$3" ] && sed -i "s/^  MSAA: .*/  MSAA: $3/" "$C"
powershell -File gt_state.ps1 -Probe "$2" >/dev/null
for i in $(seq 1 200); do t=$(powershell -c "(Get-Process rpcs3).MainWindowTitle" | grep -o "FPS: [0-9]*" | grep -o "[0-9]*"); [ "${t:-0}" -gt 40 ] && grep -aq "Building function" /f/rpsc3/source/rpcs3/bin/log/RPCS3.log && break; sleep 0.5; done
py -3.13 shot.py BCUS98114 "$1" 1280 | tail -1
cp "$TEMP/gtq.bak" "$C"
