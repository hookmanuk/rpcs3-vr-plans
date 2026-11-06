# Project Gotham Racing 4 (Xbox 360 4D5307F9): PCVR port on ReGPU

Matt's fork of zer0ducksgiven/PGR4-ReGPU: `H:\PGR4-ReGPU`, branch `vr` (local, not pushed). A XenonRecomp port on ReGPU
(D3D12, vendored in `thirdparty/ReGPU`). Not RPCS3.

## Build and run

- Inputs: `H:\ROMs\pgr4` (the disc ISO and Title Update #2, `TU_16L61VP_0000004000000.00000000000G1`, sha256 9980cf82...d9b8:
  the recompile config, jump tables and hooks are at the updated addresses, so the update is required). Extracted to
  `game\` and `out\tu2`; `sh tools/recomp.sh` makes `out\ppc`.
- Local SDKs (git-ignored): `thirdparty\sdl3` (3.4.20 VC), `thirdparty\ffmpeg` (BtbN n8.1 LGPL shared, the same DLL versions
  upstream ships), `thirdparty\fidelityfx` (copied from `H:\uncharted_pc\gpu\third_party\fsr-vulkan\upstream\ffx-2.3.0`).
- Compiler: clang 20.1.8 at `H:\tools`. `plans/tools/pgr4/env.cmd ninja -C H:\PGR4-ReGPU\build\rel pgr4` (from PowerShell's
  `cmd /c`: Bash with MSYS2_ARG_CONV_EXCL leaves `//c` as is and cmd hangs). `build\tools` was configured from a small wrapper
  CMake project (`add_subdirectory(thirdparty/XenonRecomp xenonrecomp)`) because the root CMake refuses an empty `out\ppc`.

## Test tools (`plans/tools/pgr4`)

- `pg.sh start|stop|<regpuctl command>`: the debug server, with the test user folder `H:\PGR4-ReGPU\out\testuser` (never Matt's
  `E:\Documents\pgr4`; his profile is backed up in `H:\backups\pgr4-profiles-*`). The log is `thirdparty\ReGPU\out\live.log`.
- `vrrace.sh EYE [NAME=VALUE...]`: VR on the OpenXR Simulator, driven to the St Petersburg race grid (Arcade, chapter 1, event 1).
  `flatrace.sh RES`: the same flat. `SIMXR_HZ=240` shows the headroom above the simulator's 90 Hz.
- `vrperf.py SECONDS LABEL`: average FPS, 1% low, into `perf.log`. `sweep.sh`: a list of configurations.
- `tintfind.py X Y`: which pixel shader draws a pixel. `eyecmp.py`: left against right of every resolved image after a capture.
- `tweaks.py OUT`: dumps the game's named settings. `strxref.py`, `objxref.py`, `dis.py`: strings, statics and functions in `out\ppc`.

## How the VR works

- `thirdparty/ReGPU/src/vr/vr.cpp`: OpenXR on the game's D3D12 device (`REGPU_VR=1`, `REGPU_VR_EYE=WxH`). Loader DLL beside the exe.
- One pass, both eyes: EDRAM surfaces have two layers; a stereo draw has 2 instances, the vertex shader writes
  `SV_RenderTargetArrayIndex` = instance and multiplies its **final clip position** by the eye's matrix (`hlsl.cpp VrPatch`). Game
  shaders are untouched. FXC SM 5.1 can do this (no SV_ViewID there).
- Eye matrix = eye projection x head pose x inverse(game projection), the game's projection read per draw from its view-projection
  in c4-c7 (`vr::ProjectionFromViewProjection`). z keeps the draw's own near and far. Zoom with speed is cancelled by this.
- Stereo passes: pitch 1280 always; others once a draw samples a stereo resolve (the bloom chain); pitch <= 128 stay one image, read
  from the left eye (exposure must agree between the eyes). Resolves keep a right-eye twin; `tbias.y` holds both descriptors.
- Flat draws (w = 1) that don't sample the frame go to the HUD box (`vr::HudMatrix`, 2 m away, 2.4 m wide), scissor as clip distances.
- Game side: `src/hooks/vr.cpp`. `sub_822C0638(camera)` is each camera's vertical field of view (`PGR4_VR_FOV` scales it).

## Game facts found

- The executable keeps its developers' **named settings**: 2466 objects (bool `kind 1`, int 2, float 3), value at +32, at fixed
  addresses. Listed by `tweaks.py`. `Camera.Shake.Enable` 82C94460 (read by sub_827DD588), `Camera.PassingShake.Enable` 82AB4638
  (sub_824BA960), `Camera.Chase.SlideTiltEnable` 82C941FC, `Wheel.DrivingEffects.*` 82A81F08.. 82A928FC.
- Strings: file offset - 0x3000 + 0x82000000 in `out/tu2/default_tu2.xex`.
- Camera: `sub_822C2410` builds the projection (camera +432/+436 near/far, +440 aspect), `sub_82322480` sets the matrices,
  `sub_824DC5E8` loops the viewports (stride 21008). Main-view projection in the race: sx 1.0003, sy 1.7783 (90 x 59 degrees), near 0.05,
  reversed depth. Game units are metres. A view struct sits at 4013DA50 (forward, right, up, eye).
- Force feedback: `sub_823105F0(wheel, six floats)` writes the effects from `Wheel.DrivingEffects.Feedback.*`, fed by `sub_822DCB18`
  (zeros unless car+7573 bit 0x40 is set and 0x80 clear and a global allows it), physics in `sub_822E2880`.

## Frame budget (measurements in `plans/tools/pgr4/perf.log`, DLSS off, simulator, race grid / driving)

- Flat 5120x3240 (same pixels as VR 2880 x2): 137 / 200 FPS. VR 2880 per eye, 240 Hz simulator: 84 / 126. VR 5120 per eye: 65 / 84.
- VR 800x800 per eye: GPU still 10.3 ms on the grid: most of the frame does not scale with pixels.
