# icovr_yaw.ps1 [-From s] [-To s] [-Step s] [-Out dir]: the ICO VR port on the OpenXR Simulator through
# icovr-title.txt (the signs answered, one START: the title's menu from about 24 s), eye dumps every Step s with the
# real head pose straight ahead and turned 20 degrees in turn (re\simpose.py), from From to To s; yawlog.txt beside
# the dumps says which dump had which pose. For anything that must stay put in the room when the head turns (the HUD's
# screen, the title's logo): compare a straight and a turned pair, and the left eye against the right.
param([int]$From = 24, [int]$To = 34, [int]$Step = 2,
      [string]$Out = "$env:TEMP\icovr_eyes")
$pad = 'F:\rpsc3\source\plans\tools\icovr-title.txt'
New-Item -ItemType Directory -Force $Out | Out-Null
python F:\rpsc3\source\plans\tools\re\simpose.py 0 | Out-Null
$id = & F:\rpsc3\source\plans\tools\icovr_sim.ps1 -Env @{ICO_VR_DUMP_DIR = $Out} -GameArgs "--pad-script $pad"
$t0 = Get-Date
Start-Sleep $From
$yaw = 0
while (((Get-Date) - $t0).TotalSeconds -lt $To) {
    python F:\rpsc3\source\plans\tools\re\simpose.py $yaw | Out-Null
    Start-Sleep -Milliseconds 700
    Set-Content -Path "$Out\dump" -Value '1' -Encoding ascii
    $s = [int]((Get-Date) - $t0).TotalSeconds
    Add-Content -Path "$Out\yawlog.txt" -Value "$s s yaw $yaw"
    Start-Sleep -Milliseconds ($Step * 1000 - 700)
    $yaw = 20 - $yaw
}
Stop-Process -Id $id -Force
python F:\rpsc3\source\plans\tools\re\simpose.py 0 | Out-Null
