# kh2_boot.ps1 [-Headset] [-Probe ..]: boot Kingdom Hearts HD 2.5 ReMIX (BLUS31460) from the disc into Kingdom Hearts II
# Final Mix, New Game (Standard, vibration on), through the opening movie (~6.5 min) and the first scene (skipped) to
# Twilight Town, first control. Needs the temporary keyboard pad in input_configs/BLUS31460 (600 ms presses).
# System data and the display-settings screen were done on the first boot (2026-10-02).
param([switch]$Headset, [string]$Probe = '')
$w = "$env:TEMP\rpcs3-vrprofile"
$log = 'F:\rpsc3\source\rpcs3\bin\log\RPCS3.log'
$grep = 'C:\Program Files\Git\usr\bin\grep.exe'
function K($s, $t) { Set-Content "$w\KEYS.tmp" $s -NoNewline; Move-Item -Force "$w\KEYS.tmp" "$w\KEYS"; Start-Sleep $t }
if ($Headset) { $env:XR_RUNTIME_JSON = 'F:\rpsc3\source\OpenXR-Simulator\bin\openxr_simulator.json' }
$a = @{ Game = 'F:/rpsc3/games/Kingdom Hearts - HD 2.5 ReMIX (USA) (En,Fr,Es).iso' }
if (-not $Headset) { $a.NoHeadset = $true }
if ($Probe) { $a.Probe = $Probe }
& F:\rpsc3\source\plans\tools\launch.ps1 @a | Out-Null
"launched"
for ($i = 0; $i -lt 20; $i++) {
	K "X 600 2500" 6
	& $grep -a -q 'USRDIR/kingdom2.self., title_id' $log
	if ($LASTEXITCODE -eq 0) { break }
}
"kingdom2.self after $i tries"
Start-Sleep 35
$closes = [int](& $grep -a -c 'cellVdecClose(handle' $log)
# Title: New Game -> Standard Mode -> vibration On -> Yes
K "X 600 4500`nX 600 4500`nX 600 4500`nX 600 4500" 25
for ($i = 0; $i -lt 180; $i++) {
	Start-Sleep 5
	if ([int](& $grep -a -c 'cellVdecClose(handle' $log) -gt $closes) { break }
}
"movie ended after $($i * 5) s"
Start-Sleep 12
# First scene (Roxas wakes): Start -> Skip Scene
K "Return 600 2000`nDown 600 1200`nX 600 3000" 12
"at Twilight Town (check with a screenshot)"
