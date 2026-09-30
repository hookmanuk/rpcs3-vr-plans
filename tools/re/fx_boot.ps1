# Boot FFX/X-2 HD (BLUS31211) and pick Final Fantasy X in the launcher (needs the temporary keyboard pad).
param([switch]$Headset, [string]$Probe = '', [string]$Audit = '')
$w = "$env:TEMP\rpcs3-vrprofile"
$env:RPCS3_VR_GEN_TRIGGER = "$w\GEN"
$env:RPCS3_VR_MEMDUMP = "$w\fx_dump"
$a = @{ Game = "F:/rpsc3/games/Final Fantasy X + X-2 - HD Remaster (USA) (En,Fr,De,Es,It).iso" }
if (-not $Headset) { $a.NoHeadset = $true }
if ($Probe) { $a.Probe = $Probe }
if ($Audit) { $a.Audit = $Audit }
& F:\rpsc3\source\plans\tools\launch.ps1 @a
Start-Sleep 25
Set-Content "$w\KEYS" "X 150 3000" -NoNewline; Start-Sleep 25
"in game (check with a screenshot)"
