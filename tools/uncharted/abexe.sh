#!/usr/bin/env bash
# abexe.sh TAG EXE_A EXE_B: A/B two builds of bb-probe.exe on the same benchmarks, alternating (A, B, A, B...). Each exe
# is copied over out/bb-probe.exe before its run (the bench scripts find and stop the game by that name); the build
# that was there is put back at the end. Runs (one pair each, 20 s measured): U2 after Borneo's bomb cutscene in VR (benchu2.sh),
# U3 bar fight in VR (benchu3.sh). Results: /h/uc_tests/abexe_TAG.txt, one line per run with
# whether it crashed (device lost); each run's game log as /h/uc_tests/abexe_TAG_<run>.log.
TAG=$1; A=$2; B=$3; T=$(cd "$(dirname "$0")" && pwd); U=/h/uc_tests; OUT=/h/uncharted_pc/out
[ -f "$A" ] && [ -f "$B" ] || { echo "usage: abexe.sh TAG EXE_A EXE_B"; exit 1; }
cp "$OUT/bb-probe.exe" "$U/abexe_${TAG}_saved.exe"
R="$U/abexe_${TAG}.txt"; : > "$R"
run() { # name exe bench...
    local name=$1 exe=$2; shift 2
    tasklist | grep -qi bb-probe.exe && { echo "$name: bb-probe already running, skipped" >> "$R"; return; }
    cp "$exe" "$OUT/bb-probe.exe"
    "$@" > "$U/abexe_${TAG}_${name}.out" 2>&1
    local game=u2; case "$name" in u3*) game=u3;; esac
    cp "$OUT/try/$game/run.log" "$U/abexe_${TAG}_${name}.log"
    local c=no; grep -q "GPU crash" "$U/abexe_${TAG}_${name}.log" && c=yes
    echo "$name crash=$c $(tail -1 "$U/abexe_${TAG}_${name}.out")" >> "$R"
}
run u2vr_a1 "$A" env MEAS=20 bash "$T/benchu2.sh" "abexe_${TAG}_u2vr_a1" 1
run u2vr_b1 "$B" env MEAS=20 bash "$T/benchu2.sh" "abexe_${TAG}_u2vr_b1" 1
run u3vr_a1 "$A" bash "$T/benchu3.sh" "abexe_${TAG}_u3vr_a1" 20
run u3vr_b1 "$B" bash "$T/benchu3.sh" "abexe_${TAG}_u3vr_b1" 20
cp "$U/abexe_${TAG}_saved.exe" "$OUT/bb-probe.exe" && rm -f "$U/abexe_${TAG}_saved.exe"
echo done >> "$R"
