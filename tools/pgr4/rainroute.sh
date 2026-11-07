#!/bin/sh
# rainroute.sh: on a running game at the title screen: Custom Match, Tokyo at night (the default), heavy rain, to the race grid.
P=/f/rpsc3/source/plans/tools/pgr4/pg.sh
st() { $P press "$1" >/dev/null; $P wait "$2" >/dev/null; }
$P wait 3s >/dev/null
st START 6s; st A 7s; st A 5s
st RIGHT 2s; st RIGHT 2s; st RIGHT 2s
st A 5s; st A 5s
st DOWN 1s; st DOWN 1s; st A 3s; st RIGHT 2s; st RIGHT 2s; st A 2s
st DOWN 1s; st DOWN 1s; st DOWN 1s; st A 6s
st START 3s; st A 18s; st A 14s
