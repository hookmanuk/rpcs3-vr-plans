# kh1_boot.ps1 [-Headset] [-Probe ..]: boot Kingdom Hearts HD 1.5 ReMIX (BLUS31212) from the disc into Kingdom Hearts
# Final Mix, New Game (Final Mix difficulty, Manual camera, vibration on), through the opening movie to the Dive to the
# Heart. Needs the temporary keyboard pad in input_configs/BLUS31212. KH reads the pad slowly: presses are 600 ms.
# The opening movie (~5 min at 30 FPS) cannot be skipped on a new game; the script waits for the frame rate to rise.
param([switch]$Headset, [string]$Probe = '')
$w = "$env:TEMP\rpcs3-vrprofile"
$log = 'F:\rpsc3\source\rpcs3\bin\log\RPCS3.log'
$grep = 'C:\Program Files\Git\usr\bin\grep.exe'
function K($s, $t) { Set-Content "$w\KEYS.tmp" $s -NoNewline; Move-Item -Force "$w\KEYS.tmp" "$w\KEYS"; Start-Sleep $t }
if ($Headset) { $env:XR_RUNTIME_JSON = 'F:\rpsc3\source\OpenXR-Simulator\bin\openxr_simulator.json' }
$a = @{ Game = 'F:/rpsc3/games/Kingdom Hearts - HD 1.5 ReMIX (USA) (En,Fr,Es).iso' }
if (-not $Headset) { $a.NoHeadset = $true }
if ($Probe) { $a.Probe = $Probe }
& F:\rpsc3\source\plans\tools\launch.ps1 @a | Out-Null
"launched"
# Collection menu (Kingdom Hearts Final Mix selected) -> Yes -> kingdom.self
for ($i = 0; $i -lt 20; $i++) {
	K "X 600 2500" 6
	& $grep -a -q 'USRDIR/kingdom.self., title_id' $log
	if ($LASTEXITCODE -eq 0) { break }
}
"kingdom.self after $i tries"
Start-Sleep 25
# Title: New Game -> difficulty (Final Mix) -> camera Manual -> vibration On -> Proceed
$closes = (& $grep -a -c 'cellVdecClose' $log)
K "X 600 3000`nX 600 3000`nDown 600 1500`nX 600 3000`nX 600 3000`nX 600 3000" 25
# Opening movie (its decoder closes when it ends), then the Dive to the Heart (in engine)
for ($i = 0; $i -lt 100; $i++) {
	Start-Sleep 5
	if ([int](& $grep -a -c 'cellVdecClose' $log) -gt [int]$closes) { break }
}
Start-Sleep 15
"movie ended after $($i * 5) s: $((Get-Process rpcs3 -ErrorAction SilentlyContinue | Select-Object -First 1).MainWindowTitle)"
