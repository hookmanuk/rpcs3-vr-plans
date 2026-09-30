# cap.ps1 NAME [-Wait S] [-Keys K]: optionally wait / press keys (keys.ps1, real keyboard), then capture the RPCS3
# game window (DPI-aware desktop capture) to re\NAME.png, a 960-wide re\NAMEs.png, and print the FPS.
param([Parameter(Mandatory)][string]$Name, [int]$Wait = 0, [string]$Keys = '')
$re = 'F:\rpsc3\source\plans\tools\re'
if ($Wait) { Start-Sleep $Wait }
if ($Keys) { & F:\rpsc3\source\plans\tools\keys.ps1 -Keys $Keys | Out-Null; Start-Sleep 2 }
& F:\rpsc3\source\plans\tools\keys.ps1 -Shot "$re\$Name.png" | Out-Null
& "$re\fps.ps1" -N 1
python -c "from PIL import Image; im=Image.open(r'$re\$Name.png'); im.resize((960, im.height*960//im.width)).save(r'$re\${Name}s.png')"
