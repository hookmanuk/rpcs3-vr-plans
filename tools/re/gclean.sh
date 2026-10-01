#!/bin/sh
# gclean.sh ID: stop rpcs3, remove the temporary pad and custom config
powershell -c "Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force"
C=/f/rpsc3/source/rpcs3/bin/config; rm -rf "$C/input_configs/$1"; rm -f "$C/custom_configs/config_$1.yml"
