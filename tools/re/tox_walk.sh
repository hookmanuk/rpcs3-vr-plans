#!/bin/sh
# tox_walk.sh VBLANK: fresh boot to the field, hold forward 1.5 s, print Jude's displacement (0xe76d40)
printf "Video:\n  Vblank Rate: $1\n" > /f/rpsc3/source/rpcs3/bin/config/custom_configs/config_BLUS31006.yml
powershell -File tox_boot.ps1 >/dev/null; sh keys.sh 'X 200 2000\n'; sleep 4
A=$(sh dumpnow.sh tox_dump); sh keys.sh 'I 1500 500\n'; sleep 3; B=$(sh dumpnow.sh tox_dump)
echo "vblank $1: $(py -3.13 posat.py 0xe76d40 $A $B)"
