# gpuprocs.ps1 SECONDS: which processes use the GPU's 3D engine, by Windows' own counters: mean % per process over the window.
param([int]$Seconds = 6)
$samples = Get-Counter -Counter '\GPU Engine(*engtype_3D)\Utilization Percentage' -SampleInterval 1 -MaxSamples $Seconds -ErrorAction SilentlyContinue
$sum = @{}
foreach ($s in $samples) {
    foreach ($c in $s.CounterSamples) {
        if ($c.InstanceName -match 'pid_(\d+)_') {
            $id = [int]$Matches[1]
            if (-not $sum.ContainsKey($id)) { $sum[$id] = 0.0 }
            $sum[$id] += $c.CookedValue
        }
    }
}
$sum.GetEnumerator() | Where-Object { $_.Value / $Seconds -ge 0.2 } | Sort-Object Value -Descending | ForEach-Object {
    $p = Get-Process -Id $_.Key -ErrorAction SilentlyContinue
    '{0,6:N1}%  {1} ({2})' -f ($_.Value / $Seconds), $(if ($p) { $p.ProcessName } else { '?' }), $_.Key
}
