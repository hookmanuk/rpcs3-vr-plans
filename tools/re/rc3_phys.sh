#!/bin/sh
# rc3_phys.sh VBLANK TAG: boot the R&C 3 savestate (Veldin) with Ratchet's position (0xd05e60, z up) peeked each
# frame; run forward then back; speed timeline (speedline.py). Uses bin/vr_profiles/BCUS98282.rc3.ppu.json if present.
W="$TEMP/rpcs3-vrprofile"; S=/f/rpsc3/source/rpcs3/bin/savestates/BCUS98282/rc3_veldin.SAVESTAT.zst
printf "Video:\n  Vblank Rate: $1\n" > /f/rpsc3/source/rpcs3/bin/config/custom_configs/config_BCUS98282.yml
G_PEEK="d05e60 d05e64 d05e68" powershell -File gboot.ps1 -Iso "$S" >/dev/null; sleep 9
sh keys.sh 'I 1500 1000\nK 1500 1000\n'; sleep 6
cp /f/rpsc3/source/rpcs3/bin/log/RPCS3.log "$TEMP/peek_$2.txt"
echo "$2: $(py -3.13 speedline.py "$TEMP/peek_$2.txt" d05e60 d05e64 | tr ' ' '\n' | grep -v '/h' | awk -F: '$2>1{print $2}' | sort -n | awk '{a[NR]=$1} END{print "n="NR, "p50="a[int(NR/2)+1], "p90="a[int(NR*0.9)]}')"
