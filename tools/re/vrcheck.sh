#!/bin/sh
# vrcheck.sh ID STATE OUT [WAIT=6] [PROBE=render=1] [KEYS] [VBLANK=90]: boot bin/savestates/ID/STATE on the OpenXR
# Simulator with VR on (temporary custom config: Vblank, VR Enabled, Frame Rate Unlimited, Null audio; the game's own
# config is restored after) and a temporary pad; send KEYS (an RPCS3_VR_KEYS script) once booted; after WAIT s capture
# the headset view with the head straight (OUT_y0) and turned 25 degrees (OUT_y25), and RPCS3's own image (OUT_rp).
# Env VIDEO_CFG = more lines under Video ('  Key: value\n'), EXTRA_CFG = more sections. PITCH=1 also captures pitched
# up 25 degrees (OUT_p25). GBOOT_ARGS=-Desktop: desktop stereo instead of the simulator (dev comparisons only). Leaves RPCS3 running (KEEP=1) or closes it and cleans up.
id=$1; st=$2; out=$3; wait=${4:-6}; probe=${5:-render=1}; keys=$6; vb=${7:-90}
cd "$(dirname "$0")"
C=/f/rpsc3/source/rpcs3/bin/config/custom_configs/config_$id.yml
had=0; [ -f "$C" ] && [ ! -f "$C.vrcheck.bak" ] && { had=1; cp "$C" "$C.vrcheck.bak"; }
[ -f "$C.vrcheck.bak" ] && had=1
printf "Video:\n  Vblank Rate: %s\n${VIDEO_CFG}  VR:\n    Enabled: true\n    Frame Rate: Unlimited\nAudio:\n  Renderer: \"Null\"\n${EXTRA_CFG}" "$vb" > "$C"
P=/f/rpsc3/source/rpcs3/bin/config/input_configs/$id; padhad=0; [ -d "$P" ] && padhad=1
[ $padhad = 0 ] && { mkdir -p "$P"; cp ../keyboard-pad-template.yml "$P/Default.yml"; }
D="$LOCALAPPDATA/OpenXR-Simulator"
pose() { printf '{"x": 0, "y": 0, "z": 0, "yaw": %s, "pitch": %s, "roll": 0}' "$1" "${2:-0}" > "$D/head_pose_command.json.tmp" && mv "$D/head_pose_command.json.tmp" "$D/head_pose_command.json"; }
pose 0
iso="F:/rpsc3/source/rpcs3/bin/savestates/$id/$st.SAVESTAT.zst"; [ -f "$st" ] && iso="$st"
RPCS3_VR_FRAMESTATS=1 timeout 300 powershell -File gboot.ps1 -Iso "$iso" -Probe "$probe" $GBOOT_ARGS | tail -1
# The game runs once it flips (the frame-stats hook logs each second of flips); loading overlays (PPU/SPU cache) do not flip.
L=/f/rpsc3/source/rpcs3/bin/log/RPCS3.log
for i in $(seq 1 240); do grep -aq "VR frame stats" $L && break; sleep 0.5; done
[ -n "$keys" ] && sh keys.sh "$keys"
# The simulator's preview window sets the capture size; it can come up squashed.
powershell -File simwin.ps1 >/dev/null 2>&1
sleep "$wait"
py -3.13 simshot.py "${out}_y0" 960 >/dev/null
SHOT_MOVE=1 py -3.13 shot.py "$id" "${out}_rp" 960 >/dev/null
pose 0.436; sleep 1; py -3.13 simshot.py "${out}_y25" 960 >/dev/null
if [ "${PITCH:-0}" = 1 ]; then pose 0 0.436; sleep 1; py -3.13 simshot.py "${out}_p25" 960 >/dev/null; fi
pose 0
grep -a "OpenXR: Headset\|First stereo frame\|VR profile loaded" /f/rpsc3/source/rpcs3/bin/log/RPCS3.log | cut -c1-160 | head -4
if [ "${KEEP:-0}" != 1 ]; then
  powershell -c "Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force; while (Get-Process rpcs3 -ErrorAction SilentlyContinue) { Start-Sleep -Milliseconds 200 }"; sleep 1
  if [ $had = 1 ]; then mv -f "$C.vrcheck.bak" "$C"; else rm -f "$C"; fi
  [ $padhad = 0 ] && rm -r "${P:?}"
fi
true
