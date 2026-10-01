#!/bin/sh
# g_walkp.sh ID STATE VBLANK ADDR POKEFILE [HOLD]: like g_walk.sh with a poke file applied before walking
sh gsetup.sh "$1" "$3"; powershell -File gboot.ps1 -Iso "$2" >/dev/null; sleep 8; cp "$5" "$TEMP/rpcs3-vrprofile/POKE"; sleep 3
H=${6:-600}; A=$(sh dumpnow.sh g_dump); sh keys.sh "I $H 800\n"; sleep 2; B=$(sh dumpnow.sh g_dump)
echo "vblank $3 poked: $(py -3.13 posat.py $4 $A $B)"
