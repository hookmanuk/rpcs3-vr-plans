# Boot Killzone 2 (BCUS98116) to Campaign > Continue (needs an existing campaign save and the temporary keyboard pad).
param([switch]$Headset, [string]$Probe = '', [string]$Audit = '')
$w = "$env:TEMP\rpcs3-vrprofile"
$a = @{ Game = 'F:/rpsc3/games/Killzone 2 (USA) (En,Fr,De,Es,It,Nl,Pt,Sv,No,Da,Fi,Pl,Ru).iso' }
if (-not $Headset) { $a.NoHeadset = $true }
if ($Probe) { $a.Probe = $Probe }
if ($Audit) { $a.Audit = $Audit }
& F:\rpsc3\source\plans\tools\launch.ps1 @a
Start-Sleep 20; Set-Content "$w\KEYS" "X 150 4000`nReturn 150 4000" -NoNewline; Start-Sleep 10
Set-Content "$w\KEYS" "X 200 2000" -NoNewline; Start-Sleep 4
Set-Content "$w\KEYS" "X 200 2000" -NoNewline; Start-Sleep 90
"continued"
