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
- `tweaks.py OUT`: dumps the game's named settings. `strxref.py`, `objxref.py`, `ppcdis.py`: strings, statics and functions in `out\ppc`.

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

## HUD and menus: how the game draws them (found 2026-11-07)

- After the final composite (vs e0b5be1feb70ac93, ps 4c40a956f32770b5) the HUD draws on the main surface: vs 380113a5f8092891,
  a6311cf11f1d88eb, da7f034395da2cd9 (fonts, icons), positioned through a projection with no view in c4-c7.
- Menu panels are drawn off screen on another EDRAM base (colour 5002D0), resolved (159EA000, 15D82000), then brought onto the
  frame by one full-screen draw of vs 380113a5 sampling that 1280x720 image. So: only base 0 goes in the box, and a HUD draw sampling a
  frame-sized image goes in whole. A plain full-screen quad (a fade, the pause dim) stays over the whole view.
- vs 9862cfa7a2bc20ec ps 8c8b535864c59f02 through a 4x view (pitch 640, vte 300) is both the clears (no blend) and panel shading (blended).
  The menus clear their red backdrop this way: a pitch test alone missed it (red in the left eye, black in the right).
- Flat draws in the HUD box: `vr::HudMatrix`, 2 m away, 3.2 m wide (REGPU_VR_HUD_DIST, _WIDTH, _DOWN).

- Cone Sprint (Arcade, chapter 2, event 3, Las Vegas): the gate pillars and cones are 3D objects; "Cone Gate", points and the star are flat HUD. All HUD draws have the
  depth test off (depthctl 00700764). The rev counter is drawn translucent: a cone or barrier shows through it, flat and VR alike (compared on the barrier).

## Particles

- Tyre smoke: vs 246d1432b64841aa, ps 701118197155dbca: soft particles. The vertex shader hands its clip position on (o[1] = clip x c224)
  and the pixel shader reads the scene depth there. `VrPatch` makes any such output use the eye's clip position (VrEyeClip).
- b42215dae1817893 reads depth in the vertex shader (t17), patched in `VrRewriteShader` (src/hooks/vr.cpp).
- A resolved image's right-eye copy is made only if a draw read it in the last 120 frames (`rightRead`). The front buffer has no reader
  among the draws: `RendererOnSwapImpl` marks it. (Forgetting that left the right eye up to 2 s old.)

## Force feedback

- The game's setup (sub_82310F60, state 3) continues only when SetEffect's overlapped result says 4 effects were taken. The port
  reported 0, so it set the effects up again every frame with zero inputs. Fixed in `kernel/wheel_ff.cpp`.
- Now sub_822DCB18 passes real physics to sub_823105F0. Blocks: 1 a sine (word 11 magnitude 0-255, word 14 period in ms: chatter, rough
  ground, rumble strips); 2 and 3 springs centred on the slide (outer one negative coefficient, loss of grip); 4 friction by grip.
- `input/wheel.cpp` plays all of them. Tested with PGR4_FAKE_WHEEL=1 PGR4_WHEEL_FF_TRACE=1 PGR4_WHEEL_FF_WORDS=1 (the values change with
  the car), **not on a real wheel**.

## Screen shake

Settings `screen_shake` (launcher switch, PGR4_SCREEN_SHAKE). Proved with Camera.Shake.UseCustom and a large custom amount: direction
roughness 0.08-0.09 with Enable on, 0.0001-0.007 off.

## Frame budget (measurements in `plans/tools/pgr4/perf.log`, DLSS off, simulator, race grid / driving)

- Flat 5120x3240 (same pixels as VR 2880 x2): 137 / 200 FPS. VR 2880 per eye, 240 Hz simulator: 84 / 126. VR 5120 per eye: 65 / 84.
- VR 800x800 per eye: GPU still 10.3 ms on the grid: most of the frame does not scale with pixels.
- Grid, by eye size at 240 Hz: 800 10.3 ms, 1600 10.6, 2880 11.9, 5120 14.1: about 10 ms fixed and 0.08 ms per million pixels.
- 3.5 million vertices a frame (both eyes), 4750 draws: not vertex throughput. The second instance costs 1.5-2.5 ms at 800 per eye. The game alone
  (REGPU_NO_RENDER) reaches 339 FPS, GPU busy 96% even at 800 per eye: per-draw command cost, about 2 us a draw. Flat 720p has the same 7.65 ms.
- No effect: fetch bounds, submit cadence (128, 2048), 7 draw workers. Off-screen pass scale: 3 to 1.5 gives 64 to 70 FPS on the grid.
- The simulator's xrEndFrame costs 1.5-2 ms and spikes to 17-29 ms, which is its 1% lows: pacing needs SteamVR (headset off on 2026-11-06).
- Mirror window: on is faster than off on the simulator (74 against 60 FPS at 5120, not understood): stays on, REGPU_VR_NO_MIRROR=1.
