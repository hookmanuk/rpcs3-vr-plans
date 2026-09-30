# Boot Dragon's Dogma DA (BLUS31155 v01.02) to Load Game (needs the temporary keyboard pad and a save).
param([switch]$Headset, [string]$Probe = '', [string]$Audit = '')
$w = "$env:TEMP\rpcs3-vrprofile"
$env:RPCS3_VR_GEN_TRIGGER = "$w\GEN"
$a = @{ Game = "F:/rpsc3/games/Dragon's Dogma - Dark Arisen (USA) (En,Ja,Fr,De,Es,It).iso" }
if (-not $Headset) { $a.NoHeadset = $true }
if ($Probe) { $a.Probe = $Probe }
if ($Audit) { $a.Audit = $Audit }
& F:\rpsc3\source\plans\tools\launch.ps1 @a
Start-Sleep 30
Set-Content "$w\KEYS" "Return 150 5000`nX 150 5000`nX 150 5000`nX 150 5000`nX 150 5000`nX 150 5000" -NoNewline; Start-Sleep 60
"in game (check with a screenshot)"
