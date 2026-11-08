@echo off
rem avx2build.cmd: a separate test build of PGR4 in build\avx2 with /arch:AVX2 and floating-point contraction off (the game's maths
rem unchanged), to measure whether it shortens the game's CPU frame. Never replaces build\rel.
call F:\rpsc3\source\plans\tools\pgr4\env.cmd
if not exist H:\PGR4-ReGPU\build\avx2\build.ninja (
  cmake -G Ninja -S H:\PGR4-ReGPU -B H:\PGR4-ReGPU\build\avx2 -DCMAKE_BUILD_TYPE=Release ^
    -DCMAKE_C_COMPILER=H:/tools/clang+llvm-20.1.8-x86_64-pc-windows-msvc/bin/clang-cl.exe ^
    -DCMAKE_CXX_COMPILER=H:/tools/clang+llvm-20.1.8-x86_64-pc-windows-msvc/bin/clang-cl.exe ^
    "-DCMAKE_C_FLAGS=/DWIN32 /D_WINDOWS /arch:AVX2 -ffp-contract=off" ^
    "-DCMAKE_CXX_FLAGS=/DWIN32 /D_WINDOWS /EHsc /arch:AVX2 -ffp-contract=off" || exit /b 1
)
ninja -k 0 -C H:\PGR4-ReGPU\build\avx2 pgr4
