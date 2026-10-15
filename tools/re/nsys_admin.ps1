# nsys_admin.ps1 ARGS...: runs tools/re/nsys_run.sh elevated (UAC prompt); its output goes to tools/re/nsys_admin.log
$S = 'F:/rpsc3/source/plans/tools/re'
$cmd = "cd '" + $S + "' && sh nsys_run.sh " + ($args -join ' ') + " > nsys_admin.log 2>&1"
Start-Process -Verb RunAs -FilePath 'C:\Program Files\Git\usr\bin\sh.exe' -ArgumentList @('-l', '-c', ('"' + $cmd + '"'))
