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
  (perspective-correct attributes; STQ / w').
- **Reflections** (pool.c/puddle.c rd_push_camera scopes, VU draws with pictureW != 0): the reflection camera keeps
  the frame camera's view (the mirror is in the model), its screen S_r is S scaled about 2048, so its eyes are
  K D_v K^-1 with K = S_r S^-1 and its own depth row in vrClip. The presenter replays a blended copy of the frame, so
  the scope is found in the ring frame with the same number (rd__vr_picture_camera, matched by list and picture).
  The pool grids' STs (RdGridSt, made on the CPU from the camera's screen position) move by the eye's screen move
  times sx/sy (0.8 for REFLECT) in vu_grid.hlsl (VuCB qword 20 in VR); the puddle ripples (RD_SCREEN_ST_SHIFT) the
  same in sprite_stq_vertex (DrawCB.vr.yz). rd_vis keeps every reflection draw in VR (the eyes see past its picture).
  Before: vertical streaks (the eye's lookup past the camera's reflection) and a grey patch in one eye.
- **Culling.** gsb_ClipBox keeps every box (returns 2: drawn with the clipping program) under VR; freeCamera's
  behind-eye rule on for every VU draw. The cutscene cameras' sets end where they did not look: below them is the
  fog's colour (pixels nothing drew), not a cull.
- Dev switches: ICO_VR_TEST_EYE1=<units> (eye 1 moved), ICO_VR_TEST_TINT=1 (right eye red in the present blit),
  ICO_VR_TEST_GAMEFOV=1 (both eyes the camera's own picture: compare with flat), ICO_VR_COPY_WAIT=1, ICO_VR_SCALE.

## Findings (2026-11-11 night)

- **The eyes came out identical** while the VU pre-pass was on: it evaluates each vertex once into records the draws
  read. VR turns it off (ICO_RD_VU_PREPASS=0; set with `_putenv_s`, not SDL_setenv_unsafe, which the CRT's getenv
  does not see).
- **A floor missing in the right eye only** (stage 3, low camera): the scissor programs' trivial reject used clip
  flags through G D G^-1 with G = (+0x1C0 projection) S^-1, which is not what rows 20..23 hold. Now the flags come
  from the eye's own GS position (vrClip: a 2048-pixel guard band, the camera's near/far). Also every packet goes
  through the clipping program in VR (RegistPacket.c), and gsb_ClipBox culls nothing.
- **The HUD**: list 11/12 screen prims that are not the camera's and do not read the frame's own targets (copies,
  fades over the picture: ds.screenCopy, texCrop, RD_TEXKIND_TARGET; a bounding-box test alone failed on strip-drawn
  full-screen copies) and the port's overlay/deferred text (rd__overlay_draw) are DrawCB.vr.x 2: their place in the
  target's frame mapped onto a 2 m wide 4:3 screen 2 m before the recentred seat (vrHud: frame uv -> eye uv).
- **Flat pictures**: a movie, a frame without camera, or one without mesh/skinned/grid draws (the pause screen, boot
  signs, title) are drawn in a 4:3 box of the left eye's image and shown on a 3 m quad layer 2.6 m before the seat.
- **Dashed coloured rows** in the OpenXR Simulator's preview are the simulator's: the eye output and the swapchain
  image as the runtime gets it (read back before release) are clean; RPCS3's older simulator captures do not show
  them, the port's path does whatever the write (copy or blit, one or two swapchains).
- **SteamVR null headset cannot test Vulkan**: xrGetVulkanGraphicsDeviceKHR returns XR_ERROR_RUNTIME_FAILURE (no
  adapter) and xrCreateSession XR_ERROR_VALIDATION_FAILURE. The session on SteamVR needs Matt's headset.
- **Pacing**: the token's alpha is the frame's predicted display time (xrConvertTimeToWin32PerformanceCounterKHR ->
  SDL ticks) less its smoothed lead over xrWaitFrame's return: motion steps 0.333 ticks a frame at 90 Hz, sd 0.009,
  4 irregular of 1200 (ICO_VR_ALPHALOG).
- Shadow volumes: the frame camera's (RD_SHADOW_FRAME_CAMERA) take D_v; their inc/dec split is the camera's winding
  (an eye far from the camera could see a near-edge-on face the other way: thin streaks at worst; two-sided stencil
  would need the strips' parity, not done).
- Desktop: the window mirrors the left eye (rhi_vr_mirror_blit). F8 recentres (SteamVR's reset view too).

## Results

- 2026-11-11 simulator 2880x2880/eye, opening cutscene: 90.0 FPS, 1% low 81.5, 0% late, new pictures 100%; GPU 2.5
  ms a picture (both eyes), render thread CPU ~2 ms. The headset loop: wait frame ~7.7 ms, picture 1.3, end 2.1.
- Walking in the first hall (icovr-walk.txt, no cull, every packet clipped): 90.0 FPS, 1% low 82, 0% late; GPU 1.5
  ms a picture, render thread 3.4 ms (walk 2.5, interpolation 0.7).

## Open

- Node-flag-2 parts on the 500 unit screen (+0x640: D_v uses the frame's S), the particle extent scale: check per
  eye. Puddle ripples (RD_SCREEN_ST_SHIFT) are untested: no stage start showed one.
- Shadow volume per-eye winding (above).
- Matt's headset test through SteamVR (the session there is unverified: the null headset cannot make one).
