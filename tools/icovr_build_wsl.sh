#!/bin/bash
# WSL side of icovr_build.sh: sync, configure once, build, copy to H:\ico-pc\dist\x64.
set -e
T="${*:-ico_pc}"
rsync -a --delete --exclude=.git --exclude=build-host --exclude=tools/toolchain --exclude=.venv --exclude=dist /mnt/h/ico-pc/ /root/ico-pc/
cd /root/ico-pc
export PATH=/root/ico-pc/tools/toolchain/cmake/bin:/root/ico-pc/.venv/bin:$PATH
if [ ! -f build-host/win-x64/build.ninja ]; then
  cmake --preset win-x64 -DICO_LINK_EXE=ON >/tmp/icovr_cfg.log 2>&1 || { tail -30 /tmp/icovr_cfg.log; exit 1; }
fi
set +e
cmake --build build-host/win-x64 --target $T >/tmp/icovr_build.log 2>&1
rc=$?
set -e
grep -E 'error|FAILED' /tmp/icovr_build.log | head -40
if [ $rc -ne 0 ]; then echo "BUILD_FAILED rc=$rc"; tail -5 /tmp/icovr_build.log; exit 1; fi
cp build-host/win-x64/ico_pc.exe /mnt/h/ico-pc/dist/x64/ico_pc_x64.exe
cp build-host/win-x64/ico_pc.map /mnt/h/ico-pc/dist/x64/ico_pc_x64.map
cp build-host/win-x64/SDL3.dll /mnt/h/ico-pc/dist/x64/SDL3.dll
echo BUILD_OK
