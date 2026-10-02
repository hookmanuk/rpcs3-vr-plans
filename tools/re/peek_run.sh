#!/bin/sh
# peek_run.sh ID STATE RATE PEEKFILE TAG [SECONDS]: boot bin/savestates/ID/STATE.SAVESTAT.zst flat at Vblank RATE
# (temporary custom config, removed after) with RPCS3_VR_PEEK=PEEKFILE (hex addresses, one per line) logged every frame,
# for SECONDS (default 3) after a 3 s settle, and save the "VR peek" log lines to dumps/TAG.peek.
# frameupd.py TAG then shows how often each word changes from one presented frame to the next.
id=$1; state=$2; rate=$3; peek=$4; tag=$5; secs=${6:-3}
cd "$(dirname "$0")"
C=/f/rpsc3/source/rpcs3/bin/config/custom_configs/config_$id.yml
L=/f/rpsc3/source/rpcs3/bin/log/RPCS3.log
[ -f "$C" ] && { echo "a custom config exists for $id: not touching it"; exit 1; }
printf 'Video:\n  Vblank Rate: %s\n' "$rate" > "$C"
mkdir -p dumps
RPCS3_VR_PEEK="$peek" RPCS3_VR_PEEK_EVERY=1 powershell -File ../launch.ps1 -Game "F:/rpsc3/source/rpcs3/bin/savestates/$id/$state.SAVESTAT.zst" -NoHeadset -Probe render=0 | tail -1
sleep 3
mark=$(grep -ac 'VR peek' "$L")
sleep "$secs"
grep -a 'VR peek' "$L" | tail -n +$((mark + 1)) > dumps/$tag.peek
powershell -c "(Get-Process rpcs3).MainWindowTitle; Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force; while (Get-Process rpcs3 -ErrorAction SilentlyContinue) { Start-Sleep -Milliseconds 200 }"
rm -f "$C"; [ -f "$C" ] && echo "WARNING: temporary $C still present"
wc -l < dumps/$tag.peek
