#!/bin/sh
# down.sh ID: kill rpcs3, restore config, remove temp pad, reset pose
R=/f/rpsc3/source/plans/tools/re; cd $R
id=$1; P=/f/rpsc3/source/rpcs3/bin/config/input_configs/$id
powershell -c 'Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force; $t=0; while ((Get-Process rpcs3 -ErrorAction SilentlyContinue | Where-Object { $_.Threads.Count -gt 1 }) -and $t -lt 100) { Start-Sleep -Milliseconds 200; $t++ }'
sleep 5
py -3.13 cfgtemp.py $id restore; py -3.13 cfgtemp.py global restore >/dev/null
[ -f "$P/.tmp_pad" ] && rm -r "${P:?}"
py -3.13 simpose.py 0 0 0 >/dev/null
rm -f "$TEMP/rpcs3-vrprofile/KEYS"
echo down
