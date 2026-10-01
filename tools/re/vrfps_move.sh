#!/bin/sh
# vrfps_move.sh ID STATE VBLANK: stereo FPS from a savestate while the player walks back and forth (keeps idle cameras
# from kicking in); keyboard pad from gsetup.sh. Prints min/avg over 8 s; screenshots before/after.
C=/f/rpsc3/source/rpcs3/bin/config/custom_configs/config_$1.yml
printf "Video:\n  Vblank Rate: $3\n" > "$C"
P=/f/rpsc3/source/rpcs3/bin/config/input_configs/$1; mkdir -p $P; cp /f/rpsc3/source/plans/tools/keyboard-pad-template.yml $P/Default.yml
powershell -File gboot.ps1 -Iso "F:/rpsc3/source/rpcs3/bin/savestates/$1/$2.SAVESTAT.zst" -Probe 'render=1' >/dev/null
sleep 4; sh keys.sh 'I 1500 50
K 1500 50
I 1500 50
K 1500 50
I 1500 50
K 1500 50
I 1500 50
'; sleep 1
vals=$(powershell -File fps.ps1 -N 7 | grep -o "[0-9][0-9.]*")
py -3.13 shot.py $1 mv_$2_$3 480 >/dev/null
echo "$1 $2 vblank $3 moving: $(echo $vals | tr ' ' '\n' | awk '{s+=$1; if(min==""||$1<min)min=$1} END{printf "min %.1f avg %.1f", min, s/NR}') [$(echo $vals)]"
rm -f "$C"; rm -rf "$P"
