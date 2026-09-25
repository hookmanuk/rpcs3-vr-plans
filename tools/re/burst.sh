#!/bin/sh
# burst.sh N OUTDIR: take N RPCS3_VR_SHOT captures back to back into OUTDIR (full-size PNGs moved there).
W="$TEMP/rpcs3-vrprofile"; S=F:/rpsc3/source/rpcs3/bin/screenshots/${SHOT_ID:-BCUS98259}
mkdir -p "$2"
for k in $(seq 1 $1); do
  before=$(ls -t "$S"/*.png 2>/dev/null | head -1); touch "$W/SHOT"
  for i in $(seq 1 100); do sleep 0.2; n=$(ls -t "$S"/*.png | head -1); [ "$n" != "$before" ] && break; done
  # wait until the PNG is complete (size stable)
  s0=-1; while :; do s1=$(stat -c %s "$n"); [ "$s1" = "$s0" ] && [ "$s1" -gt 0 ] && break; s0=$s1; sleep 0.5; done
  mv "$n" "$2/$(printf %03d $k).png"
done
