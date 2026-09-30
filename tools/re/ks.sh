#!/bin/sh
# ks.sh ID OUT 'KEYS' [wait]: send a key script, wait, screenshot (640 wide) and print the title
sh "$(dirname "$0")/keys.sh" "$3"; py -3.13 "$(dirname "$0")/shot.py" "$1" "$2" 640 - "${4:-6}"
