# dante_boot.ps1 [-Headset] [-Probe ..]: boot Dante's Inferno (BLUS30405) from the disc to Acre: logos (X/Start),
# PSN notice (X), main menu Start Game, video calibration (X), difficulty (X), the unskippable intro movie (~90 s,
# waited on its decoder closing). Needs the temporary keyboard pad in input_configs/BLUS30405.
param([switch]$Headset, [string]$Probe = '')
$w = "$env:TEMP\rpcs3-vrprofile"
$log = 'F:\rpsc3\source\rpcs3\bin\log\RPCS3.log'
$grep = 'C:\Program Files\Git\usr\bin\grep.exe'
function K($s, $t) { Set-Content "$w\KEYS.tmp" $s -NoNewline; Move-Item -Force "$w\KEYS.tmp" "$w\KEYS"; Start-Sleep $t }
if ($Headset) { $env:XR_RUNTIME_JSON = 'F:\rpsc3\source\OpenXR-Simulator\bin\openxr_simulator.json' }
$a = @{ Game = "F:/rpsc3/games/Dante's Inferno (USA) (En,Fr,Es).iso" }
if (-not $Headset) { $a.NoHeadset = $true }
if ($Probe) { $a.Probe = $Probe }
& F:\rpsc3\source\plans\tools\launch.ps1 @a | Out-Null
"launched"
Start-Sleep 12
K "X 200 2500`nReturn 200 2500`nX 200 2500" 14
K "X 200 3000" 8
$closes = [int](& $grep -a -c 'cellVdecClose(handle' $log)
K "X 200 4000`nX 200 4000`nX 200 4000" 16
for ($i = 0; $i -lt 60; $i++) {
	Start-Sleep 5
	if ([int](& $grep -a -c 'cellVdecClose(handle' $log) -gt $closes) { break }
}
Start-Sleep 10
"intro ended after $($i * 5) s: at Acre (check with a screenshot)"
