#!/bin/sh
# up.sh ID STATE [PROBE] [SCALE=300]: fresh simulator boot of a savestate (or ISO path if STATE contains '/'), VR on,
# Null audio via cfgtemp (down.sh restores), keyboard pad if none. Waits for VR frame stats. Env passes through.
R=/f/rpsc3/source/plans/tools/re; cd $R
id=$1; st=$2; probe=${3:-render=1}; sc=${4:-300}
L=/f/rpsc3/source/rpcs3/bin/log/RPCS3.log
P=/f/rpsc3/source/rpcs3/bin/config/input_configs/$id
[ -d "$P" ] || { mkdir -p "$P"; cp ../keyboard-pad-template.yml "$P/Default.yml"; touch "$P/.tmp_pad"; }
py -3.13 cfgtemp.py $id set "Video/VR/Enabled=true" "Video/VR/Frame Rate=Unlimited" "Video/Resolution Scale=$sc" "Audio/Renderer=Null" >/dev/null; [ -n "$CFGX" ] && py -3.13 cfgtemp.py $id set "$CFGX" >/dev/null; [ -n "$CFGX2" ] && py -3.13 cfgtemp.py $id set "$CFGX2" >/dev/null
py -3.13 cfgtemp.py global set "Audio/Renderer=Null" >/dev/null; py -3.13 simpose.py 0 0 0 >/dev/null
case "$st" in */*) iso="$st";; *) iso="F:/rpsc3/source/rpcs3/bin/savestates/$id/$st.SAVESTAT.zst";; esac
RPCS3_VR_FRAMESTATS=1 timeout 60 powershell -File gboot.ps1 -Iso "$iso" -Probe "$probe" >/dev/null 2>&1
sleep 8; powershell -File simwin.ps1 >/dev/null 2>&1
for i in $(seq 1 240); do grep -aq "VR frame stats" $L && { echo up; exit 0; }; sleep 0.5; done
echo "no frame stats"
