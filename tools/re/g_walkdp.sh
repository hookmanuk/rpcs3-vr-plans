#!/bin/sh
# g_walkdp.sh ID STATE VBLANK ADDR KEY HOLD POKEFILE: like g_walkd.sh with a poke before walking
sh gsetup.sh "$1" "$3"; powershell -File gboot.ps1 -Iso "$2" >/dev/null; sleep 8; cp "$7" "$TEMP/rpcs3-vrprofile/POKE"; sleep 2
A=$(sh dumpnow.sh g_dump); sh keys.sh "$5 $6 800\n"; sleep 2; B=$(sh dumpnow.sh g_dump)
echo "vblank $3 $5 $6 poked: $(py -3.13 posat.py $4 $A $B) [$(powershell -c '(Get-Process rpcs3).MainWindowTitle' | cut -d'|' -f1)]"
