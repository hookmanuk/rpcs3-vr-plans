# dumpstacks.ps1 -Dump <file.dmp> [-Out <file.txt>]: every thread's call stack from a memory dump of a hung rpcs3.exe
# (Task Manager > Details > rpcs3.exe > Create memory dump file), read by cdb (WinDbg) with the symbols of the build in
# rpcs3/bin (rpcs3.pdb; the release package's rpcs3.exe must be the same build) and Microsoft's symbol server.
param([Parameter(Mandatory = $true)][string]$Dump, [string]$Out = "")
$cdb = (Get-ChildItem -Path (Get-AppxPackage -Name Microsoft.WinDbg).InstallLocation -Recurse -Filter cdb.exe | Where-Object { $_.FullName -match '\\amd64\\' } | Select-Object -First 1).FullName
if (-not $cdb) { throw "cdb.exe not found (winget install Microsoft.WinDbg)" }
if (-not $Out) { $Out = [IO.Path]::ChangeExtension($Dump, ".stacks.txt") }
$cache = Join-Path $env:LOCALAPPDATA "symcache"
$sym = "srv*$cache*https://msdl.microsoft.com/download/symbols;F:\rpsc3\source\rpcs3\bin"
& $cdb -z $Dump -y $sym -lines -c ".symfix+ $cache; .reload /f rpcs3.exe; ~* k 40; q" 2>&1 | Out-File -Encoding utf8 $Out
Write-Output "stacks: $Out"
