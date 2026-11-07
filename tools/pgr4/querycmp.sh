#!/bin/sh
# querycmp.sh: Tokyo night (Custom Match) grid and a few seconds of driving, flat and VR: occlusion query answers from a frame trace and a shot of each. out/qc_flat*, out/qc_vr*.
T=/f/rpsc3/source/plans/tools/pgr4; P=$T/pg.sh; L=/h/PGR4-ReGPU/thirdparty/ReGPU/out/live.log; O=/h/PGR4-ReGPU/out
one() { # TAG
    sh $T/rainroute.sh
    sleep 4
    $P capture >/dev/null; sleep 4
    cp $L $O/qc_$1_grid.txt
    $P shot H:/PGR4-ReGPU/out/qc_$1_grid.png >/dev/null
    $P trigger R 1 >/dev/null; sleep 9
    $P capture >/dev/null; sleep 4
    cp $L $O/qc_$1_drive.txt
    $P shot H:/PGR4-ReGPU/out/qc_$1_drive.png >/dev/null
    $P trigger R 0 >/dev/null
    $P stop >/dev/null 2>&1
    for s in grid drive; do
        echo "== $1 $s: queries $(grep -c 'occlusion query .* begins' $O/qc_$1_$s.txt)"
        grep 'occlusion query .* ends' $O/qc_$1_$s.txt | sed -E 's/.*answer //' | sort | uniq -c | sort -rn | head -8
    done
}
$P stop >/dev/null 2>&1
$P start PGR4_RESOLUTION=1280x720 PGR4_VSYNC=0 PGR4_MAX_FPS=60 | cut -c1-60
for i in $(seq 1 40); do f=$($P status 2>/dev/null | sed -E 's/.*"frame": ([0-9]+).*/\1/'); [ "${f:-0}" -gt 200 ] 2>/dev/null && break; sleep 3; done
one flat
NO_RACE=1 sh $T/vrrace.sh 2880x2880 | tail -1 | cut -c1-60
one vr
