#!/bin/sh
# gt5_bootloop.sh N [STATE=gt5_rome_start] [EXTRA_KEY...]: boots STATE N times on the simulator with Matt's config
# (cfgtemp: VR on, Vblank 90, 400%, Null audio, extra keys; restored after), 38 s each; prints per boot whether the
# Vulkan device was lost. Kills rpcs3 between boots.
cd "$(dirname "$0")"
n=$1; st=${2:-gt5_rome_start}; shift 2 2>/dev/null
L=/f/rpsc3/source/rpcs3/bin/log/RPCS3.log
P=/f/rpsc3/source/rpcs3/bin/config/input_configs/BCUS98114
mkdir -p "$P"; cp ../keyboard-pad-template.yml "$P/Default.yml"
py -3.13 cfgtemp.py BCUS98114 set "Video/VR/Enabled=true" "Video/VR/Frame Rate=Unlimited" "Video/Vblank Rate=90" "Video/Resolution Scale=400" "Audio/Renderer=Null" "$@" >/dev/null
lost=0
for i in $(seq 1 $n); do
  RPCS3_VR_FRAMESTATS=1 timeout 60 powershell -File gboot.ps1 -Iso "F:/rpsc3/source/rpcs3/bin/savestates/BCUS98114/$st.SAVESTAT.zst" -Probe render=1 >/dev/null 2>&1
  sleep 38
  if grep -aq "Device lost" $L; then r=LOST; lost=$((lost+1)); else r=ok; fi
  echo "boot $i: $r ($(grep -a -c 'VR frame stats' $L) stats lines)"
  powershell -c "Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force; \$t=0; while ((Get-Process rpcs3 -ErrorAction SilentlyContinue | Where-Object { \$_.Threads.Count -gt 1 }) -and \$t -lt 150) { Start-Sleep -Milliseconds 200; \$t++ }"
  sleep 1
done
echo "lost $lost of $n"
py -3.13 cfgtemp.py BCUS98114 restore >/dev/null
rm -r "${P:?}"
