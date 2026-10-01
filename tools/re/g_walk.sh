#!/bin/sh
# g_walk.sh ID ISO_OR_STATE VBLANK ADDR [HOLD_MS]: boot (savestate) at VBLANK, then walk forward HOLD ms; print the distance at ADDR
sh gsetup.sh "$1" "$3"; powershell -File gboot.ps1 -Iso "$2" >/dev/null; sleep 10
H=${5:-600}; A=$(sh dumpnow.sh g_dump); sh keys.sh "I $H 800\n"; sleep 2; B=$(sh dumpnow.sh g_dump)
echo "vblank $3 hold $H: $(py -3.13 posat.py $4 $A $B) [$(powershell -c '(Get-Process rpcs3).MainWindowTitle' | cut -d'|' -f1)]"
