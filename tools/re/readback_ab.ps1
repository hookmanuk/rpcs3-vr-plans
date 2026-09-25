param([int]$Scale = 300)
# SotC readback A/B: wait (profile without readback_without_wait), no wait, no wait + far-depth fill.
# Desktop stereo at $Scale%, walked onto the shrine stairs; prints FPS and the GPU profile lines (draws/frame).
$bin = 'F:\rpsc3\source\rpcs3\bin'
$profile = "$bin\vr_profiles\BCUS98259.shadow.json"
$orig = [IO.File]::ReadAllBytes($profile)
$cfgsrc = "$env:TEMP\config_BCUS98259.yml.user-600"
& py -3.13 -c "import re,os;b=open(r'$cfgsrc','rb').read();b=b.replace(b'  Renderer: Cubeb',b'  Renderer: `"Null`"');b=re.sub(rb'  Resolution Scale: \d+',b'  Resolution Scale: $Scale',b);open(r'$bin\config\custom_configs\config_BCUS98259.yml','wb').write(b)"
New-Item -ItemType Directory -Force "$bin\config\input_configs\BCUS98259" | Out-Null
Copy-Item F:\rpsc3\source\plans\tools\keyboard-pad-template.yml "$bin\config\input_configs\BCUS98259\Default.yml"
$env:RPCS3_VR_GPUPROF = '1'
try {
  foreach ($mode in 'wait', 'nowait', 'fill') {
    if ($mode -eq 'wait') { & py -3.13 -c "p=r'$profile';s=open(p,'rb').read();open(p,'wb').write(b''.join(l for l in s.splitlines(True) if b'readback_without_wait' not in l))" }
    else { [IO.File]::WriteAllBytes($profile, $orig) }
    $env:RPCS3_VR_READBACK_FILL = if ($mode -eq 'fill') { '1' } else { $null }
    "=== $mode"
    & F:\rpsc3\source\plans\tools\re\perfrun.ps1 -Probe 'render=1' -Samples 1 -Walk "K 2200 500"
    Start-Sleep 12
    foreach ($i in 1..3) { Start-Sleep 2; $t=(Get-Process rpcs3).MainWindowTitle; "  $($t.Substring(0,11))" }
    Copy-Item "$bin\log\RPCS3.log" "$env:TEMP\ab_$mode.log"
    Select-String -Path "$env:TEMP\ab_$mode.log" -Pattern 'GPU profile: \d' | Select-Object -Last 3 | ForEach-Object { '  ' + $_.Line.Substring($_.Line.IndexOf('GPU profile')).Split(';')[0,3,4] -join ';' }
  }
}
finally {
  [IO.File]::WriteAllBytes($profile, $orig)
  $env:RPCS3_VR_READBACK_FILL = $null; $env:RPCS3_VR_GPUPROF = $null
}
