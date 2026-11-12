#!/bin/bash
# icovr_package_wsl.sh LABEL (WSL side; run through icovr_package.sh): the ICO VR fork's Windows release zips with the
# project's own tools/package_win.sh, from a clean clone of H:\ico-pc's vr branch at /root/ico-pc-pkg (the build
# clone /root/ico-pc is an rsync copy with no usable history; its toolchain and .venv are linked in). Writes
# H:\ico-pc\dist\release\ico-pc-LABEL-win.zip and -win-portable.zip. The log: /root/ico-pc-pkg/build-host/pkg-LABEL.log.
set -e
L="$1"
[ -n "$L" ] || { echo "usage: icovr_package_wsl.sh LABEL"; exit 2; }
P=/root/ico-pc-pkg
G="git -c safe.directory=*"
if [ ! -d "$P/.git" ]; then
    $G clone -q --no-checkout /mnt/h/ico-pc "$P"
fi
cd "$P"
$G fetch -q /mnt/h/ico-pc vr
$G checkout -q --detach FETCH_HEAD
echo "packaging $($G rev-parse --short HEAD): $($G log -1 --format=%s)"
[ -e .venv ] || ln -s /root/ico-pc/.venv .venv
[ -e tools/toolchain ] || ln -s /root/ico-pc/tools/toolchain tools/toolchain
export PATH=/root/ico-pc/tools/toolchain/cmake/bin:/root/ico-pc/.venv/bin:$PATH
bash tools/package_win.sh "$L"
mkdir -p /mnt/h/ico-pc/dist/release
cp "dist/ico-pc-$L-win.zip" "dist/ico-pc-$L-win-portable.zip" /mnt/h/ico-pc/dist/release/
ls -la /mnt/h/ico-pc/dist/release/
echo PACKAGE_OK
