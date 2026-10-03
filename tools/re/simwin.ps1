param([int]$W = 1920, [int]$H = 1080)
Add-Type @'
using System; using System.Runtime.InteropServices; using System.Text; using System.Collections.Generic;
public class Win {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint p);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int cx, int cy, uint f);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  public struct RECT { public int L, T, R, B; }
  public static List<string> List(uint pid) {
    var o = new List<string>();
    EnumWindows((h, l) => {
      uint p; GetWindowThreadProcessId(h, out p);
      if (p == pid && IsWindowVisible(h)) {
        var sb = new StringBuilder(256); GetWindowText(h, sb, 256); RECT r; GetWindowRect(h, out r);
        o.Add(h.ToInt64() + "|" + sb + "|" + (r.R - r.L) + "x" + (r.B - r.T));
      }
      return true; }, IntPtr.Zero);
    return o;
  }
}
'@
foreach ($p in Get-Process rpcs3 -ErrorAction SilentlyContinue) {
  foreach ($line in [Win]::List([uint32]$p.Id)) {
    $line
    $parts = $line.Split('|')
    if ($parts[1] -match 'Simulator|OpenXR|Preview') { [void][Win]::SetWindowPos([IntPtr][int64]$parts[0], [IntPtr]::Zero, 0, 0, $W, $H, 0x0044); "  -> resized to ${W}x$H" }
  }
}
