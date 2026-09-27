param([Parameter(Mandatory)][string]$Game, [string]$Probe = '', [string]$Work = "$env:TEMP\rpcs3-vrprofile",
      [switch]$NoHeadset, [string]$Audit = '')
# Restart RPCS3 on a game with the VR development hooks:
#   inspector   RPCS3_STEREO_INSPECT=$Work\insp\   (create $Work\insp\ARM to capture one frame)
#   probe file  RPCS3_VR_PROBE_FILE=$Work\probe.txt (rewritten any time; re-read every frame)
#   screenshot  RPCS3_VR_SHOT=$Work\SHOT            (create it; plans\tools\re\shot.py does)
#   -Probe 'render=1'   start with stereo rendering armed (the file replaces the default)
#   -NoHeadset          RPCS3_OPENXR=0: both eyes side by side on the desktop
#   -Audit 25 | pitch:35  rotation audit: right eye yawed/pitched, left eye as reference
$bin = 'F:\rpsc3\source\rpcs3\bin'
New-Item -ItemType Directory -Force "$Work\insp" | Out-Null
Get-Process rpcs3 -ErrorAction SilentlyContinue | ForEach-Object { $_.CloseMainWindow() | Out-Null }; Start-Sleep 5
Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Sleep 2
Remove-Item "$Work\probe.txt" -ErrorAction SilentlyContinue
if ($Probe) { Set-Content "$Work\probe.txt" $Probe -NoNewline }
$env:RPCS3_STEREO_INSPECT = "$Work\insp\"
$env:RPCS3_VR_PROBE_FILE = "$Work\probe.txt"
$env:RPCS3_VR_SHOT = "$Work\SHOT"   # create this file for a screenshot (re/shot.py)
if ($NoHeadset) { $env:RPCS3_OPENXR = '0' } else { Remove-Item Env:RPCS3_OPENXR -ErrorAction SilentlyContinue }
if ($Audit) { $env:RPCS3_VR_AUDIT = $Audit } else { Remove-Item Env:RPCS3_VR_AUDIT -ErrorAction SilentlyContinue }
Start-Process "$bin\rpcs3.exe" -ArgumentList "`"$Game`"" -WorkingDirectory $bin
for ($i = 0; $i -lt 180; $i++) { Start-Sleep 1; $t = (Get-Process rpcs3 -ErrorAction SilentlyContinue | Select-Object -First 1).MainWindowTitle; if ($t -match 'FPS: [1-9]') { break } }
"running: $t"
