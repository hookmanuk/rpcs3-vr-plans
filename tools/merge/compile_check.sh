#!/bin/bash
# Compile-check rpcs3 translation units with GCC and the project's warning flags, without CMake,
# Qt or the submodules (used for 10-multiview-merge-audit.md on an Ubuntu 24.04 container).
#
# Third-party headers come from Ubuntu packages:
#   apt-get install libvulkan-dev glslang-dev libpugixml-dev libyaml-cpp-dev libasmjit-dev libstb-dev \
#     libzstd-dev libavutil-dev libavcodec-dev libavformat-dev libswscale-dev libswresample-dev \
#     libvulkan-memory-allocator-dev libpng-dev zlib1g-dev libglew-dev libgl-dev libx11-dev \
#     libwayland-dev libudev-dev libevdev-dev libcurl4-openssl-dev libssl-dev libwolfssl-dev \
#     libsoundtouch-dev libminiupnpc-dev
# Ubuntu's yaml-cpp and SoundTouch need -fexceptions where they are included (RPCS3's own copies
# do not); the files below get it. Objects land in OUT, so nm can check definitions across them.
#
# usage: compile_check.sh [-r rpcs3-checkout] [-o OUT] file.cpp...    (paths relative to the checkout)
#   parallel: ... | xargs -P4 -n1 tools/merge/compile_check.sh -r ../rpcs3 -o /tmp/cc

ROOT=$(pwd)
OUT=/tmp/rpcs3_compile_check
while [ $# -gt 0 ]; do
	case "$1" in
	-r) ROOT=$(cd "$2" && pwd); shift 2 ;;
	-o) OUT=$2; shift 2 ;;
	*) break ;;
	esac
done
mkdir -p "$OUT"
FLAGS=(-std=gnu++23 -O0 -fno-exceptions -fstack-protector -msse -msse2 -mcx16 -msse4.1 -mavx
	-Wall -Werror=old-style-cast -Werror=sign-compare -Werror=reorder -Werror=return-type
	-Werror=overloaded-virtual -Werror=missing-noreturn -Werror=implicit-fallthrough
	-Wunused-parameter -Wignored-qualifiers -Wredundant-move -Wcast-qual -Wdeprecated-copy
	-Wtautological-compare -Wempty-body -Wredundant-decls -Wstrict-aliasing=1
	-Werror=suggest-override -Wclobbered -Wduplicated-branches -Wduplicated-cond -Wno-class-memaccess
	-DHAVE_VULKAN -DHAVE_X11 -DHAVE_CLOCK_GETTIME -DNDEBUG
	-I"$ROOT" -I"$ROOT/rpcs3" -I"$ROOT/3rdparty" -I/usr/include/stb -I/usr/include/glslang
	-I/usr/include/soundtouch -I/usr/include/miniupnpc)
cd "$ROOT" || exit 1
fail=0
for f in "$@"; do
	o="$OUT/$(echo "$f" | tr '/' '_').o"
	extra=()
	case "$f" in
	*VKOpenXR.cpp) extra=(-Wno-old-style-cast) ;; # as rpcs3/Emu/CMakeLists.txt does
	*rsx_camera_probe.cpp | *System.cpp | *lv2/lv2.cpp) extra=(-fexceptions) ;;
	esac
	if g++ "${FLAGS[@]}" "${extra[@]}" -c "$f" -o "$o" 2> "$o.log"; then
		echo "OK   $f (warnings: $(grep -c 'warning:' "$o.log"))"
	else
		echo "FAIL $f"
		grep -m5 'error' "$o.log"
		fail=1
	fi
done
exit $fail
