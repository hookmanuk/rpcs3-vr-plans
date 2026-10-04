"""insplist.py [CAPTURE|-] [BLOCK] [FROM] [TO]: per draw: index, vertex/fragment program, target (address, size), depth
test/blend, textures, eye class and the constant block rows (default c[138]); FROM/TO limit the draw range."""
import sys, os, glob, json
W = os.path.join(os.environ['TEMP'], 'rpcs3-vrprofile', 'insp')
path = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] != '-' else max(glob.glob(W + '/*_stereo.jsonl'), key=os.path.getmtime)
blk = int(sys.argv[2]) if len(sys.argv) > 2 else 138
lo = int(sys.argv[3]) if len(sys.argv) > 3 else 0; hi = int(sys.argv[4]) if len(sys.argv) > 4 else 1 << 30
print(path)
for line in open(path, encoding='utf8'):
    d = json.loads(line)
    if d.get('type') != 'draw' or not lo <= d['draw'] <= hi: continue
    c = {k['c']: k['f'] for k in d.get('constants', [])}
    rows = [c.get(blk + i) for i in range(4)]
    m = ' | '.join(' '.join('%.3g' % v for v in r) if r else '-' for r in rows)
    rt = d['rt']; st = d['state']
    tex = ','.join('%dx%d' % (t['width'], t['height']) for t in d.get('textures', []))
    print('%4d %s fp%-4d rt %08x %dx%d %s%s n%-5d %-22s %-8s %s' % (d['draw'], d['vp_ucode_hash'], d['fp_session_id'], rt['color_addresses'][0], rt['width'], rt['height'],
          'D' if st['depth_test'] else '-', 'B' if st['blend'] else '-', d['vertex_draw_count'], tex[:22], d.get('eye', '')[:8], m))
