#!/bin/sh
# gsetup.sh ID VBLANK [extra yaml lines]: temporary keyboard pad + custom config for a title
C=/f/rpsc3/source/rpcs3/bin/config
mkdir -p "$C/input_configs/$1" && cp /f/rpsc3/source/plans/tools/keyboard-pad-template.yml "$C/input_configs/$1/Default.yml"
printf "Video:\n  Vblank Rate: $2\n$3" > "$C/custom_configs/config_$1.yml"
