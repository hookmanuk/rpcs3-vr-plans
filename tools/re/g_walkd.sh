#!/bin/sh
# g_walkd.sh ID STATE VBLANK ADDR KEY HOLD: boot STATE at VBLANK, hold KEY for HOLD ms; print the distance at ADDR
sh gsetup.sh "$1" "$3"; powershell -File gboot.ps1 -Iso "$2" >/dev/null; sleep 10
A=$(sh dumpnow.sh g_dump); sh keys.sh "$5 $6 800\n"; sleep 2; B=$(sh dumpnow.sh g_dump)
echo "vblank $3 $5 $6: $(py -3.13 posat.py $4 $A $B) [$(powershell -c '(Get-Process rpcs3).MainWindowTitle' | cut -d'|' -f1)]"
