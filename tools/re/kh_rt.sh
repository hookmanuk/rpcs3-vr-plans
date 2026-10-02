#!/bin/sh
# kh_rt.sh GAME RATE TAG [nopatch|native]: real-time check for the Kingdom Hearts frame-step patches without a disc boot.
# Boots the game's savestate (made with the community 60 FPS patch) on the PPU interpreter at Vblank RATE (temporary
# custom config, removed after), applies the VR patch's code words with RPCS3_VR_POKE and sets the vblank-length word
# to 1.0 with pine (the profile's game_vblank_frames_f32 then keeps it at 60/RATE), holds the left stick forward and
# writes two memory dumps 2.5 s apart: dumps/<TAG>.0 and .1. Compare runs with posratio.py (1.0 = real time).
# "nopatch" skips the pokes (control: the community patch alone); "native": a savestate made with the VR patch (no
# pokes, the PPU recompiler as configured).
game=$1; rate=$2; tag=$3; mode=${4:-}
cd "$(dirname "$0")"
case $game in
  kh1) id=BLUS31212; state=vrtest_kh1_dive; word=0x20d102c
       pokes='3686c u32 0xc043102c' ;;
  kh2) id=BLUS31460; state=vrtest_kh2_twilight; word=0x887ca4
       pokes='7684c u32 0xc0447ca4
76858 u32 0xfc200e9c
7685c u32 0xfc200818
76860 u32 0xec2100b2
76864 u32 0x60000000
7686c u32 0x48000050' ;;
  *) echo "game: kh1 or kh2"; exit 1 ;;
esac
W="$TEMP/rpcs3-vrprofile"
C=/f/rpsc3/source/rpcs3/bin/config/custom_configs/config_$id.yml
P=/f/rpsc3/source/rpcs3/bin/config/input_configs/$id
[ -f "$C" ] && { echo "a custom config exists for $id: not touching it"; exit 1; }
padhad=0; [ -d "$P" ] && padhad=1
[ $padhad = 0 ] && { mkdir -p "$P"; cp ../keyboard-pad-template.yml "$P/Default.yml"; }
if [ "$mode" = native ]; then
  printf 'Video:\n  Vblank Rate: %s\n' "$rate" > "$C"
else
  printf 'Core:\n  PPU Decoder: Interpreter (static)\nVideo:\n  Vblank Rate: %s\n' "$rate" > "$C"
fi
mkdir -p dumps; rm -f dumps/$tag.*
RPCS3_VR_POKE="$W/POKE" RPCS3_VR_MEMDUMP="$W/MEMDUMP" powershell -File ../launch.ps1 -Game "F:/rpsc3/source/rpcs3/bin/savestates/$id/$state.SAVESTAT.zst" -NoHeadset -Probe render=0 | tail -1
sleep 4
if [ "$mode" != nopatch ] && [ "$mode" != native ]; then
  printf '%s' "$pokes" > "$W/POKE.tmp" && mv "$W/POKE.tmp" "$W/POKE"
  py -3.13 ../pine.py write $word f32 1.0 >/dev/null
fi
sleep 2
grep -a 'VR poke\|vblank length' /f/rpsc3/source/rpcs3/bin/log/RPCS3.log | tail -2 | cut -c40-160
sh keys.sh 'I 7000 200\n'
sleep 2
before=$(ls "$W"/MEMDUMP.*.bin 2>/dev/null | wc -l)
touch "$W/MEMDUMP"; until [ ! -f "$W/MEMDUMP" ]; do sleep 0.1; done
sleep 2.5
touch "$W/MEMDUMP"; until [ ! -f "$W/MEMDUMP" ]; do sleep 0.1; done
sleep 3
n=0; for f in $(ls -t "$W"/MEMDUMP.*.bin | head -2 | sort); do b=${f%.bin}; for x in bin idx txt; do mv "$b.$x" "dumps/$tag.$n.$x"; done; n=$((n + 1)); done
py -3.13 ../pine.py read $word f32 1
powershell -c "(Get-Process rpcs3).MainWindowTitle; Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force; while (Get-Process rpcs3 -ErrorAction SilentlyContinue) { Start-Sleep -Milliseconds 200 }"
rm -f "$C"; [ -f "$C" ] && echo "WARNING: temporary $C still present"
[ $padhad = 0 ] && rm -r "${P:?}"
ls dumps/$tag.* | wc -l
