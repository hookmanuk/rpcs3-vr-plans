#!/bin/sh
# marktest.sh TAG [NAME=VALUE...]: simulator, the St Petersburg grid in the default (chase) view: a shot after 8 s and after 6 s of driving,
# to look for missing road markings / signs. Out: out/mark_TAG_{grid,drive}.png
T=/f/rpsc3/source/plans/tools/pgr4; P=$T/pg.sh; O=H:/PGR4-ReGPU/out
TAG=$1; shift
tasklist | grep -qi pgr4.exe && { echo "pgr4 is running: stopping"; exit 1; }
sh $T/vrrace.sh 2880x2880 "$@" >/dev/null 2>&1
$P wait 8s >/dev/null
$P shot $O/mark_${TAG}_grid.png >/dev/null
$P trigger R 1 >/dev/null; sleep 6
$P shot $O/mark_${TAG}_drive.png >/dev/null
$P trigger R 0 >/dev/null
$P stop >/dev/null 2>&1; sleep 2
