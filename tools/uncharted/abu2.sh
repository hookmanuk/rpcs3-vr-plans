#!/usr/bin/env bash
# abu2.sh ROUNDS "A ENV" "B ENV" [VR]: alternating benchu2.sh runs of one build (A first each round): TAG a1, b1, a2,
# b2 ... into /h/uc_tests/ab.txt (one summary line each). Waits for the game to be gone between runs.
T=$(cd "$(dirname "$0")" && pwd); OUT=/h/uc_tests/ab.txt; : > $OUT
gone() { for i in $(seq 1 30); do tasklist | grep -qi bb-probe.exe || return 0; sleep 1; done; taskkill //F //IM bb-probe.exe >/dev/null 2>&1; sleep 3; }
for r in $(seq 1 ${1:-2}); do
    for side in a b; do
        gone
        [ $side = a ] && E=$2 || E=$3
        echo "$(date +%T) start $side$r ($E)" >> /h/uc_tests/ab_progress.txt
        bash "$T/benchu2.sh" "$side$r" "${4:-0}" "$E" > /dev/null 2>&1
        cat "/h/uc_tests/bench_$side$r.txt" >> $OUT 2>/dev/null || echo "$side$r: failed" >> $OUT
    done
done
echo done >> $OUT
