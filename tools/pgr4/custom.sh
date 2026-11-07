#!/bin/sh
# custom.sh [EYE]: from a VR boot to the Custom Match options page (city, route, weather, laps, lobby). Shots of each step in out/nav*.png
T=/f/rpsc3/source/plans/tools/pgr4; P=$T/pg.sh; O=H:/PGR4-ReGPU/out
st() { $P press "$1" >/dev/null; $P wait "$2" >/dev/null; }
NO_RACE=1 sh $T/vrrace.sh "${1:-2880x2880}" | tail -1 | cut -c1-60
$P wait 3s >/dev/null
st START 6s; st A 7s; st A 5s
$P shot $O/nav0.png >/dev/null
st RIGHT 2s; st RIGHT 2s; st RIGHT 2s
$P shot $O/nav1.png >/dev/null
st A 5s
$P shot $O/nav2.png >/dev/null
st A 5s
$P shot $O/nav3.png >/dev/null
