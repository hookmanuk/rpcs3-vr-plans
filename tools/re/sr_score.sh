#!/bin/sh
# sr_score.sh FILE: summary of sr_drive.sh output (seconds 10-52): mean FPS, seconds under 88 FPS, min FPS, mean RSX ms.
sed -n 10,52p "$1" | awk '{n++; f+=$1; r+=$3; if($1<88)u++; if(min==""||$1<min)min=$1} END{printf "mean %.1f FPS, %d s under 88, min %.1f, RSX %.2f ms\n", f/n, u, min, r/n}'
