#!/usr/bin/env bash
# crashab.sh TAG RUNS "ENV A" "ENV B": the U2 bomb benchmark (benchu2.sh, VR on the simulator, run.py's U2 settings) RUNS
# times per arm, A and B alternating; each run's game log kept as /h/uc_tests/cab_TAG_<arm><n>.log. One line per run
# in /h/uc_tests/cab_TAG.txt: arm, crashed or not (the dig-wide GPU fault), the bench line. Ends with the crash count
# per arm.
TAG=$1; RUNS=${2:-5}; A=$3; B=$4; T=$(cd "$(dirname "$0")" && pwd); U=/h/uc_tests
: > "$U/cab_${TAG}.txt"
for n in $(seq 1 "$RUNS"); do
    for arm in a b; do
        E="$A"; [ $arm = b ] && E="$B"
        bash "$T/benchu2.sh" "cab_${TAG}_${arm}${n}" 1 "$E" > "$U/cab_${TAG}_${arm}${n}.out" 2>&1
        cp /h/uncharted_pc/out/try/u2/run.log "$U/cab_${TAG}_${arm}${n}.log"
        c=no; grep -q "GPU crash" "$U/cab_${TAG}_${arm}${n}.log" && c=yes
        echo "$arm$n crash=$c $(tail -1 "$U/cab_${TAG}_${arm}${n}.out")" >> "$U/cab_${TAG}.txt"
    done
done
for arm in a b; do echo "arm $arm: $(grep -c "^$arm[0-9]* crash=yes" "$U/cab_${TAG}.txt") crashes in $RUNS runs"; done >> "$U/cab_${TAG}.txt"
