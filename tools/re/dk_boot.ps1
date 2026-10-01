# Boot The Darkness (BLUS30035) (needs the temporary keyboard pad).
param([switch]$Headset, [string]$Probe = '', [string]$Audit = '', [int]$FakeHmd = 0)
$w = "$env:TEMP\rpcs3-vrprofile"
$env:RPCS3_VR_GEN_TRIGGER = "$w\GEN"
$env:RPCS3_VR_MEMDUMP = "$w\dk_dump"
$env:RPCS3_VR_POKE = "$w\POKE"
$a = @{ Game = "F:/rpsc3/games/Darkness, The (USA) (En,Fr,De,Es,It).iso" }
if (-not $Headset) { $a.NoHeadset = $true }
if ($Probe) { $a.Probe = $Probe }
if ($Audit) { $a.Audit = $Audit }
if ($FakeHmd) { $a.FakeHmd = $FakeHmd }
& F:\rpsc3\source\plans\tools\launch.ps1 @a
"launched"
# Intro video (X), autosave notice (X), New Game, Medium: the opening (first-person, "Use to look around").
function K($s, $t) { Set-Content "$w\KEYS.tmp" $s -NoNewline; Move-Item -Force "$w\KEYS.tmp" "$w\KEYS"; Start-Sleep $t }
Start-Sleep 25
K "Return 300 4000`nX 200 4000" 12
K "X 200 3000`nReturn 300 3000" 10
K "X 200 3000" 8
K "X 200 3000" 8
K "X 200 3000" 45
"in game (check with a screenshot)"
