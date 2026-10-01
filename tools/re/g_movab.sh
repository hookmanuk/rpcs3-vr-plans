#!/bin/sh
# g_movab.sh ID STATE TAG VBLANK KEY HOLD: boot STATE at VBLANK, dump, hold KEY HOLD ms, dump -> keep/TAG.{0,1}
W="$TEMP/rpcs3-vrprofile"; mkdir -p "$W/keep"
sh gsetup.sh "$1" "$4"; powershell -File gboot.ps1 -Iso "$2" >/dev/null; sleep 10
D=$(sh dumpnow.sh g_dump); for e in bin idx txt; do mv -f "$D.$e" "$W/keep/$3.0.$e"; done
sh keys.sh "$5 $6 800\n"; sleep 2
D=$(sh dumpnow.sh g_dump); for e in bin idx txt; do mv -f "$D.$e" "$W/keep/$3.1.$e"; done
echo "$3 $(powershell -c '(Get-Process rpcs3).MainWindowTitle' | cut -d'|' -f1)"
