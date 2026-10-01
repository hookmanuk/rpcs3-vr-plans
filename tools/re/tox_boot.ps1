# Boot Tales of Xillia (BLUS31006) (needs the temporary keyboard pad).
param([switch]$Headset, [string]$Probe = '', [string]$Audit = '')
$w = "$env:TEMP\rpcs3-vrprofile"
$env:RPCS3_VR_GEN_TRIGGER = "$w\GEN"
$env:RPCS3_VR_MEMDUMP = "$w\tox_dump"
$env:RPCS3_VR_POKE = "$w\POKE"
$env:RPCS3_PPU_WATCH_FILE = "$w\WATCH"
if ($env:TOX_PEEK) { Set-Content "$w\peek.txt" $env:TOX_PEEK -NoNewline; $env:RPCS3_VR_PEEK = "$w\peek.txt" } else { Remove-Item Env:RPCS3_VR_PEEK -ErrorAction SilentlyContinue }
if ($env:TOX_TRACE) { $env:RPCS3_PPU_TRACE = $env:TOX_TRACE; $env:RPCS3_PPU_TRACE_REGS = $env:TOX_REGS } else { Remove-Item Env:RPCS3_PPU_TRACE -ErrorAction SilentlyContinue }
$a = @{ Game = "F:/rpsc3/games/Tales of Xillia (USA) (En,Fr,Es).iso" }
if (-not $Headset) { $a.NoHeadset = $true }
if ($Probe) { $a.Probe = $Probe }
if ($Audit) { $a.Audit = $Audit }
& F:\rpsc3\source\plans\tools\launch.ps1 @a
"launched"
# First-run options -> opening movie (skip) -> character select (Jude) -> cutscene (skip) -> tutorials -> field.
function K($s, $t) { Set-Content "$w\KEYS.tmp" $s -NoNewline; Move-Item -Force "$w\KEYS.tmp" "$w\KEYS"; Start-Sleep $t }
Start-Sleep 30
K "Return 300 4000`nX 200 4000" 16
K "Return 300 4000" 6
K "Down 200 1000`nX 200 2500`nX 200 5000" 30
K "Left 200 1500`nX 200 3000`nX 200 3000" 33
K "Return 300 3000" 5
K "Down 200 1000`nX 200 2500`nX 200 5000" 30
K "X 200 3000" 8
K "X 200 3000`nX 200 3000" 10
"in the field (check with a screenshot)"
