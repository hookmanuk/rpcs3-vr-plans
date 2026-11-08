#!/bin/sh
# stallrun.sh LABEL [SECONDS=40] [NAME=VALUE...]: SteamVR, in-car on the race grid: the D3D12 calls that stalled (DrawInstanced /
# SetPipelineState over 1 ms, with the cycles the thread ran and its processor), the whole machine's CPU load meanwhile, the
# frame's stages and the game-side 1% low. Saves out/stallrun_LABEL.log.
T=/f/rpsc3/source/plans/tools/pgr4; P=$T/pg.sh; L=/h/PGR4-ReGPU/thirdparty/ReGPU/out/live.log
LABEL=$1; S=${2:-40}; [ $# -gt 0 ] && shift; [ $# -gt 0 ] && shift
tasklist | grep -qi pgr4.exe && { echo "pgr4 is running: stopping"; exit 1; }
sh $T/steamrace.sh 5120x5120 REGPU_PERF=1 REGPU_VR_TRACE=1 "$@" 2>&1 | tail -1 | cut -c1-60
$P press LB >/dev/null; sleep 2; $P press LB >/dev/null; sleep 4
T0=$(grep -a -o -E "^\[ *[0-9.]+\]" $L | tail -1 | tr -d '[] ')
typeperf "\Processor Information(_Total)\% Processor Utility" "\Processor Information(_Total)\% Processor Performance" "\System\Context Switches/sec" -si 5 -sc $((S / 5)) 2>/dev/null | tail -n +3 | head -$((S / 5)) | cut -d, -f2- | tr -d '"' > /h/PGR4-ReGPU/out/stallrun_cpu.txt &
TP=$!
timeout $S nvidia-smi --query-gpu=temperature.gpu,clocks.sm,power.draw,utilization.gpu,clocks_throttle_reasons.active --format=csv,noheader -l 5 > /h/PGR4-ReGPU/out/stallrun_gpu.txt 2>&1 &
NV=$!
py -3 -I $T/vrperf.py $S "$LABEL grid" | sed -E 's/.*grid: //; s/, p50 [0-9.]+ ms//; s/, [0-9]+ frames.*//' | cut -c1-90
wait $TP
kill $NV 2>/dev/null
echo "   CPU: utility %, performance % (of 4.7 GHz), context switches/s per 5 s:"; sed 's/^/     /' /h/PGR4-ReGPU/out/stallrun_cpu.txt
echo "   GPU: temp C, SM MHz, W, util %, throttle reasons per 5 s:"; head -$((S / 5 + 1)) /h/PGR4-ReGPU/out/stallrun_gpu.txt | sed 's/^/     /'
echo "   pgr4 threads by CPU seconds (id: s):"; powershell -NoProfile -Command "Get-Process pgr4 | Select-Object -ExpandProperty Threads | Sort-Object TotalProcessorTime -Descending | Select-Object -First 10 | ForEach-Object { '{0}: {1:N1}' -f \$_.Id, \$_.TotalProcessorTime.TotalSeconds }" | tr '\n' ' ' | sed 's/^/     /'; echo
py -3 $T/stagesum.py $L $S | grep -E "late|vr stages" | tail -4 | cut -c1-200
echo "   stalled calls (ms, M cycles, cpu):"
awk -v T0=$T0 '{ if (match($0,/^\[ *([0-9.]+)\]/,m) && m[1]+0 > T0) print }' $L | grep -a -E "took [0-9.]+ ms \(vs" | sed -E 's/.*(DrawInstanced|SetPipelineState) took ([0-9.]+) ms \(vs [0-9a-f]+ ps [0-9a-f]+\), ran ([0-9.]+) M cycles, cpu ([0-9]+) -> ([0-9]+)/\1 \2 ms \3 M \4->\5/' | sort | uniq -c | sort -rn | head -20 | sed 's/^/     /'
$P stop >/dev/null 2>&1; sleep 2
cp $L /h/PGR4-ReGPU/out/stallrun_$LABEL.log
