"""icovr_release_update.py TAG NOTES.md ZIP...: the draft release of hookmanuk/ico-pc for TAG made again in place: its
body from the notes file, every asset it holds deleted, the zips given uploaded. For a draft only (it refuses a
published release). The token is git's credential helper's for github.com."""
import json, os, subprocess, sys, urllib.request, urllib.parse

REPO = 'hookmanuk/ico-pc'
tag, notes, zips = sys.argv[1], sys.argv[2], sys.argv[3:]
cred = subprocess.run(['git', 'credential', 'fill'], input='protocol=https\nhost=github.com\n\n', capture_output=True,
                      text=True).stdout
token = next(l.split('=', 1)[1] for l in cred.splitlines() if l.startswith('password='))


def call(url, data=None, ctype='application/json', method=None):
    req = urllib.request.Request(url, data=data, method=method or ('POST' if data is not None else 'GET'))
    req.add_header('Authorization', 'Bearer ' + token)
    req.add_header('Accept', 'application/vnd.github+json')
    req.add_header('User-Agent', 'release-script')
    if data is not None:
        req.add_header('Content-Type', ctype)
    with urllib.request.urlopen(req) as r:
        raw = r.read()
        return json.loads(raw) if raw else None


rels = call('https://api.github.com/repos/%s/releases?per_page=30' % REPO)
rel = next(r for r in rels if r['tag_name'] == tag)
assert rel['draft'], 'the release is published: not touched'
for a in rel['assets']:
    call('https://api.github.com/repos/%s/releases/assets/%d' % (REPO, a['id']), method='DELETE')
    print(' deleted', a['name'])
rel = call('https://api.github.com/repos/%s/releases/%d' % (REPO, rel['id']),
           json.dumps({'tag_name': tag, 'body': open(notes, encoding='utf-8').read()}).encode(), method='PATCH')
up = rel['upload_url'].split('{')[0]
for z in zips:
    name = os.path.basename(z)
    a = call(up + '?name=' + urllib.parse.quote(name), open(z, 'rb').read(), 'application/zip')
    print(' asset', a['name'], a['size'], 'local', os.path.getsize(z), a['state'])
rel = call('https://api.github.com/repos/%s/releases/%d' % (REPO, rel['id']))
print('draft', rel['draft'], 'tag', rel['tag_name'], 'assets', [a['name'] for a in rel['assets']], rel['html_url'])
