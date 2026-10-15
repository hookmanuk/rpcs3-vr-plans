#!/bin/sh
# nsys_run.sh OUT ID STATE [SCALE=300] [DELAY=30] [DUR=8]: boots a savestate on the simulator with the usual test
# config (VR on, Unlimited, Vblank 600, Null audio, DLSS off) under Nsight Systems: Vulkan API + GPU workloads + OpenXR,
# and (elevated, through nsys_admin.ps1) CPU IP sampling + context switches. Report: plans/evidence/nsys/OUT.nsys-rep (+ .sqlite; NSYS_OUT overrides the folder).
# Env TRACE adds e.g. ",vulkan-annotations"; VB the vblank rate (600); GPUMET=<Hz> adds the GPU hardware metrics
# (GR active, SM active, vertex / pixel warps in flight, DRAM bandwidth; elevated only).
S=${NSYS_OUT:-/f/rpsc3/source/plans/evidence/nsys}; mkdir -p "$S"
N="/c/Program Files/NVIDIA Corporation/Nsight Systems 2026.5.1/target-windows-x64/nsys.exe"
out=$1; id=$2; st=$3; sc=${4:-300}; delay=${5:-30}; dur=${6:-8}
cd /f/rpsc3/source/plans/tools/re
powershell -c "Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force" ; sleep 2
py -3.13 cfgtemp.py $id set "Video/VR/Enabled=true" "Video/VR/Frame Rate=Unlimited" "Video/Resolution Scale=$sc" "Audio/Renderer=Null" "Video/Vblank Rate=${VB:-600}" "Video/VR/DLSS (experimental)=Off" "Video/VR/DLSS Frame Generation (experimental)=false" >/dev/null
py -3.13 simpose.py 0 0 0 >/dev/null
W="$LOCALAPPDATA/Temp/rpcs3-vrprofile"; mkdir -p "$W"; printf 'render=1' > "$W/probe.txt"
export XR_RUNTIME_JSON='F:\rpsc3\source\OpenXR-Simulator\bin\openxr_simulator.json'
export RPCS3_VR_PROBE_FILE="$(cygpath -w "$W/probe.txt")" RPCS3_VR_FRAMESTATS=1 RPCS3_VR_PROFILE_RELOAD=1
if net session >/dev/null 2>&1; then CPU="--sample=process-tree --cpuctxsw=process-tree"; echo "elevated: CPU sampling on"; else CPU="--sample=none --cpuctxsw=none"; fi
cd /f/rpsc3/source/rpcs3/bin
"$N" profile -o "$(cygpath -w "$S/$out")" -f true --trace=vulkan,openxr${TRACE} --vulkan-gpu-workload=individual $CPU ${GPUMET:+--gpu-metrics-devices=all --gpu-metrics-frequency=$GPUMET} \
  --delay=$delay --duration=$dur --kill=true --wait=primary --export=sqlite ./rpcs3.exe "F:/rpsc3/source/rpcs3/bin/savestates/$id/$st.SAVESTAT.zst" 2>&1 | grep -v "^$" | tail -8
sleep 2; powershell -c "Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force"; sleep 1
cd /f/rpsc3/source/plans/tools/re; py -3.13 cfgtemp.py $id restore >/dev/null
grep -a "VR frame stats" /f/rpsc3/source/rpcs3/bin/log/RPCS3.log | tail -3 | grep -o "avg [0-9.]* FPS.*late [0-9.]*%, RSX thread [0-9.]* ms/frame" | sed 's/, 1% low.*median/ median/'
echo done
