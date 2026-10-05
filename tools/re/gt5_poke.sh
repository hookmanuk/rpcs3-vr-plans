#!/bin/sh
# gt5_poke.sh OUT ADDR VALUE [STATE=gt5_indy_prerace] [SCALE=400]: boots STATE on the OpenXR Simulator with Matt's config
# (cfgtemp, VR on, Vblank 90, Frame Rate Unlimited; restored after), waits 6 s, writes the u32 VALUE at ADDR over PINE,
# keeps 10 s more. OUT.txt: frame stats per second; shots OUT_before.png / OUT_after.png.
cd "$(dirname "$0")"
out=$1; addr=$2; val=$3; st=${4:-gt5_indy_prerace}; sc=${5:-400}
L=/f/rpsc3/source/rpcs3/bin/log/RPCS3.log
P=/f/rpsc3/source/rpcs3/bin/config/input_configs/BCUS98114
padhad=0; [ -d "$P" ] && padhad=1
[ $padhad = 0 ] && { mkdir -p "$P"; cp ../keyboard-pad-template.yml "$P/Default.yml"; }
py -3.13 cfgtemp.py BCUS98114 set "Video/VR/Enabled=true" "Video/VR/Frame Rate=Unlimited" "Video/Vblank Rate=90" "Video/Resolution Scale=$sc" "Audio/Renderer=\"Null\"" >/dev/null
RPCS3_VR_FRAMESTATS=1 timeout 300 powershell -File gboot.ps1 -Iso "F:/rpsc3/source/rpcs3/bin/savestates/BCUS98114/$st.SAVESTAT.zst" -Probe render=1 >/dev/null 2>&1
sleep 10
for i in $(seq 1 240); do grep -aq "VR frame stats" $L && break; sleep 0.5; done
sleep 6
py -3.13 simshot.py "${out}_before" 640 >/dev/null 2>&1
n0=$(grep -a -c "VR frame stats" $L)
py -3.13 -c "import sys,time; sys.path.insert(0,'..'); from pine import Pine; p=Pine(); print('before', p.read($addr)); [ (p.write($addr,'u32',$val), time.sleep(0.05)) for _ in range(${REPEAT:-1}) ]; time.sleep(0.5); print('after', p.read($addr))"
sleep 5; py -3.13 simshot.py "${out}_after" 640 >/dev/null 2>&1; sleep 5
grep -a "VR frame stats" $L | sed 's/.*stats: //' | cut -c1-150 > "$out.txt"; echo "poke at line $n0" >> "$out.txt"
powershell -c "Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force; while (Get-Process rpcs3 -ErrorAction SilentlyContinue) { Start-Sleep -Milliseconds 200 }"
sleep 1
py -3.13 cfgtemp.py BCUS98114 restore >/dev/null
[ $padhad = 0 ] && rm -r "${P:?}"
true
