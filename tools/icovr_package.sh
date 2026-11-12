#!/bin/bash
# icovr_package.sh LABEL: the ICO VR fork's Windows release zips (see icovr_package_wsl.sh); H:\ico-pc\dist\release.
MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' wsl -d Debian -u root -- bash /mnt/f/rpsc3/source/plans/tools/icovr_package_wsl.sh "$@"
