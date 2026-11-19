#!/usr/bin/env bash
# crashhunt.sh RUNS "EXTRA ENV": U2 bomb route (bombsess.sh, SteamVR, Matt's Borneo save copy) RUNS times with a short
# hold after the cutscene, each run's game log kept as /h/uc_tests/crashhunt_N.log; stops at the first run whose log
# shows a lost device (the dig-wide-01 GPU fault: a shader reading an unmapped address, ~1 run in 6, 2026-11-18).
T=$(cd "$(dirname "$0")" && pwd)
for n in $(seq 1 ${1:-6}); do
    tasklist | grep -qi bb-probe.exe && { echo "bb-probe already running: stop"; exit 1; }
    for d in SAVEDATA020 SAVEDATA020.sce_sys SAVEDATA02P SAVEDATA02P.sce_sys; do  # the same checkpoint every run
        rm -rf "/h/uc_tests/mc_copy/savedata/1/CUSA02343/${d}"; cp -r "/h/uc_tests/crashhunt_save/${d}" "/h/uc_tests/mc_copy/savedata/1/CUSA02343/${d}"
    done
    bash "$T/bombsess.sh" "BB_GPU_CHECKPOINTS=1 BB_GPU_ADDRESS_REPORT=1 $2" 60
    cp /h/uncharted_pc/out/try/u2/run.log /h/uc_tests/crashhunt${TAG}_$n.log
    if grep -qi "GPU crash\|device.lost\|devicelost\|VK_ERROR_DEVICE" /h/uc_tests/crashhunt${TAG}_$n.log; then
        echo "run $n: device lost"; exit 0
    fi
    echo "run $n: no crash ($(grep -c "VR: game" /h/uc_tests/crashhunt${TAG}_$n.log) reports)"
done
echo "no crash in ${1:-6} runs"
