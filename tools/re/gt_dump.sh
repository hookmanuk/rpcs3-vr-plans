#!/bin/sh
# gt_dump.sh TAG 'probe' 'addr addr ...': boot the race-start savestate, dump surfaces (both eyes) as soon as frames flow
W="$TEMP/rpcs3-vrprofile"; powershell -File gt_state.ps1 -Probe "$2" >/dev/null
for i in $(seq 1 200); do t=$(powershell -c "(Get-Process rpcs3).MainWindowTitle" | grep -o "FPS: [0-9]*" | grep -o "[0-9]*"); [ "${t:-0}" -gt 40 ] && grep -aq "Building function" /f/rpsc3/source/rpcs3/bin/log/RPCS3.log && break; sleep 0.5; done
rm -f "$W"/RTDUMP.*; echo "$3" | tr ' ' '\n' > "$W/RTDUMP"; sleep 3
mkdir -p "$W/$1"; mv "$W"/RTDUMP.* "$W/$1/" 2>/dev/null; ls "$W/$1" | head -20
