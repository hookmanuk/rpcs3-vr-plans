# keys.sh 'LINE\nLINE...': write an RPCS3_VR_KEYS script atomically (the hook can read a half-written file).
W="$TEMP/rpcs3-vrprofile"; printf "$1" > "$W/KEYS.tmp" && mv -f "$W/KEYS.tmp" "$W/KEYS"
