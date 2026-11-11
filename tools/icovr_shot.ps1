# icovr_shot.ps1 -ProcId N -Out file.png [-Title substring]: DPI-aware capture of a top-level window of the process
# (the OpenXR Simulator's preview window lives in the game's process; -Title picks it, else the largest visible one).
# Brings nothing to the front: it copies the window's screen area, so the window must be visible.
param([int]$ProcId, [string]$Out, [string]$Title = '')
Add-Type @"
using System; using System.Text; using System.Runtime.InteropServices;
public class IcoShot {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  public struct RECT { public int L, T, R, B; }
}
"@
[IcoShot]::SetProcessDPIAware() | Out-Null
Add-Type -AssemblyName System.Drawing
$found = New-Object System.Collections.ArrayList
$cb = [IcoShot+EnumProc]{ param($h, $l)
    $p = 0; [IcoShot]::GetWindowThreadProcessId($h, [ref]$p) | Out-Null
    if ($p -eq $ProcId -and [IcoShot]::IsWindowVisible($h)) {
        $sb = New-Object System.Text.StringBuilder 256; [IcoShot]::GetWindowText($h, $sb, 256) | Out-Null
        $r = New-Object IcoShot+RECT; [IcoShot]::GetWindowRect($h, [ref]$r) | Out-Null
        [void]$found.Add([pscustomobject]@{H = $h; T = $sb.ToString(); R = $r; A = ($r.R - $r.L) * ($r.B - $r.T)})
    }
    return $true }
[IcoShot]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null
$found | ForEach-Object { "window '$($_.T)' $($_.R.L),$($_.R.T) $($_.R.R - $_.R.L)x$($_.R.B - $_.R.T)" }
$w = if ($Title) { $found | Where-Object { $_.T -like "*$Title*" } | Select-Object -First 1 } else { $found | Sort-Object A -Descending | Select-Object -First 1 }
if (-not $w) { "no window"; exit 1 }
$r = $w.R; $bw = $r.R - $r.L; $bh = $r.B - $r.T
$bmp = New-Object System.Drawing.Bitmap $bw, $bh
$g = [System.Drawing.Graphics]::FromImage($bmp); $g.CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size)
$bmp.Save($Out); "saved $Out ($($w.T))"
