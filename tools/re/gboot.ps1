# Generic boot for profiling a game: gboot.ps1 -Iso <path> [-Probe ..] [-Audit ..] [-FakeHmd N] [-Interp]
param([Parameter(Mandatory)][string]$Iso, [string]$Probe = '', [string]$Audit = '', [int]$FakeHmd = 0)
$w = "$env:TEMP\rpcs3-vrprofile"
$env:RPCS3_VR_GEN_TRIGGER = "$w\GEN"; $env:RPCS3_VR_MEMDUMP = "$w\g_dump"; $env:RPCS3_VR_POKE = "$w\POKE"; $env:RPCS3_PPU_WATCH_FILE = "$w\WATCH"
if ($env:G_PEEK) { Set-Content "$w\peek.txt" $env:G_PEEK -NoNewline; $env:RPCS3_VR_PEEK = "$w\peek.txt" } else { Remove-Item Env:RPCS3_VR_PEEK -ErrorAction SilentlyContinue }
$a = @{ Game = $Iso; NoHeadset = $true }
if ($Probe) { $a.Probe = $Probe }
if ($Audit) { $a.Audit = $Audit }
if ($FakeHmd) { $a.FakeHmd = $FakeHmd }
& F:\rpsc3\source\plans\tools\launch.ps1 @a
