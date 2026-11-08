# threadcpu.ps1 [SECONDS=20] [TOP=14]: the running pgr4's threads by CPU over the window (seconds of CPU, % of a core),
# each with its description (guest N name, gpu draw piece worker, vr frames...). For telling a slow-mode boot's hot thread.
# Times from Win32_Thread (kernel + user, milliseconds); .NET's ProcessThread.TotalProcessorTime missed hot threads.
param([double]$Seconds = 20, [int]$Top = 14)
$sig = @'
[DllImport("kernel32.dll")] public static extern IntPtr OpenThread(uint access, bool inherit, uint id);
[DllImport("kernel32.dll")] public static extern int GetThreadDescription(IntPtr h, out IntPtr desc);
[DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
[DllImport("kernel32.dll")] public static extern IntPtr LocalFree(IntPtr p);
'@
$k = Add-Type -MemberDefinition $sig -Name K32 -Namespace ThreadCpu -PassThru
$pid4 = (Get-Process pgr4 -ErrorAction Stop).Id
function Snapshot {
    $m = @{}
    foreach ($t in (Get-CimInstance Win32_Thread -Filter "ProcessHandle='$pid4'")) { $m[[int]$t.Handle] = ([double]$t.KernelModeTime + [double]$t.UserModeTime) / 1000.0 } # (ms)
    return $m
}
$a = Snapshot
Start-Sleep -Seconds $Seconds
$b = Snapshot
$rows = foreach ($id in $b.Keys) {
    $d = $b[$id] - $(if ($a.ContainsKey($id)) { $a[$id] } else { 0 })
    if ($d -gt 0.05) {
        $name = ''
        $h = $k::OpenThread(0x0040, $false, [uint32]$id) # THREAD_QUERY_LIMITED_INFORMATION
        if ($h -ne [IntPtr]::Zero) {
            $p = [IntPtr]::Zero
            if ($k::GetThreadDescription($h, [ref]$p) -ge 0 -and $p -ne [IntPtr]::Zero) { $name = [Runtime.InteropServices.Marshal]::PtrToStringUni($p); [void]$k::LocalFree($p) }
            [void]$k::CloseHandle($h)
        }
        [pscustomobject]@{ id = $id; cpu_s = [math]::Round($d, 2); core_pct = [math]::Round(100 * $d / $Seconds, 0); name = $name }
    }
}
$total = ($rows | Measure-Object cpu_s -Sum).Sum
"pgr4 threads over $Seconds s: total {0:N1} core-seconds ({1:N1} cores)" -f $total, ($total / $Seconds)
$rows | Sort-Object cpu_s -Descending | Select-Object -First $Top | ForEach-Object { "   {0,6}  {1,6:N2} s  {2,3}%  {3}" -f $_.id, $_.cpu_s, $_.core_pct, $_.name }
