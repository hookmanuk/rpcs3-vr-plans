#!/bin/bash
# icovr_build.sh [target...]: build the ICO VR port (H:\ico-pc, branch vr) in WSL Debian and copy the exe
# into H:\ico-pc\dist\x64. See icovr_build_wsl.sh.
MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' wsl -d Debian -u root -- bash /mnt/f/rpsc3/source/plans/tools/icovr_build_wsl.sh "$@"
