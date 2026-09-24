param([int]$Scale, [string]$Tag = '', [switch]$Sample)
# Racebox single race on Vineta K at a given resolution scale; prints per-second RSX diagnostics
# from pressing Start Race (t=0) to 35 s in, holding accelerate.
$sp = 'C:\Users\matt\AppData\Local\Temp\claude\f--rpsc3-source\b49418ad-c716-45af-82ee-2cc7d21009d5\scratchpad'
$bin = 'F:\rpsc3\source\rpcs3\bin'
$out = "$sp\race$Scale$Tag"; New-Item -ItemType Directory -Force $out | Out-Null
$cfg = "$bin\config\custom_configs\config_BCES00664.yml"
$t = [IO.File]::ReadAllText($cfg); $t = [regex]::Replace($t, 'Resolution Scale: \d+', "Resolution Scale: $Scale"); [IO.File]::WriteAllText($cfg, $t)
function Read-Shared($p) { $fs = [IO.File]::Open($p, 'Open', 'Read', 'ReadWrite,Delete'); $sr = New-Object IO.StreamReader($fs); $x = $sr.ReadToEnd(); $sr.Close(); $x -split "`n" }
function LogSecond { $m = (Read-Shared "$bin\log\RPCS3.log" | Select-String '^\S+ 0:(\d\d):(\d\d)' | Select-Object -Last 1).Matches[0]; [int]$m.Groups[1].Value * 60 + [int]$m.Groups[2].Value }

Get-Process rpcs3 -ErrorAction SilentlyContinue | ForEach-Object { $_.CloseMainWindow() | Out-Null }; Start-Sleep 5
Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Sleep 2
Start-Process "$bin\rpcs3.exe" -ArgumentList "`"$bin\dev_hdd0\game\BCES00664\USRDIR\EBOOT.BIN`"" -WorkingDirectory $bin
Start-Sleep 50
& "$sp\keys.ps1" -Keys 'Right' -GapMs 1500
& "$sp\keys.ps1" -Keys 'X' -GapMs 2500
& "$sp\keys.ps1" -Keys 'X' -GapMs 3000
& "$sp\keys.ps1" -Keys 'X' -GapMs 3000 -Shot "$out\ship.png"
& "$sp\keys.ps1" -Keys 'X' -GapMs 100      # ship -> pre-race flyover
Start-Sleep 22
& "$sp\keys.ps1" -Keys 'X' -GapMs 100 -Shot "$out\prerace.png"   # start race
$t0 = LogSecond
$smi = Start-Process nvidia-smi -ArgumentList '--query-gpu=utilization.gpu,clocks.gr,power.draw --format=csv,noheader -lms 250' -RedirectStandardOutput "$out\gpu.csv" -NoNewWindow -PassThru
if ($Sample) { Start-Sleep 1; & "$sp\sampler.ps1" -Seconds 6 -ThreadPrefix 'rsx::thread' -Top 70 | Set-Content "$out\profile.txt" }

Add-Type @'
using System; using System.Runtime.InteropServices;
public static class K { [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra); [DllImport("user32.dll")] public static extern uint MapVirtualKey(uint c, uint t); }
'@
Start-Sleep 5
$sc = [byte][K]::MapVirtualKey(0x58, 0)
[K]::keybd_event(0x58, $sc, 0, [UIntPtr]::Zero)
Start-Sleep 30
[K]::keybd_event(0x58, $sc, 2, [UIntPtr]::Zero)
Stop-Process -Id $smi.Id -Force -ErrorAction SilentlyContinue
& "$sp\keys.ps1" -Shot "$out\racing.png"
Start-Sleep 2

$rows = @(); $cur = $null
foreach ($line in (Read-Shared "$bin\log\RPCS3.log")) {
	if ($line -match ' 0:(\d\d):(\d\d)\.\d+ \{RSX.*Pacing: (\d+) flips.*replay ([\d.]+) ms') {
		$s = [int]$matches[1] * 60 + [int]$matches[2] - $t0
		$cur = if ($s -ge 0) { [ordered]@{ t = $s; fps = [int]$matches[3]; replay = [double]$matches[4] } } else { $null }
	}
	elseif ($cur -and $line -match 'inside vkQueueSubmit ([\d.]+)') { $cur.submit = [double]$matches[1] }
	elseif ($cur -and $line -match 'Stalls.*guest\) ([\d.]+), zcull reads ([\d.]+)') { $cur.idle = [double]$matches[1]; $cur.zcull = [double]$matches[2] }
	elseif ($cur -and $line -match 'Waits.*vkQueuePresentKHR ([\d.]+), wait_for_event ([\d.]+); (\d+) draws/s; right eye batched (\d+) draws in (\d+) passes') {
		$cur.draws = [int]$matches[3]; $cur.batched = [int]$matches[4]; $cur.passes = [int]$matches[5]
		$rows += [pscustomobject]$cur; $cur = $null
	}
}
$rows | Format-Table -AutoSize | Out-String -Width 200 | Set-Content "$out\table.txt"
Get-Content "$out\table.txt"





