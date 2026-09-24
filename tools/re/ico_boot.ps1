# ico_boot.ps1: fresh-boot ICO (collection launcher -> intro -> New Game) with the VR dev hooks, for scripted tests.
param([switch]$Headset, [string]$Probe = '', [string]$Audit = '')
$w = "$env:TEMP\rpcs3-vrprofile"
$env:RPCS3_VR_SHOT = "$w\SHOT"; $env:RPCS3_VR_KEYS = "$w\KEYS"; $env:RPCS3_VR_MEMDUMP = "$w\dump\F"
$iso = @(Resolve-Path 'F:/rpsc3/games/Ico*.iso')[0].Path
if ($Headset) { & F:\rpsc3\source\plans\tools\launch.ps1 -Game $iso -Probe $Probe } else { & F:\rpsc3\source\plans\tools\launch.ps1 -Game $iso -Probe $Probe -NoHeadset -Audit $Audit }
Start-Sleep 8; Set-Content "$w\KEYS" "X 150 1000" -NoNewline; Start-Sleep 25
Set-Content "$w\KEYS" "Return 150 1000" -NoNewline; Start-Sleep 8
Set-Content "$w\KEYS" "X 150 1500`nX 150 1500" -NoNewline
