param([string]$Probe = '', [switch]$Headset, [int]$Samples = 6, [string]$Walk = '')
# Boot SotC (collection menu -> Shadow), wait for gameplay, then print FPS from the title and GPU load.
$w="$env:TEMP\rpcs3-vrprofile"
$env:RPCS3_VR_KEYS = "$w\KEYS"; $env:RPCS3_VR_SHOT = "$w\SHOT"
foreach ($v in 'RPCS3_VR_AUDIT_FOV','RPCS3_PPU_WATCH') { Remove-Item "Env:$v" -ErrorAction SilentlyContinue }
$args2 = @{ Game = @(Resolve-Path 'F:/rpsc3/games/Ico*.iso')[0].Path }
if ($Probe) { $args2.Probe = $Probe }
if (-not $Headset) { $args2.NoHeadset = $true }
& F:\rpsc3\source\plans\tools\launch.ps1 @args2 | Out-Null
Start-Sleep 8; Set-Content "$w\KEYS" "Right 150 1500`nX 150 1000" -NoNewline; Start-Sleep 25
Set-Content "$w\KEYS" "Return 150 5000`nX 150 9000`nReturn 150 6000" -NoNewline; Start-Sleep 40
if ($Walk) { Set-Content "$w\KEYS" $Walk -NoNewline; Start-Sleep 6 }
for ($i = 0; $i -lt $Samples; $i++) {
  Start-Sleep 3
  $t = (Get-Process rpcs3).MainWindowTitle; $fps = if ($t -match 'FPS: ([\d.]+)') { $Matches[1] } else { '?' }
  $g = (& nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits).Trim()
  $cpu = [math]::Round((Get-Counter '\Process(rpcs3)\% Processor Time' -SampleInterval 1 -MaxSamples 1).CounterSamples[0].CookedValue / 100, 1)
  "fps $fps gpu $g% cpu-cores $cpu"
}
