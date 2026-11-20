#!/usr/bin/env bash
# benchu2.sh TAG [VR] ["EXTRA ENV"]: the U2 bomb-cutscene benchmark (Borneo, Matt's checkpoint, the heaviest frame known:
# ~1330 one-group skinning dispatches a frame after the cutscene, 2026-11-19). Restores the checkpoint from
# /h/uc_tests/bomb_save into mc_copy, runs the route (Continue, view nudged right, walk with jumps to Sully: the
# cutscene), waits it out, then measures MEAS seconds (default 30) standing: per-frame times (BB_FLIP_LOG), the draw pipe's stage B (the
# recording thread) busy share and draws/s, and stops the game. VR=0 (default) flat, 1 the OpenXR simulator at 90 Hz.
# Output: /h/uc_tests/bench_TAG.txt (one summary line) and bench_TAG_flip.txt. Needs a build with BB_FLIP_LOG.
TAG=$1; VR=${2:-0}; EXTRA=$3; T=$(cd "$(dirname "$0")" && pwd); U=/h/uc_tests; D=/h/uncharted_pc/out/try/u2
tasklist | grep -qi bb-probe.exe && { echo "bb-probe already running: stop"; exit 1; }
for d in SAVEDATA020 SAVEDATA020.sce_sys SAVEDATA02P SAVEDATA02P.sce_sys; do
    [ -d "$U/bomb_save/$d" ] || { echo "no backup $d"; exit 1; }
    rm -rf "$U/mc_copy/savedata/1/CUSA02343/$d"; cp -r "$U/bomb_save/$d" "$U/mc_copy/savedata/1/CUSA02343/$d"
done
rm -f "$TEMP/fliplog.txt"; touch "$U/bench.mark"
R="wait 70; press cross; wait 5; press cross; wait 55; press rx=200 0.3; wait 1; shot f0; hold ly=0"
for i in 1 2 3 4; do R="$R; wait 2; hold ly=0 cross; wait 0.15; hold ly=0; wait 1.85"; done
R="$R; release; wait 2; shot f1; wait 45; shot f2; wait 600"
# Flat: the job workers sleep as in VR (BB_JOB_SLEEP=1). Spinning (the flat default on more than 12 threads) put nine
# threads at 71-95% of a core and the same build measured 9 ms or 12 ms frames run to run (2026-11-19).
VRENV="BB_VR=0 BB_JOB_SLEEP=1"; [ "$VR" = 1 ] && VRENV=""
# run.py's U2 settings (the launcher's Play goes through run.py; sess.sh / drive.py do not): GPU memory kept accurate,
# small results read back, the raycaster copies landing in guest memory on the landing thread.
RUNPY="BB_GPU_MERGE=0 BB_TINY_READBACK=1 BB_READBACK_SMALL_BUFFERS=1 BB_SCALAR_COPY64_SYNC=2 BB_SCALAR_COPY64_DEFER=1"
[ "$NORUNPY" = 1 ] && RUNPY=""  # NORUNPY=1: without them (the sessions before 2026-11-19 evening)
(cd "$T" && GAME=u2 UCUSER=mc_copy SESSION_ENV="BB_GPU_USER_DIR=H:\\uc_tests\\mc_copy BB_FRAME_STATS=1 BB_FLIP_LOG=1 $RUNPY $VRENV $EXTRA" \
    ROUTE="$R" HOLD=1 timeout 900 bash sess.sh > "$U/bench_${TAG}_sess.log" 2>&1 &)
for i in $(seq 1 120); do [ "$D/f2.png" -nt "$U/bench.mark" ] && break; sleep 3; done
[ "$D/f2.png" -nt "$U/bench.mark" ] || { echo "never reached f2"; taskkill //F //IM bb-probe.exe >/dev/null 2>&1; exit 1; }
cp "$D/f2.png" "$U/bench_${TAG}_f2.png"
sleep 8; n0=$(grep -c "^Draw pipe" $D/run.log); sleep ${MEAS:-30}
cp "$TEMP/fliplog.txt" "$U/bench_${TAG}_flip.txt"
pipe=$(grep "^Draw pipe" $D/run.log | tail -n +$((n0 + 1)) | awk '{d += $3; b += $(NF)+0; n++} END {if (n) printf "%.0f %.1f", d/n, b/n}')
vrl=$(grep "^VR: game" $D/run.log | tail -3 | awk '{g += $3; n++} END {if (n) printf "%.1f", g/n}')
taskkill //F //IM bb-probe.exe >/dev/null 2>&1; sleep 2; : > "$D/pad.txt"
# drive.py sleeps out its last wait: stop it too (else it outlives the run).
powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='python.exe'\" | Where-Object { \$_.CommandLine -like '*tools/drive.py u2*' } | ForEach-Object { Stop-Process -Id \$_.ProcessId -Force }" >/dev/null 2>&1
python - "$U/bench_${TAG}_flip.txt" "$pipe" "$vrl" "$TAG" "${MEAS:-30}" <<'EOF' | tee "$U/bench_${TAG}.txt"
import statistics, sys
rows = [list(map(float, l.split())) for l in open(sys.argv[1]) if len(l.split()) == 8]
end = rows[-1][0]; secs = float(sys.argv[5]); rows = [r for r in rows if r[0] >= end - secs * 1e6]
ft = sorted(r[1] for r in rows); n = len(ft)
items = statistics.mean(r[2] + r[3] for r in rows)
dps, busy = (sys.argv[2].split() + ['0', '0'])[:2]
dps, busy = float(dps), float(busy)
us = busy / 100 * 1e6 / dps if dps else 0
print(f'{sys.argv[4]}: {n / secs:.1f} FPS, median {statistics.median(ft):.2f} ms, p99 {ft[int(n * .99)]:.2f} ms, '
      f'{items:.0f} draws+dispatches/frame, stage B busy {busy:.1f}% = {us:.3f} us/item'
      + (f', VR game {sys.argv[3]} FPS' if sys.argv[3] else ''))
EOF
