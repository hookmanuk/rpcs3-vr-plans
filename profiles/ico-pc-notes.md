# ICO PC port (ico-pc, native C port of the PS2 game) - VR fork notes

Repo `H:\ico-pc` (fork hookmanuk/ico-pc of nathanialf/ico-pc), branch `vr`. ROM `H:\ROMs\ico\Ico (USA).bin`
(SCUS-97113, a bare .bin; `iso=` in `dist\x64\ico-pc.ini`). The first start extracts the disc into
`%APPDATA%\ico-pc\ico-pc\ico-ntsc.o2r`.

## Build and run

- Linux-hosted cross build (mingw-gcc 14 from Debian packages, DXC, pinned CMake): WSL Debian 13, clone at
  `/root/ico-pc` (toolchain there, `tools/fetch_toolchain.sh` once). `plans/tools/icovr_build.sh` rsyncs
  `H:\ico-pc` into it, runs ninja on `build-host/win-x64` (configured `--preset win-x64 -DICO_LINK_EXE=ON`) and
  copies `ico_pc.exe` (as `ico_pc_x64.exe`), the map and SDL3.dll into `H:\ico-pc\dist\x64`. A full build is ~70 s.
  Close the game first (the copy fails on a running exe).
- `plans/tools/icovr_sim.ps1 [-Flat] [-Steam] [-Env @{..}] [-GameArgs '--pad-script icovr-gameplay.txt']`: start on
  the OpenXR Simulator (this launch only), SteamVR, or flat. Prints the PID.
- `plans/tools/icovr_dump.sh SECONDS COUNT [ENV=..]` (ICOVR_ARGS for the game's arguments): both eyes of COUNT
  pictures as 2880x2880 PNGs (ICO_VR_DUMP_DIR + a `dump` trigger file, read back on the headset's thread).
- `plans/tools/icovr_shot.ps1 -ProcId N -Title OpenXR -Out x.png`: DPI-aware capture of the simulator preview.
- Pad scripts (the port's own, `port/input/pad_script.h`): `pad-boot.txt` (the repo's, power-on to New Game) and
  `icovr-gameplay.txt` (the same to tick 960, then released: Ico standing in the first hall, stage 3, from ~33 s).
  Deterministic in ticks, not in wall time.
- No WSL distribution existed before this work: Debian was installed with `wsl --install -d Debian` (2026-11-11).

## Flat benchmark (2026-11-11)

RTX 5090 + 9800X3D, the opening cutscene, vsync off, uncapped: 4K 433 FPS avg (1% low 165), 1x 451 (167); identical
per 10 s block: the render thread (walk 1-1.5 ms, interpolation ~1 ms, uploads) sets the rate, the GPU ~1 ms a
picture at 4K. The game itself steps at 30 Hz; every present between ticks is interpolated (rd_interp.c).

## VR design (2026-11-11)

- **Pictures per headset frame.** The port already replays the last game frame at any rate with interpolated
  cameras and objects. The headset's thread (port/platform/vr_openxr.c, Uncharted's loop) does xrWaitFrame,
  xrBeginFrame, locates the views at the predicted display time and hands a token to the game thread; the game
  thread presents once a token (window_present.c vr_presents) at alpha = (token time - the tick's close) / tick, the
  render thread draws the picture with the token's poses, the submit thread publishes it (rd_vr.c), the headset
  thread copies both layers into the runtime's 2-layer swapchain on its own queue (queue 1 of the family, waiting on
  the backend's timeline) and calls xrEndFrame with the poses the picture was drawn with.
- **Multiview.** rhi_vr.h stereo mode: every texture has two layers (uploads write both, readbacks read layer 0),
  every view a 2D array, every pass and pipeline view mask 0b11, copies copy both layers. Shaders are compiled a
  second time with ICO_VR=1 (cmake/IcoShaders.cmake, `<name>_vr`, SPIR-V 1.1): `ICO_T2D/ICO_UV/ICO_LD` (reg.hlsli)
  read the view's layer by `g_viewIndex` (ViewIndex through vk::ext_builtin_input). Off in VR: MSAA, storage dst
  reads, interlock, VU record stores, local read, the VU pre-pass (it evaluated vertices once for both views: the
  eyes came out identical), sprite planes (camera-screen planes), the renderer's frustum/occlusion skip.
- **Eyes.** FrameCB gains vrScreen[2], vrClip[2], vrHud[2], vrMode. D_v = S_eye E_v S^-1: S the frame camera's GS
  screen matrix (RdCamera.proj; X/W = 2048 + zoom x/z, Y down, Z = zn + zf/z, W = z), E_v the head/eye pose (OpenXR
  y up/-z forward -> game y down/+z forward, 100 units a metre: the world is in cm), S_eye the eye's tangents onto
  the 4:3 native frame (512x448 GS px about 2048) with the game's depth row. The eye render is the 4:3 frame stretched
  onto the 2880x2880 eye (sceneWidth/Height, non-uniform scale, full height, full pixel, outputBox the whole eye).
  VU programs apply D_v to h before vu_divide (and G D_v G^-1 to the clip rows, G = the +0x1C0 projection over S);
  screen prims and shadow volumes the game projected through the frame camera (RD_SCREEN_FRAME_CAMERA,
  RD_SHADOW_FRAME_CAMERA: the interpolation's own test) apply D_v to (X, Y, Z, 1) and output a homogeneous position
  (perspective-correct attributes; STQ / w'). Draws under the reflection cameras (pictureW != 0) and 2D are not
  transformed yet.
- **Culling.** gsb_ClipBox keeps every box (returns 2: drawn with the clipping program) under VR; freeCamera's
  behind-eye rule on for every VU draw. The cutscene cameras' sets end where they did not look: below them is the
  fog's colour (pixels nothing drew), not a cull.
- Dev switches: ICO_VR_TEST_EYE1=<units> (eye 1 moved), ICO_VR_TEST_TINT=1 (right eye red in the present blit),
  ICO_VR_TEST_GAMEFOV=1 (both eyes the camera's own picture: compare with flat), ICO_VR_COPY_WAIT=1, ICO_VR_SCALE.

## Results

- 2026-11-11 simulator 2880x2880/eye, opening cutscene: 90.0 FPS, 1% low 81.5, 0% late, new pictures 100%; GPU 2.5
  ms a picture (both eyes), render thread CPU ~2 ms. The headset loop: wait frame ~7.7 ms, picture 1.3, end 2.1.

## Open

- Flat screen (quad layer) for frames without 3D: boot signs, title, menus, FMV, loading.
- HUD/menus over gameplay (subtitles, pause): now drawn identically in both eyes (head-locked at infinity).
- Shadow volumes: the CPU's front/back split is the camera's winding; per-eye winding may differ at silhouettes.
- Reflections (puddle/pool cameras), the particle extent scale, the light shafts and flames: check per eye.
- Horizontal dashed rows seen in the simulator preview only (not in the eye dumps): the preview's scaling?
- SteamVR pacing (null headset only while Matt is away), Matt's headset test.
