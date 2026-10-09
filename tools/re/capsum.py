"""capsum.py: one line per render target of the newest BCUS98114 inspector capture (draws, vertices, car body draws and transform groups, top vertex programs). Edit the title filter for another game."""
import json, sys, glob, os, collections
W = os.path.join(os.environ['TEMP'], 'rpcs3-vrprofile', 'insp')
path = max(glob.glob(W + '/BCUS98114*_stereo.jsonl'), key=os.path.getmtime)
print(path)
body = {'84b91fd2a878d672', '47aeae27a85d4863'}
draws = [json.loads(l) for l in open(path, encoding='utf8') if '"type":"draw"' in l]
print('draws', len(draws))
# per target (in order of first appearance): draws, verts, body draws, distinct transform groups among body draws, programs
order = []
per = collections.OrderedDict()
for d in draws:
    rt = d['rt']; key = (rt['width'], rt['height'], rt['color_addresses'][0], rt['zeta_address'])
    if key not in per:
        per[key] = dict(draws=0, verts=0, body=0, groups=set(), progs=collections.Counter(), first=d['draw'], last=d['draw'])
    p = per[key]; p['draws'] += 1; p['verts'] += d['vertex_draw_count']; p['last'] = d['draw']
    p['progs'][d['vp_ucode_hash']] += 1
    if d['vp_ucode_hash'] in body:
        p['body'] += 1
        c = {k['c']: tuple(k['f']) for k in d.get('constants', [])}
        p['groups'].add(tuple(c.get(i, ()) for i in range(4)))
for key, p in per.items():
    print('%4dx%-4d col %08x z %08x: draws %4d (#%d-#%d) verts %7d body %3d groups %2d  top programs: %s' % (
        key[0], key[1], key[2], key[3], p['draws'], p['first'], p['last'], p['verts'], p['body'], len(p['groups']),
        ' '.join('%s:%d' % (h[:8], n) for h, n in p['progs'].most_common(5))))
