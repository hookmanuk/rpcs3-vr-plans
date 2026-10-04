#!/bin/sh
# gclean.sh ID: stop rpcs3, remove the temporary pad, put back the custom config gsetup.sh replaced (or remove it)
powershell -c "Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force"
C=/f/rpsc3/source/rpcs3/bin/config; rm -rf "$C/input_configs/$1"; F="$C/custom_configs/config_$1.yml"
if [ -f "$F.gsetup.bak" ]; then mv -f "$F.gsetup.bak" "$F"; else rm -f "$F"; fi
