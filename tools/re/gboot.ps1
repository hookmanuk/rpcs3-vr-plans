# Generic boot for profiling a game: gboot.ps1 -Iso <path> [-Probe ..] [-Audit ..] [-FakeHmd N] [-Desktop]
# Runs with a headset session on the OpenXR Simulator (as simboot.ps1; the system's runtime is not touched).
# -Desktop (or -FakeHmd) keeps the old desktop-only launch (RPCS3_OPENXR=0): everything else goes through the simulator.
param([Parameter(Mandatory)][string]$Iso, [string]$Probe = '', [string]$Audit = '', [int]$FakeHmd = 0, [switch]$Desktop)
$w = "$env:TEMP\rpcs3-vrprofile"
$env:RPCS3_VR_GEN_TRIGGER = "$w\GEN"; $env:RPCS3_VR_MEMDUMP = "$w\g_dump"; $env:RPCS3_VR_POKE = "$w\POKE"; $env:RPCS3_PPU_WATCH_FILE = "$w\WATCH"
if ($env:G_PEEK) { Set-Content "$w\peek.txt" $env:G_PEEK -NoNewline; $env:RPCS3_VR_PEEK = "$w\peek.txt" } else { Remove-Item Env:RPCS3_VR_PEEK -ErrorAction SilentlyContinue }
if ($env:G_TRACE) { $env:RPCS3_PPU_TRACE = $env:G_TRACE; $env:RPCS3_PPU_TRACE_REGS = $env:G_REGS } else { Remove-Item Env:RPCS3_PPU_TRACE -ErrorAction SilentlyContinue }
$a = @{ Game = $Iso }
if ($Desktop -or $FakeHmd) { $a.NoHeadset = $true } else { $env:XR_RUNTIME_JSON = 'F:\rpsc3\source\OpenXR-Simulator\bin\openxr_simulator.json' }
if ($Probe) { $a.Probe = $Probe }
if ($Audit) { $a.Audit = $Audit }
if ($FakeHmd) { $a.FakeHmd = $FakeHmd }
& F:\rpsc3\source\plans\tools\launch.ps1 @a
