"""icovr_release_drop.py TAG NAME_PART NOTES.md: on the draft release of hookmanuk/ico-pc for TAG, deletes the assets
whose name holds NAME_PART and sets the body from the notes file. For a draft only (it refuses a published release).
The token is git's credential helper's for github.com."""
import json, subprocess, sys, urllib.request

REPO = 'hookmanuk/ico-pc'
tag, part, notes = sys.argv[1], sys.argv[2], sys.argv[3]
cred = subprocess.run(['git', 'credential', 'fill'], input='protocol=https\nhost=github.com\n\n', capture_output=True,
                      text=True).stdout
token = next(l.split('=', 1)[1] for l in cred.splitlines() if l.startswith('password='))


def call(url, data=None, method=None):
    req = urllib.request.Request(url, data=data, method=method or ('POST' if data is not None else 'GET'))
    req.add_header('Authorization', 'Bearer ' + token)
    req.add_header('Accept', 'application/vnd.github+json')
    req.add_header('User-Agent', 'release-script')
    if data is not None:
        req.add_header('Content-Type', 'application/json')
    with urllib.request.urlopen(req) as r:
        raw = r.read()
        return json.loads(raw) if raw else None


rels = call('https://api.github.com/repos/%s/releases?per_page=30' % REPO)
rel = next(r for r in rels if r['tag_name'] == tag)
assert rel['draft'], 'the release is published: not touched'
for a in rel['assets']:
    if part in a['name']:
        call('https://api.github.com/repos/%s/releases/assets/%d' % (REPO, a['id']), method='DELETE')
        print(' deleted', a['name'])
call('https://api.github.com/repos/%s/releases/%d' % (REPO, rel['id']),
     # tag_name with it: a PATCH of a draft without it resets the draft's tag to "untagged-..."
     json.dumps({'tag_name': tag, 'body': open(notes, encoding='utf-8').read()}).encode(), method='PATCH')
rel = call('https://api.github.com/repos/%s/releases/%d' % (REPO, rel['id']))
print('draft', rel['draft'], 'tag', rel['tag_name'], 'assets', [(a['name'], a['size']) for a in rel['assets']])
print('portable in the notes:', 'portable' in rel['body'])
