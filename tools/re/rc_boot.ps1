# Boot Ratchet & Clank Collection (BCUS98282) (needs the temporary keyboard pad).
param([switch]$Headset, [string]$Probe = '', [string]$Audit = '')
$w = "$env:TEMP\rpcs3-vrprofile"
$env:RPCS3_VR_GEN_TRIGGER = "$w\GEN"
$env:RPCS3_VR_MEMDUMP = "$w\rc_dump"
$env:RPCS3_VR_POKE = "$w\POKE"
$a = @{ Game = "F:/rpsc3/games/Ratchet & Clank Collection (USA) (En,Fr,Es).iso" }
if (-not $Headset) { $a.NoHeadset = $true }
if ($Probe) { $a.Probe = $Probe }
if ($Audit) { $a.Audit = $Audit }
& F:\rpsc3\source\plans\tools\launch.ps1 @a
"launched"
# Logos -> collection menu (R&C1) -> title -> New Game -> new save slot -> skip the opening cutscenes -> Veldin.
function K($s, $t) { Set-Content "$w\KEYS.tmp" $s -NoNewline; Move-Item -Force "$w\KEYS.tmp" "$w\KEYS"; Start-Sleep $t }
Start-Sleep 20
K "X 200 3000`nReturn 200 3000`nX 200 3000`nReturn 200 4000" 16
K "X 200 3000" 25
K "Return 300 2000`nX 300 2000" 8
K "X 200 3000`nX 200 3000`nX 200 3000" 21
K "Return 200 3000`nX 200 3000" 26
K "Return 200 3000`nReturn 200 3000`nX 200 3000" 34
K "Return 200 3000`nReturn 200 3000" 21
"at Veldin (check with a screenshot)"
