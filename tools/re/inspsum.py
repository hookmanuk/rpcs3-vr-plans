"""inspsum.py [CAPTURE.jsonl] [BLOCK]: one line per draw of an inspector capture (default: the newest in
$TEMP/rpcs3-vrprofile/insp): draw, vertex program, depth test, textures, eye classification and the 4 rows of the
constant block (default c[32]) rounded, so the camera, HUD and fixed-depth draws can be told apart."""
import sys, os, glob, json
W = os.path.join(os.environ['TEMP'], 'rpcs3-vrprofile', 'insp')
path = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] != '-' else max(glob.glob(W + '/*_stereo.jsonl'), key=os.path.getmtime)
blk = int(sys.argv[2]) if len(sys.argv) > 2 else 32
print(path)
for line in open(path, encoding='utf8'):
    d = json.loads(line)
    if d.get('type') != 'draw': continue
    c = {k['c']: k['f'] for k in d.get('constants', [])}
    rows = [c.get(blk + i) for i in range(4)]
    m = ' | '.join(' '.join('%.3g' % v for v in r) if r else '-' for r in rows)
    tex = ','.join('%dx%d' % (t['width'], t['height']) for t in d.get('textures', []))
    print('%3d vp %-16s %s n%-5d %-9s %-18s %s' % (d['draw'], d['vp_ucode_hash'], 'D' if d['state']['depth_test'] else '-',
          d['vertex_draw_count'], d.get('eye', ''), tex[:18], m))
