#!/bin/sh
# eyeshape_bench.sh [FILTER]: headset-shaped eyes A/B over tools/re/vrtest_states.txt. Each state runs twice at 120 Hz
# (or its rates= tag), RPCS3_VR_EYE_SHAPE=0 then 1: avg FPS, 1% low, late frames, GPU utilisation and power (nvidia-smi over
# the measured windows) and the profiler's GPU ms/frame (= the frame interval unless GPU-bound) per mode, and the simulator captures. Results in plans/evidence/eyeshape/<date-time>/.
cd "$(dirname "$0")"
D=/f/rpsc3/source/plans/evidence/eyeshape/$(date +%Y-%m-%d-%H%M)${TAG:+-$TAG}; mkdir -p "$D"
L=/f/rpsc3/source/rpcs3/bin/log/RPCS3.log
echo "# build $(git -C /f/rpsc3/source/rpcs3 log --oneline -1 | cut -c1-60); simulator $(grep -o '"headset_profile": "[a-z0-9]*"' "$LOCALAPPDATA/OpenXR-Simulator/settings.json")" | tee "$D/results.txt"
echo "# state | mode | rate | avg FPS 1%-low late% | GPU use and power over the measured windows | profiler GPU ms/frame | eye image" | tee -a "$D/results.txt"
grep -v '^#' vrtest_states.txt | grep -- "${1:-.}" | while read id st vpf walk settle rest; do
  [ -z "$id" ] && continue
  tag=$(echo "$rest" | grep -o "rates=[0-9,]*" | cut -d= -f2 | tr , ' ' | awk '{print $NF}')
  rate=${tag:-120}
  for m in 0 1; do
    G=/tmp/eyeshape_gpu.csv
    O=/tmp/eyeshape_vr1pct.out
    run() {
      padhad=0; [ -d "/f/rpsc3/source/rpcs3/bin/config/input_configs/$id" ] && padhad=1
      : > $L  # the previous run's log must not trip the watchdog
      nvidia-smi --query-gpu=utilization.gpu,power.draw --format=csv,noheader,nounits -lms 500 > $G &
      NP=$!
      RPCS3_VR_EYE_SHAPE=$m RPCS3_VR_GPUPROF=1 SETTLE=$settle sh vr1pct.sh "$id" "$st" $((rate * vpf)) "$walk" > $O 2>&1 &
      VP=$!
      # Watchdog: a fatal error, a lost device or a frozen emulation in the log, frame stats that stop for 45 s, or a run
      # over 200 s ends the run as CRASH/HANG (log kept), instead of the bench waiting on it.
      fail=""; t=0; last=""; still=0
      while kill -0 $VP 2>/dev/null; do
        sleep 5; t=$((t + 5))
        if grep -aq "·F \|Device lost\|Emulation has been frozen" $L 2>/dev/null; then fail="CRASH: $(grep -a '·F \|Device lost' $L | head -1 | cut -c1-140)"; fi
        cur=$(grep -a "VR frame stats" $L 2>/dev/null | tail -1)
        if [ -n "$cur" ] && [ "$cur" = "$last" ]; then still=$((still + 5)); else still=0; fi
        last=$cur
        [ $still -ge 45 ] && fail="HANG: no frame stats for 45 s"
        [ $t -ge 200 ] && fail="HANG: run over 200 s"
        if [ -n "$fail" ]; then
          cp $L "$D/${st}_m${m}_fail.log"
          powershell -c "Get-CimInstance Win32_Process | Where-Object { (\$_.CommandLine -match 'vr1pct|keys.sh|simshot|shot.py') -and (\$_.CommandLine -notmatch 'Get-CimInstance') } | ForEach-Object { Stop-Process -Id \$_.ProcessId -Force -ErrorAction SilentlyContinue }; Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force" >/dev/null 2>&1
          C=/f/rpsc3/source/rpcs3/bin/config
          [ -f "$C/custom_configs/config_$id.yml.vr1pct.bak" ] && mv -f "$C/custom_configs/config_$id.yml.vr1pct.bak" "$C/custom_configs/config_$id.yml"
          [ $padhad = 0 ] && [ -d "$C/input_configs/$id" ] && rm -r "$C/input_configs/${id:?}"
          echo "!! $st mode $m: $fail" | tee -a "$D/results.txt" >> /tmp/eyeshape_alerts.txt
          break
        fi
      done
      wait $VP 2>/dev/null
      kill $NP 2>/dev/null; wait $NP 2>/dev/null
      out=$(cat $O)
      [ -n "$fail" ] && out="no frame stats ($fail)"
    }
    run
    # No stats at all = the game stalled before measuring: one retry.
    echo "$out" | grep -q "no frame stats" && run
    # The measured windows end ~6 s before vr1pct does (screenshots): GPU use over the 24 s before that.
    util=$(head -n -12 $G | tail -n 48 | tr -d ' ' | awk -F, '{u+=$1; p+=$2; n++} END{if(n) printf "GPU %.0f%% %.0f W", u/n, p/n; else printf "GPU -"}')
    sum=$(echo "$out" | grep "=> median" | sed -E 's/.*avg ([0-9.]+) FPS, 1% low ([0-9.]+), late frames ([0-9.]+)%.*/\1 \2 \3/')
    gpu=$(grep -a "GPU profile:" $L | sed -E 's/.*GPU profile: ([0-9.]+) ms\/frame.*/\1/' | awk '$1 < 200' | tail -n +3 | sort -n | awk '{a[NR]=$1} END{if(NR) printf "%.2f", a[int((NR+1)/2)]; else printf "-"}')
    size=$(grep -a "Projection layer shows\|eye image" $L | head -1 | grep -o "[0-9]*x[0-9]* eye image" | head -1)
    [ -z "$size" ] && size=$(grep -a "Headset eye shape" $L | head -1 | grep -o "scale [0-9.]*")
    echo "$st | $([ $m = 1 ] && echo shaped || echo 16:9) | $rate | ${sum:-no stats} | $util | profiler $gpu ms | $size" | tee -a "$D/results.txt"
    [ -f "sim_${st}_$((rate * vpf)).png" ] && cp "sim_${st}_$((rate * vpf)).png" "$D/${st}_m$m.png"
  done
done
echo "done $D"
