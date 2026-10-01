# Launch FFX/X-2 HD with extra env (FX_ENV "A=1;B=2"), no key script.
$w = "$env:TEMP\rpcs3-vrprofile"
if ($env:FX_ENV) { foreach ($kv in $env:FX_ENV -split ";") { $k, $v = $kv -split "=", 2; Set-Item "Env:$k" $v } }
$env:RPCS3_VR_MEMDUMP = "$w\fx_dump"; $env:RPCS3_VR_POKE = "$w\POKE"; $env:RPCS3_PPU_WATCH_FILE = "$w\WATCH"
& F:\rpsc3\source\plans\tools\launch.ps1 -Game "F:/rpsc3/games/Final Fantasy X + X-2 - HD Remaster (USA) (En,Fr,De,Es,It).iso" -NoHeadset
