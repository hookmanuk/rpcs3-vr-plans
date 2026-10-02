param([Parameter(Mandatory)][string]$Game, [string]$Probe = '', [string]$Work = "$env:TEMP\rpcs3-vrprofile",
      [switch]$NoHeadset, [string]$Audit = '', [int]$FakeHmd = 0)
# Restart RPCS3 on a game with the VR development hooks:
#   inspector   RPCS3_STEREO_INSPECT=$Work\insp\   (create $Work\insp\ARM to capture one frame)
#   probe file  RPCS3_VR_PROBE_FILE=$Work\probe.txt (rewritten any time; re-read every frame)
#   screenshot  RPCS3_VR_SHOT=$Work\SHOT            (create it; plans\tools\re\shot.py does)
#   profile     RPCS3_VR_PROFILE_RELOAD=1           (edits to bin\vr_profiles\<id>.json apply live)
#   -Probe 'render=1'   start with stereo rendering armed (the file replaces the default)
#   -NoHeadset          RPCS3_OPENXR=0: both eyes side by side on the desktop
#   -Audit 25 | pitch:35  rotation audit: right eye yawed/pitched, left eye as reference
#   -FakeHmd 100        with -NoHeadset: render the headset view (HUD box, head transform, 100-degree FOV) on the desktop
$bin = 'F:\rpsc3\source\rpcs3\bin'
New-Item -ItemType Directory -Force "$Work\insp" | Out-Null
Get-Process rpcs3 -ErrorAction SilentlyContinue | ForEach-Object { $_.CloseMainWindow() | Out-Null }; Start-Sleep 5
Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Sleep 2
Remove-Item "$Work\probe.txt" -ErrorAction SilentlyContinue
if ($Probe) { Set-Content "$Work\probe.txt" $Probe -NoNewline }
$env:RPCS3_STEREO_INSPECT = "$Work\insp\"
$env:RPCS3_VR_PROBE_FILE = "$Work\probe.txt"
$env:RPCS3_VR_SHOT = "$Work\SHOT"   # create this file for a screenshot (re/shot.py)
$env:RPCS3_VR_KEYS = "$Work\KEYS"  # key script, e.g. 'I 3000' (needs a keyboard pad profile)
$env:RPCS3_VR_RTDUMP = "$Work\RTDUMP"  # write hex surface addresses into it: raw left/right dumps (empty: display buffer)
$env:RPCS3_VR_PROFILE_RELOAD = '1'  # re-read bin\vr_profiles\<id>.json within 0.5 s of an edit
$env:RPCS3_VR_SAVESTATE = "$Work\SAVESTATE"  # create it to save a savestate, as Ctrl+S (works with the desktop locked)
if ($NoHeadset) { $env:RPCS3_OPENXR = '0' } else { Remove-Item Env:RPCS3_OPENXR -ErrorAction SilentlyContinue }
if ($FakeHmd) { $env:RPCS3_VR_FAKE_HMD = "$FakeHmd" } else { Remove-Item Env:RPCS3_VR_FAKE_HMD -ErrorAction SilentlyContinue }
if ($Audit) { $env:RPCS3_VR_AUDIT = $Audit } else { Remove-Item Env:RPCS3_VR_AUDIT -ErrorAction SilentlyContinue }
Start-Process "$bin\rpcs3.exe" -ArgumentList "`"$Game`"" -WorkingDirectory $bin
for ($i = 0; $i -lt 180; $i++) { Start-Sleep 1; if ($i % 5 -eq 4) { & "$PSScriptRoot\re\dismiss_pkg.ps1" | Out-Null }; $t = (Get-Process rpcs3 -ErrorAction SilentlyContinue | Select-Object -First 1).MainWindowTitle; if ($t -match 'FPS: [1-9]') { break } }
"running: $t"
