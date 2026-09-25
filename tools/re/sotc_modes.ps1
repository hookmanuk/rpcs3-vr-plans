param([int]$Scale = 400, [string[]]$Modes = @('far', 'cull', 'flat'), [string]$Walk = '', [int]$Vblank = 0, [string]$Config = "$env:TEMP\config_BCUS98259.yml.user-600")
# SotC at the start view (or after $Walk keys), desktop, with the GPU profiler:
#   far  = stereo, profile as committed (occlusion_depth_readback: far depth)
#   cull = stereo, the game's own occlusion culling (profile line removed for the run)
#   flat = no stereo
# Uses the user's config copy $env:TEMP\config_BCUS98259.yml.user-600 (Null audio, $Scale%).
# Logs: $env:TEMP\mode_<mode>.log; screenshots: plans/tools/re/mode_<mode>.png
$bin = 'F:\rpsc3\source\rpcs3\bin'
$profile = "$bin\vr_profiles\BCUS98259.shadow.json"
$orig = [IO.File]::ReadAllBytes($profile)
& py -3.13 -c "import re;b=open(r'$Config','rb').read();b=b.replace(b'  Renderer: Cubeb',b'  Renderer: `"Null`"');b=re.sub(rb'  Resolution Scale: \d+',b'  Resolution Scale: $Scale',b);b=re.sub(rb'  Vblank Rate: \d+',b'  Vblank Rate: $Vblank',b) if $Vblank else b;open(r'$bin\config\custom_configs\config_BCUS98259.yml','wb').write(b)"
New-Item -ItemType Directory -Force "$bin\config\input_configs\BCUS98259" | Out-Null
Copy-Item F:\rpsc3\source\plans\tools\keyboard-pad-template.yml "$bin\config\input_configs\BCUS98259\Default.yml"
$env:RPCS3_VR_GPUPROF = '1'
$env:RPCS3_VR_SHOT = Join-Path $env:TEMP 'rpcs3-vrprofile\SHOT'
$sh = 'C:\Program Files\Git\bin\sh.exe'
try {
  foreach ($mode in $Modes) {
    if ($mode -eq 'cull') { & py -3.13 -c "p=r'$profile';s=open(p,'rb').read();open(p,'wb').write(b''.join(l for l in s.splitlines(True) if b'occlusion_depth_readback' not in l))" }
    else { [IO.File]::WriteAllBytes($profile, $orig) }
    $args2 = @{ Samples = 2 }
    if ($mode -ne 'flat') { $args2.Probe = 'render=1' }
    if ($Walk) { $args2.Walk = $Walk }
    "=== $mode"
    & F:\rpsc3\source\plans\tools\re\perfrun.ps1 @args2
    Start-Sleep 10
    & $sh /f/rpsc3/source/plans/tools/re/lastshot.sh "mode_$mode"
    Copy-Item "$bin\log\RPCS3.log" "$env:TEMP\mode_$mode.log"
  }
}
finally {
  [IO.File]::WriteAllBytes($profile, $orig)
  $env:RPCS3_VR_GPUPROF = $null
}
