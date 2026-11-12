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
- Shadow volumes: the frame camera's (RD_SHADOW_FRAME_CAMERA) take D_v. The game's inc/dec lists mix both vertex
  orders, so in VR each triangle is reordered (from the recorded payload) so that its camera winding is its op's and
  the lists are drawn with two-sided stencil (RD_STENCIL_TWO_SIDED_POS: front incr, back decr): the camera's count is
  unchanged, an eye that sees a face the other way counts it the other way. In-run A/B (icovr_ab.sh, trigger file
  `onesided`): one-sided vs two-sided differ by fewer pixels than the same mode 8 s apart. A first version re-read
  the triangles from the mapped upload ring (write-combined): +10 ms render thread a picture (68 FPS); fixed.
- Node flag 2 (camera-locked) parts use +0xC0 (the frame screen) on the NTSC disc, so D_v is right for them; only
  PAL's +0x640 (500 unit screen) would need K D K^-1.
- Desktop: the window mirrors the left eye (rhi_vr_mirror_blit). F8 recentres (SteamVR's reset view too).

## Results

- 2026-11-11 simulator 2880x2880/eye, opening cutscene: 90.0 FPS, 1% low 81.5, 0% late, new pictures 100%; GPU 2.5
  ms a picture (both eyes), render thread CPU ~2 ms. The headset loop: wait frame ~7.7 ms, picture 1.3, end 2.1.
- Walking in the first hall (icovr-walk.txt, no cull, every packet clipped): 90.0 FPS, 1% low 82, 0% late; GPU 1.5
  ms a picture, render thread 3.4 ms (walk 2.5, interpolation 0.7).

- 2026-11-12 (after reflections and two-sided shadows), walk (icovr_rate.sh): 90 Hz 90.0 FPS, 1% low 82.7, 0% late,
  render thread 3.2 ms (walk 2.3), GPU 1.5 ms; 120 Hz 120.0 (1% low 107), 144 Hz 144.0 (126), 180 Hz 180.0 (154),
  all 0% late. Stage 34 (pool) and 36 (sea) at 120 Hz: 120.0 FPS, 0% late, GPU 1.9 / 1.7 ms.
- Head poses (icovr_poses.sh, simpose.py real pose: straight, yaw +-20, pitch 10, roll 15) on stage 3: both eyes
  consistent, nothing cut or following the head.

## Frame pacing and the render thread (2026-11-12)

- **The 1% low was the wrong measure.** The old figure came from the gaps between xrEndFrame returns, which carry each
  picture's own time variance (a 3.5 ms picture then a 4.7 ms one reads as a 9.5 ms frame) though every frame met its
  display slot (0% late, 100% new pictures). The headset report now adds a `display:` line: 1% low by the predicted
  display times, display slots skipped, frames over budget (xrWaitFrame's return to xrEndFrame's past one period) and
  the picture wait's p99; the old figure stays as "submit 1% low". The rd side logs the render thread's time a
  picture, interpolated vs a new game frame's (no spikes at the 30 Hz tick: p99 within 0.5 ms of each other).
- **Not shader compilation**: 0 pipelines created in play (every 10 s window); the disk pipeline cache is warm and the
  start-up set (100 keys) is built before play in ~23 ms.
- **Upload memory**: the upload rings were in the resizable-BAR window (device-local, host-visible): write-combined
  stores across the bus. Host-cached system memory first (vk_memory.c; ICO_RHI_UPLOAD_CACHED=0 the old order): stage
  16 at 120 Hz render thread 6.5 -> 5.0 ms (frames over budget 28 -> 0), walk 3.2 -> 2.4, flat 2.4 -> 1.9; GPU 1.8 ->
  1.9 ms.
- **Still re-present off in VR**: it re-showed 6 of 997 presents (the last head pose's picture: a judder); off in VR,
  which also drops the whole-frame hash every present. The DrawCB cache hash is 8 bytes a step. Stage 16: 5.0 -> 4.3.
- Profiling: `plans/tools/re/sym_sample.py ico_pc_x64.exe render SECONDS H:/ico-pc/dist/x64/ico_pc_x64.syms` (leaf
  samples by the exe's `llvm-nm -n` symbols, static functions included; dump the .syms after a build from WSL with
  `llvm-nm -n build-host/win-x64/ico_pc.exe | grep ' [tT] '`). After the fixes the render thread's profile is flat
  (vuDraw 5%, the rest under 2% each).
- Stage survey before the fixes (icovr_survey.sh 120 40, display metrics): every stage 120.0 FPS with 0 skipped display
  slots; over budget only on 10 (33), 16 (27), 22 (7), 27 (5), 31 (5), 17 (2); render thread 2.6-6.6 ms, GPU
  1.2-2.6 ms.
- After (same survey, the heavy stages): 8, 10, 12, 17, 22, 27, 31 at 0 frames over budget, 16 at 1 of 900; all 0
  skipped slots, display 1% low 118.2-119.8; render thread 3.1-4.4 ms (10: 5.9 -> 4.0, 16: 6.6 -> 4.3, 22: 5.9 ->
  4.0, 27: 5.6 -> 3.4, 31: 6.0 -> 4.4), GPU 1.6-2.3 ms.

- **Flat vs VR look** (icovr_flatcmp.sh: the flat window against the VR eye with ICO_VR_TEST_GAMEFOV=1, same stage
  start): stages 7 (sun patches, bloom), 11 (outdoor haze), 18, 25 (cliff fog), 36 (shadow creature, sea), 38 (forest
  light shafts, glare) match in every effect; the flat's cinematic bars are off in VR by design.

- **~4K per eye** (ICO_VR_SCALE=1.34: 3859x3859, near Matt's headset), stage 38 (the GPU's heaviest) at 120 Hz: 120.0
  FPS, 0 skipped, 0 over budget, display 1% low 118.3; GPU 2.7 -> 4.2 ms a picture (worst 6), render thread 3.5. GPU
  by list: 3 1.2 ms, 2 1.0, 7 0.8, 0 0.4; effects glow 0.5, motion blur 0.3, fog 0.3. The frame moves ~2.4 GB of
  attachment loads/stores a picture (24 passes, each the whole 2-layer target): the next GPU target if needed.

## 2026-11-12: headset feedback (Matt on SteamVR), options, the title

Matt: "this works amazingly well!" The disc is now the European one (`H:\ROMs\ico\Ico (Europe) (En,Fr,De,Es,It).iso`,
SCES-50760; `iso=` in `dist\x64\ico-pc.ini`); `dist\x64\ico_vr.cmd` starts VR (ICO_VR=1, ICO_VR_SCALE).

- **Options in VR** (d46fef585). Display > VR resolution, 50..200 % in tens (`[vr] render_scale`): the scene at that
  percent of the eyes' size, stretched or box-reduced by the present (checked at 50 %: scene 1440x1440 in 2880 eyes).
  The rows VR does not use are hidden (Preset, Resolution, Aspect, Vertical sync, Frame rate, Downsampling, the three
  Upscaling rows, Full-height, Full pixel, CRT). Screen softening and Motion blur default Off with ICO_VR=1 (the
  defaults and the first config.toml). No upscaler in VR: Matt, after the crash below, "Remove all the upscaling
  options. We don't need them anyway."
- **FSR 3.1 in VR: tried, crashed Matt's PC, removed.** Needed: a second FidelityFX context (the right eye's history),
  a FidelityFX patch (its 2D views of an external image take VK_REMAINING_ARRAY_LAYERS, invalid on the two-layer
  stereo images, and only layer 0 is reachable), and motion vectors without the VU pre-pass (VR turns it off): a
  full-screen pass from SCENE's depth, M = W_prev W_cur^-1 with W = Se E V an eye. The first simulator run made both
  contexts (2016 -> 2880) and took the PC down. All reverted. If ever retried: Vulkan validation boot first, Matt away.
- **The title's logo** (a5c717599). Matt: "the title screen ICO logo moves with your head, it should be fixed in front
  of you same as 2d position", then with two headset shots: "the logo is right in front of my face, not 2m away... If
  I turn its on a flat plane that doesnt match the text." The logo is not 2D: models I, C, O, their glows (_f) and
  shadows (_sd) and the darkening plane title_back (port/game/title_logo.c), stage animations that stand just before
  the game's camera. Through the eyes they sat centimetres from the face (left/right disparity 640 px at 900 against
  the far castle's 220 and the menu text's 230). Now reg_DispObj marks those models (rd_vr_hud_mark), the renderer
  keeps the meshes recorded under the mark, and vu_divide (DrawCB.vr.x 4/5) places each vertex by the camera's own 2D
  picture on the HUD's screen (vrHud); title_back is stretched 8x about the screen's middle so it darkens the whole
  view. Simulator, real head pose 0 and 20 degrees: the letters' disparity is the text's (230), one plane.
  Dead ends on the way: the frame-covering list 11 sprites (all untextured fades: a change keyed on them "fixed
  nothing"), the port's overlay (it is on the HUD already), and six boot scripts that missed the title. What reaches
  it: the signs answered to tick 300, one START at 420 (`icovr-title.txt`), dumps from 24 s.
- **The title's attract loop** (06d89e380). Matt: "it keeps restarting ico if I leave it on the menu": op.c tick, the
  title's 10 s idle countdown back to the opening demo. Off with the headset on (ico_video_vr); the flat game keeps it.
- **Anti-aliasing in VR** (e8afc2cdc). MSAA 2x/4x/8x only (supersampling is the VR resolution row above 100 %; a
  saved SSAA choice draws as Off). The backend had MSAA off in the stereo mode because the MSAA shaders read
  Texture2DMS: the resolve (blit.hlsl) and the fog's per-sample depth read (fog_lut.hlsl FOG_MS) now take ICO_T2DMS /
  ICO_MSLD (reg.hlsli), the device enables shaderStorageImageMultisample (SPIR-V ImageMSArray needs it) and the stereo
  mode keeps the sample counts where it exists. Vulkan validation (`ICO_VK_VALIDATION=1`,
  `VK_LAYER_PATH=C:\VulkanSDK\1.4.341.1\Bin`): 0 errors off and at MSAA 4x. MSAA 4x at 2880x2880 eyes, the first hall
  at 120 Hz: 120.0 FPS, display 1% low 119.3, 0 skipped, 0 over budget, GPU 4.3 ms a picture (off at 50 %: 1.6 ms).
- **The mirror's blit** (same commit): the validation boot showed rhi_vr_mirror_blit reading the eyes before the
  list's pending barriers were recorded (their attachment layout, an error every picture); they go first now.
- **Then, the same day** (258e4e4a5). Matt: "VR resolution has no options next to it. If it needs to be a list then
  do 100-200 in 10 increments. remove MSAA, it doesnt work and isnt needed." The row had no value or arrows because
  its option id lies outside the range settings.c steppable() takes (I had never looked at the page). Stepped now,
  100..200 % in tens. MSAA is out of VR again (the row hidden, no sample counts in the stereo mode, the MSAA shaders
  as before); the mirror blit's barrier fix stays. Checked by looking: `tools/icovr-options.txt` opens Options >
  Display from the title (rows: VR resolution, Window mode, Frame rate counter, Video mode); two Rights read 120 %
  and the scene is made again at 3456x3456 in 2880 eyes.
- **VR resolution 50..200 %, Video mode hidden** (6561492b2). Matt: "why have we got video mode there? That seems
  irrelevant? also can you add 50-100 res steps too". Video mode is the European disc's 50/60 Hz switch (the game's
  own tick rate, 25 or 30 a second); hidden in VR, and the boot takes 60 Hz there (sysconf.c ico_boot_video_mode).
  Seven Lefts from 100 %: the scene 2592, 2304, 2016, 1728, 1440 and held.
- **Release v0.11.4-vr-0.1** (Matt: "alter the readme in vr and main branches, add a VR section to the top detailing
  the download release url and vr features. create a v0.11.4-vr-0.1 release like usual"; then "move the ico_vr.cmd up
  a folder, if thats our VR entry point"). README: a VR section at the top on vr and on main. The package is the
  project's own `tools/package_win.sh <label>`, which now also stages `tools/vr/openxr_loader.dll` (Khronos SDK
  1.1.63's prebuilt loader, its licence in NOTICES.txt through tools/notices/manifest.json) beside the program and
  `tools/vr/ico_vr.cmd` at the zip's top beside the README (it starts x64\ico_pc_x64.exe). Run it with
  `plans/tools/icovr_package.sh v0.11.4-vr-0.1`: a clean clone of the vr branch at /root/ico-pc-pkg in WSL (the build
  clone /root/ico-pc is an rsync copy; its toolchain and .venv are linked in), a full clean build of about 15
  minutes, the two zips in `H:\ico-pc\dist\release`. The label parses as 0.11.4.0 for the exe's version
  information. Matt tests the unpacked zip; on his word: push vr and main, tag, draft release with both zips.
- **A test process that would not die**: after a Stop-Process a simulator run stayed as one thread (exiting in the
  driver), kept `ico_pc_x64.exe` locked and stopped the next start at "starting the device". Rename the locked exe
  aside to copy a build in; the process needed an admin end or a reboot.
- Gameplay after all of it (walk, 120 Hz): 120.0 FPS, display 1% low 118.7 to 119.8, 0 slots skipped, 0 frames over
  budget, render thread 2.3 ms, GPU 1.6 ms a picture.
- The camera behind a wall ("Occaisionally the camera is positioned behind a wall I have to lean forwards to see
  through it"): closed by Matt the same evening, "remove the part about the wall being a problem, its not."
- **A fresh start**: a new unpack started through ico_vr.cmd (ICO_VR=1) opens the port's own window "Choose your ICO
  disc image (one of the supported discs)" on the desktop, so the launcher alone is enough (checked on a fresh
  portable unpack on the simulator). The README's VR section says so (cb4fafca8; main 8271b3f5c).
- README, later the same evening (Matt): the VR section also says to turn on Options > Controls > Analogue stick fix
  with a gamepad, and that VR "has only been tested with the European disc" (vr 1d1d95c3e, main 9bbee6639); the zips
  in `H:\ico-pc\dist\release` are built from 1d1d95c3e.
- **Pushed and drafted** (Matt: "ok push the code and release to github"): origin vr 1d1d95c3e (new branch), main
  9bbee6639, tag v0.11.4-vr-0.1 on 1d1d95c3e; a draft release with both zips and the notes
  (`profiles/ico-pc-release-v0.11.4-vr-0.1.md`) made by `tools/icovr_release.py`; he presses Publish. The fork has
  no active workflows (none registered, 0 runs), so the pushes and the tag started none of upstream's CI.
- Open: a first start as the flat game writes config.toml with Screen softening and Motion blur on, and VR then
  starts with them on (the Off default only applies when the first start is in VR). Offered to Matt: VR's own saved
  values for the two; no answer yet.

## Open

- The particle extent scale: check per eye. Puddle ripples (RD_SCREEN_ST_SHIFT) are untested: the puddles are in the
  Waterfall room (stage 22) once drained, a story state no stage start reaches (no save states yet): needs a save. PAL: flag-2 nodes on +0x640.
- Matt's headset test through SteamVR (the session there is unverified: the null headset cannot make one).
