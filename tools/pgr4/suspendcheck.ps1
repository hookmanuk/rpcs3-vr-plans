# suspendcheck.ps1 SECONDS NAME[,NAME...]: suspends those processes (NtSuspendProcess, same user, no admin), runs
# freezecheck for SECONDS on cores 0 and 8, then resumes them whatever happens. Finds which program causes a
# machine-wide freeze without killing anything.
param([double]$Seconds = 15, [string]$Names = "")
$sig = @'
[DllImport("ntdll.dll")] public static extern int NtSuspendProcess(IntPtr h);
[DllImport("ntdll.dll")] public static extern int NtResumeProcess(IntPtr h);
'@
$nt = Add-Type -MemberDefinition $sig -Name Nt -Namespace Freeze -PassThru
$procs = @()
foreach ($n in ($Names -split ',' | Where-Object { $_ })) { $procs += Get-Process -Name $n -ErrorAction SilentlyContinue }
$suspended = @()
foreach ($p in $procs) {
    try { $h = $p.Handle } catch { Write-Output ("cannot open {0} ({1}): {2}" -f $p.ProcessName, $p.Id, $_.Exception.Message); continue }
    $st = $nt::NtSuspendProcess($h)
    if ($st -eq 0) { $suspended += $p } else { Write-Output ("suspend {0} ({1}) failed: 0x{2:x}" -f $p.ProcessName, $p.Id, $st) }
}
Write-Output ("suspended: " + (($suspended | ForEach-Object { "{0}({1})" -f $_.ProcessName, $_.Id }) -join ' '))
try {
    & H:\tools\freezecheck.exe $Seconds 0,8 0.8 | Select-Object -First 3
} finally {
    foreach ($p in $suspended) { [void]$nt::NtResumeProcess($p.Handle) }
    Write-Output ("resumed: " + (($suspended | ForEach-Object { $_.ProcessName }) -join ' '))
}
