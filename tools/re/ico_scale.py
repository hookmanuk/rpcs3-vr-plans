"""ico_scale.py VALUE: set the ICO "Wider view (VR culling)" patch value in patch_config.yml (640 = off)."""
import sys
c = 'F:/rpsc3/source/rpcs3/bin/config/patch_config.yml'
t = open(c, encoding='utf-8', newline='').read()
i = t.index('  Wider view (VR culling):')
k = t.index('Scale: ', i) + len('Scale: ')
e = t.index('\n', k)
open(c, 'w', encoding='utf-8', newline='').write(t[:k] + sys.argv[1] + t[e:])
