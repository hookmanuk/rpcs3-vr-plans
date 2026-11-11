# icovr_sim.ps1 [-Steam] [-Flat] [-Env @{NAME='value'}] [-GameArgs '--pad-script file']: start the ICO VR port (H:\ico-pc\dist\x64) on the OpenXR
# Simulator (F:\rpsc3\source\OpenXR-Simulator, this launch only; the system's runtime is not touched), or with -Steam
# on the system's runtime (SteamVR), or with -Flat without VR. Prints the process id. The log is
# H:\ico-pc\dist\x64\logs\ico-pc.log.
param([switch]$Steam, [switch]$Flat, [hashtable]$Env = @{}, [string]$GameArgs = '')
$exe = 'H:\ico-pc\dist\x64\ico_pc_x64.exe'
$psi = New-Object System.Diagnostics.ProcessStartInfo $exe
$psi.WorkingDirectory = Split-Path $exe
$psi.UseShellExecute = $false
if ($GameArgs) { $psi.Arguments = $GameArgs }
if (-not $Flat) {
    $psi.EnvironmentVariables['ICO_VR'] = '1'
    if (-not $Steam) {
        $psi.EnvironmentVariables['XR_RUNTIME_JSON'] = 'F:\rpsc3\source\OpenXR-Simulator\bin\openxr_simulator.json'
        $psi.EnvironmentVariables['XRFG_DISABLE_OFXR_BRIDGE'] = '1'
    }
}
foreach ($k in $Env.Keys) { $psi.EnvironmentVariables[$k] = [string]$Env[$k] }
$p = [System.Diagnostics.Process]::Start($psi)
$p.Id
