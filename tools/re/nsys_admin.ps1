# nsys_admin.ps1 ARGS...: runs tools/re/nsys_run.sh elevated (UAC prompt); its output goes to tools/re/nsys_admin.log.
# An elevated process does not inherit this shell's environment, so the settings nsys_run.sh reads (GPUMET, TRACE, VB,
# NSYS_OUT) are passed on its command line.
$S = 'F:/rpsc3/source/plans/tools/re'
$envs = ''
foreach ($n in 'GPUMET', 'TRACE', 'VB', 'NSYS_OUT') {
  $v = [Environment]::GetEnvironmentVariable($n)
  if ($v) { $envs += "$n='$v' " }
}
$cmd = "cd '" + $S + "' && " + $envs + "sh nsys_run.sh " + ($args -join ' ') + " > nsys_admin.log 2>&1"
Start-Process -Verb RunAs -FilePath 'C:\Program Files\Git\usr\bin\sh.exe' -ArgumentList @('-l', '-c', ('"' + $cmd + '"'))
