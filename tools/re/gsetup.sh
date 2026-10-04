#!/bin/sh
# gsetup.sh ID VBLANK [extra yaml lines]: temporary keyboard pad + custom config for a title
# (an existing custom config is kept as config_ID.yml.gsetup.bak; gclean.sh puts it back). The temporary config
# starts with a "# gsetup temporary" line, so a second gsetup without gclean never backs it up as the real one.
C=/f/rpsc3/source/rpcs3/bin/config
mkdir -p "$C/input_configs/$1" && cp /f/rpsc3/source/plans/tools/keyboard-pad-template.yml "$C/input_configs/$1/Default.yml"
F="$C/custom_configs/config_$1.yml"
[ -f "$F" ] && [ ! -f "$F.gsetup.bak" ] && ! head -1 "$F" | grep -q "^# gsetup temporary" && cp "$F" "$F.gsetup.bak"
printf "# gsetup temporary\nVideo:\n  Vblank Rate: $2\n$3" > "$F"
