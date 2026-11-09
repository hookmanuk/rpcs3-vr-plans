#!/usr/bin/env bash
# contractab.sh: BB_SHADER_CONTRACT A/B at Matt's U2 cliff save (eye 3584, simulator): each side its own fresh GPU cache
# (H:/uc_tests/gpu_cN), run twice; the GPU's ms a frame (BB_GPU_PROFILE) and the VR frame-rate line of each run.
T=$(cd "$(dirname "$0")" && pwd); L=/h/uncharted_pc/out/try/u2/run.log; O=/h/uc_tests/contractab.txt
for c in 0 1; do rm -rf /h/uc_tests/gpu_c$c; mkdir -p /h/uc_tests/gpu_c$c; done
for run in 1 2; do for c in 0 1; do
    tasklist | grep -qi bb-probe.exe && { echo "bb-probe running: stop"; exit 1; }
    GAME=u2 HOLD=35 SESSION_ENV="BB_GPU_PROFILE=1 BB_SHADER_CONTRACT=$c BB_GPU_USER_DIR=H:\uc_tests\gpu_c$c" \
      ROUTE="wait 45; press cross; wait 4; press cross; wait 55" timeout 200 bash $T/sess.sh > /h/uc_tests/contractab_sess.log 2>&1
    sleep 3
    { echo "== contract $c run $run"; grep -a "GPU profile: [0-9]" $L | tail -2 | sed 's/^/   /'
      grep -a "dispatch cs 0000000043b8ee5e" $L | tail -1 | sed 's/^/   /'; grep -a "VR: game" $L | tail -2 | sed 's/^/   /'; } | tee -a $O
done; done
