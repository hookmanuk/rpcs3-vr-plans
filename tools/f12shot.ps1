param([Parameter(Mandatory)][string]$TitleId, [string]$Keys = '', [int]$GapMs = 2500, [string]$Out = '')
# Optionally press keys, then take RPCS3's own F12 screenshot (eye 0 only, but works in exclusive
# fullscreen where window captures go stale). Prints the file; -Out also saves a 1280-wide copy.
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$dir = "F:\rpsc3\source\rpcs3\bin\screenshots\$TitleId"
if ($Keys) { & "$here\keys.ps1" -Keys $Keys -GapMs $GapMs | Out-Null }
$before = (Get-ChildItem $dir -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1).FullName
& "$here\keys.ps1" -Keys 'F12' -GapMs 1200 | Out-Null
$f = Get-ChildItem $dir -File | Sort-Object LastWriteTime | Select-Object -Last 1
if ($f.FullName -eq $before) { Start-Sleep 1; $f = Get-ChildItem $dir -File | Sort-Object LastWriteTime | Select-Object -Last 1 }
if ($Out) {
	Add-Type -AssemblyName System.Drawing
	$img = $null; for ($i = 0; $i -lt 20 -and -not $img; $i++) { try { $img = [Drawing.Image]::FromFile($f.FullName) } catch { Start-Sleep -Milliseconds 500 } }
	$s = New-Object Drawing.Bitmap $img, 1280, ([int](1280 * $img.Height / $img.Width)); $s.Save($Out); $img.Dispose(); $s.Dispose()
}
$f.FullName
