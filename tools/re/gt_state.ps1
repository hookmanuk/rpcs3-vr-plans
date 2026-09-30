# Boot GT5 (BCUS98114) from a savestate: -State 1 = race start (red shadows repro), 0 = car selection.
param([int]$State = 1, [switch]$Headset, [string]$Probe = 'render=1', [string]$Audit = '')
$a = @{ Game = "F:/rpsc3/source/rpcs3/bin/savestates/BCUS98114/BCUS98114_1_$State.SAVESTAT.zst" }
if (-not $Headset) { $a.NoHeadset = $true }
if ($Probe) { $a.Probe = $Probe }
if ($Audit) { $a.Audit = $Audit }
& F:\rpsc3\source\plans\tools\launch.ps1 @a
"launched"
