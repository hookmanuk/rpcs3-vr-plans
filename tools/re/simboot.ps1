# simboot.ps1 -Iso <game or savestate> [-Probe ..]: boot RPCS3 with a headset session on the OpenXR Simulator
# (F:\rpsc3\source\OpenXR-Simulator, Pimax Dream Air profile, 90 Hz) instead of the system's OpenXR runtime.
# XR_RUNTIME_JSON applies to this launch only; the system's active runtime (Matt's headset) is not touched.
# Drive the simulated head with sim.ps1 (pose, sweep, screenshot of the composited eyes).
param([Parameter(Mandatory)][string]$Iso, [string]$Probe = '')
$env:XR_RUNTIME_JSON = 'F:\rpsc3\source\OpenXR-Simulator\bin\openxr_simulator.json'
& F:\rpsc3\source\plans\tools\launch.ps1 -Game $Iso -Probe $Probe
