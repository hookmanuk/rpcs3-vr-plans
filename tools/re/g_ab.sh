#!/bin/sh
# g_ab.sh ID STATE TAG VBLANK: boot STATE at VBLANK, 3 dumps 4 s apart into keep/TAG.{0,1,2}
W="$TEMP/rpcs3-vrprofile"; mkdir -p "$W/keep"
sh gsetup.sh "$1" "$4"; powershell -File gboot.ps1 -Iso "$2" >/dev/null; sleep 10
echo "$3: $(powershell -c '(Get-Process rpcs3).MainWindowTitle' | cut -d'|' -f1)"
for n in 0 1 2; do D=$(sh dumpnow.sh g_dump); for e in bin idx txt; do mv -f "$D.$e" "$W/keep/$3.$n.$e"; done; sleep 3; done
