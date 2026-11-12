"""icovr_release.py TAG NOTES.md ZIP...: a draft release of hookmanuk/ico-pc for an existing tag (pushed first), with
the notes file as its body and the zips as assets, through GitHub's REST API with the token git's credential helper
holds for github.com. Matt presses Publish. Prints the release's page and each asset's size as GitHub reports it."""
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
        return json.load(r)


body = open(notes, encoding='utf-8').read()
rel = call('https://api.github.com/repos/%s/releases' % REPO,
           json.dumps({'tag_name': tag, 'name': 'ICO VR ' + tag, 'body': body, 'draft': True,
                       'prerelease': False}).encode())
print('draft release', rel['id'], rel['html_url'])
up = rel['upload_url'].split('{')[0]
for z in zips:
    name = os.path.basename(z)
    a = call(up + '?name=' + urllib.parse.quote(name), open(z, 'rb').read(), 'application/zip')
    print(' asset', a['name'], a['size'], 'local', os.path.getsize(z), a['state'])
