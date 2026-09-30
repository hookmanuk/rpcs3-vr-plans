# Boot God of War Collection (BCES00800) fresh to gameplay (GoW1: the boat, after the intro video).
# Needs the temporary keyboard pad in input_configs/BCES00800. -Game2: God of War II instead.
# Waits by watching the log for the executable switches rather than fixed delays (menus take longer at 90 Hz).
param([switch]$Game2, [switch]$Headset, [string]$Probe = '', [switch]$TitleOnly, [string]$Audit = '')
$w = "$env:TEMP\rpcs3-vrprofile"
$log = 'F:\rpsc3\source\rpcs3\bin\log\RPCS3.log'
function LogHas($pat) { & 'C:\Program Files\Git\usr\bin\grep.exe' -a -q $pat $log; return $LASTEXITCODE -eq 0 }
function Keys($k) { Set-Content "$w\KEYS" $k -NoNewline }
$a = @{ Game = 'F:/rpsc3/games/God of War Collection (UK).dec.iso' }
if (-not $Headset) { $a.NoHeadset = $true }
if ($Probe) { $a.Probe = $Probe }
if ($Audit) { $a.Audit = $Audit }
& F:\rpsc3\source\plans\tools\launch.ps1 @a
# Intro logo video -> game selector (GAMESEL.self)
for ($i = 0; $i -lt 12 -and -not (LogHas 'USRDIR/GAMESEL.self., title_id'); $i++) { Keys "Return 150 1500`nX 150 1500"; Start-Sleep 5 }
$exe = if ($Game2) { 'GOW2.self' } else { 'GOW1.self' }
for ($i = 0; $i -lt 12 -and -not (LogHas "USRDIR/$exe., title_id"); $i++) {
	Start-Sleep 6
	if ($Game2) { Keys "Down 150 800`nX 150 1000" } else { Keys "X 150 1000" }
	Start-Sleep 4
	if (-not (LogHas "USRDIR/$exe., title_id")) { Keys "Up 150 400`nUp 150 400`nUp 150 400`nUp 150 400" }
}
"booting $exe"
Start-Sleep 40
if ($TitleOnly) { return }
Keys "X 150 3000`nX 150 3000`nX 150 3000"
Start-Sleep 12
"new game started (intro video ~90 s)"
