"""package_release.py [OUT_DIR]: build the VR release zip from rpcs3/bin, laid out like the CI package.

Mirrors .ci/deploy-windows.sh (the CI zips bin/* after a clean build): the git-tracked bin/ content, the build
outputs (rpcs3.exe, Qt/FFmpeg/OpenCV/OpenXR DLLs, qt6/), and the files the CI fetches at packaging time
(SDL controller database, rpcs3.net compatibility and config databases, RPCS3 translations). Only the shipped
VR games' profiles and patches are in bin/ (the rest live in vr-non-working/). Nothing personal is included:
no config/, dev_*, games, caches, savestates, screenshots, logs or the community patch.yml.
"""
import io, json, os, re, subprocess, sys, urllib.request, zipfile

SRC = r'F:\rpsc3\source\rpcs3'
BIN = os.path.join(SRC, 'bin')
OUT = sys.argv[1] if len(sys.argv) > 1 else r'F:\rpsc3\source\release'

# Build outputs next to rpcs3.exe (not in git). The CI removes rpcs3.exp/.lib/.pdb and vc_redist.
BUILD_FILES = ['rpcs3.exe', 'openxr_loader.dll', 'opencv_world4140.dll',
               'avcodec-61.dll', 'avformat-61.dll', 'avutil-59.dll', 'swresample-5.dll', 'swscale-8.dll']
BUILD_GLOBS = [r'^Qt6[A-Za-z]+\.dll$']
BUILD_DIRS = ['qt6']


def fetch(url):
    req = urllib.request.Request(url, headers={'User-Agent': 'rpcs3-vr-package'})
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read()


def check_vr_number(base, vr):
    """The VR number counts every release and never restarts, also not after merging a newer upstream version
    (v0.0.42-vr7, then v0.0.43-vr8). Stops if a new version's number is not above every released tag's; rebuilding
    an already tagged version is allowed. Uses the tags of the SRC checkout."""
    number = re.fullmatch(r'vr(\d+)', vr)
    if not number:
        sys.exit(f'RPCS3_VR_VERSION "{vr}" is not vrN')
    tags = subprocess.run(['git', '-C', SRC, 'tag', '--list', 'v*-vr*'], capture_output=True, text=True, check=True).stdout.split()
    released = [int(m.group(1)) for m in (re.fullmatch(r'v\d+\.\d+\.\d+-vr(\d+)', t) for t in tags) if m]
    if f'v{base}-{vr}' in tags or not released:
        return
    latest = max(released)
    if int(number.group(1)) <= latest:
        sys.exit(f'RPCS3_VR_VERSION is {vr}, but vr{latest} is already released: the VR number never restarts, so this '
                 f'release is vr{latest + 1} (rpcs3/rpcs3_vr_version.h)')
    if int(number.group(1)) > latest + 1:
        print(f'warning: {vr} skips numbers after the latest tag, vr{latest} (are all tags fetched?)')


def main():
    commit = re.search(r'RPCS3_GIT_VERSION "([^"]+)"', open(os.path.join(SRC, 'rpcs3', 'git-version.h')).read()).group(1)
    ver_src = open(os.path.join(SRC, 'rpcs3', 'rpcs3_version.cpp')).read()
    base = '.'.join(re.search(r'utils::version version\{ (\d+), (\d+), (\d+),', ver_src).groups())
    # RPCS3_VR_VERSION lives in rpcs3_vr_version.h since the merge-footprint restructuring (in rpcs3_version.cpp before).
    vr_header = os.path.join(SRC, 'rpcs3', 'rpcs3_vr_version.h')
    vr_src = open(vr_header).read() if os.path.exists(vr_header) else ver_src
    vr = re.search(r'#define RPCS3_VR_VERSION "([^"]+)"', vr_src).group(1)
    check_vr_number(base, vr)
    version = f'v{base}-{vr}-{commit}'  # the GitHub release tag is v{base}-{vr}
    files = {}  # zip path -> bytes or source path

    # Git-tracked bin/ content (GuiConfigs, Icons, fonts, test, vr_profiles, patches), as a CI checkout has it.
    tracked = subprocess.run(['git', '-C', SRC, 'ls-files', 'bin'], capture_output=True, text=True, check=True).stdout.split('\n')
    for rel in filter(None, tracked):
        files[rel[len('bin/'):]] = os.path.join(SRC, rel.replace('/', os.sep))

    for name in os.listdir(BIN):
        if name in BUILD_FILES or any(re.match(g, name) for g in BUILD_GLOBS):
            files[name] = os.path.join(BIN, name)
    for d in BUILD_DIRS:
        for root, _, names in os.walk(os.path.join(BIN, d)):
            for n in names:
                p = os.path.join(root, n)
                files[os.path.relpath(p, BIN).replace(os.sep, '/')] = p
    missing = [f for f in BUILD_FILES if f not in files]
    if missing:
        sys.exit(f'missing build outputs: {missing}')

    # What the CI adds at packaging time.
    files['config/input_configs/gamecontrollerdb.txt'] = fetch('https://raw.githubusercontent.com/gabomdq/SDL_GameControllerDB/master/gamecontrollerdb.txt')
    files['GuiConfigs/compat_database.dat'] = fetch('https://rpcs3.net/compatibility?api=v1&export')
    files['GuiConfigs/config_database.dat'] = fetch('https://api.rpcs3.net/config/?api=v1')
    release = json.loads(fetch('https://api.github.com/repos/RPCS3/rpcs3_translations/releases/latest'))
    url = next((a['browser_download_url'] for a in release.get('assets', []) if a['name'] == 'RPCS3-languages.zip'), None)
    if url:
        with zipfile.ZipFile(io.BytesIO(fetch(url))) as z:
            for info in z.infolist():
                if not info.is_dir():
                    files['qt6/translations/' + info.filename] = z.read(info)
    else:
        print('warning: no RPCS3-languages.zip in the latest translations release; packaging without translations')

    # VR fork additions: the games list and settings guide with its screenshots (the deploy scripts copy them
    # too) and the licence.
    files['vr-games.md'] = os.path.join(SRC, 'vr-games.md')
    files['vr-settings.md'] = os.path.join(SRC, 'vr-settings.md')
    shots = os.path.join(SRC, 'docs', 'vr-settings')
    for n in os.listdir(shots):
        files['docs/vr-settings/' + n] = os.path.join(shots, n)
    files['LICENSE'] = os.path.join(SRC, 'LICENSE')

    os.makedirs(OUT, exist_ok=True)
    zip_path = os.path.join(OUT, f'rpcs3-{version}_win64.zip')
    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for arc in sorted(files):
            src = files[arc]
            if isinstance(src, bytes):
                z.writestr(arc, src)
            else:
                z.write(src, arc)
    size = os.path.getsize(zip_path)
    print(f'{zip_path}: {len(files)} files, {size / 1e6:.1f} MB')


if __name__ == '__main__':
    main()
