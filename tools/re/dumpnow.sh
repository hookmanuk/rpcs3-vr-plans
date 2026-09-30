#!/bin/sh
# dumpnow.sh NAME: trigger an RPCS3_VR_MEMDUMP (whose file is $TEMP/rpcs3-vrprofile/NAME), wait for the new dump, print its base path.
W="$TEMP/rpcs3-vrprofile"; touch "$W/.dumpmark"; sleep 0.1; touch "$W/$1"
until [ -n "$(find "$W" -maxdepth 1 -name "$1.*.txt" -newer "$W/.dumpmark" 2>/dev/null)" ]; do sleep 0.5; done; sleep 1
f=$(find "$W" -maxdepth 1 -name "$1.*.txt" -newer "$W/.dumpmark" | head -1); echo "${f%.txt}"
