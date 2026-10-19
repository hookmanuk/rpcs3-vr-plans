# DRIVECLUB (PS4, CUSA00003 EU disc, APP_VER 1.28): VR notes

Not RPCS3: the PS4 game runs on DCport (qnfn/Driveclub-Port: the game's x86-64 code natively, a shadPS4 Vulkan
renderer). The VR fork is `H:\dcport-runtime` (bloodborne_pc base), branch `vr` on top of `dcport` (the port's
runtime patch applied). Fork code in `gpu/shadps4/video_core/renderer_vulkan/vr/` (vr_openxr, vr_camera, vr_stereo,
vr_fixes, vr_dev), one-line `// VR` hooks in vk_platform, vk_instance, vk_presenter, vk_rasterizer, vk_pipeline_cache,
vk_temporal_upscaler.h, CMakeLists (shaders). Build: `bash H:/dcport-play/build.sh` (MSYS2 CLANG64; kills bb-probe,
copies openxr_loader.dll). Test root `H:\dcport-play` (data/, user/, scripts below). Play: `H:\dcport-play\Driveclub VR.cmd`.

## True stereo: multiview (default since 2026-10-18; BB_VR_STEREO=mv)

Matt: "You should implement proper multiview rather than distant scenery having no depth." Both eyes are rendered
(fork a4e0688, 069d8c7). The depth reprojection below stays as the fallback (no BB_VR_STEREO).

- Main-view images (2D, 1 sample, the render size or a power-of-two fraction, mip chains included) get a second array
  layer (`vr_multiview.cpp` BackingLayers); layer 0 stays the guest's. A pass whose attachments all have 2 layers draws
  with view mask 0b11 through a multiview twin of its pipeline (made at pipeline creation, spec constant 200 = true).
  A pass that mixes 1- and 2-layer targets draws mono (logged): the G-buffer's scene colour has a 12-level mip chain,
  so mip chains must be stereo.
- Eye offset: the vertex epilogue (hardware VS: vertex or tessellation evaluation; geometry shaders before each
  EmitVertex) adds vr_shift[view] = +-P00 x ipd/2 to clip x when w != 1, only in twins. Exact for a sideways eye;
  full-screen passes (w = 1) stay put. Detecting camera draws by constants failed: world draws carry a premultiplied
  matrix, only full-screen passes bind the 512-byte camera buffer.
- Shaders (`emit_spirv_vr.cpp`): plain 2D images become 2D arrays, every sample/fetch/storage/atomic takes layer =
  gl_ViewIndex (graphics) or push vr_eye (compute); 1-layer images clamp to layer 0. Compute that writes a 2-layer
  storage image runs again with vr_eye = 1 (buffer-only compute once: particles do not advance twice).
- Texture cache copies (CopyImage/CopyMip/CopyDepthStencil) carry layer 1 (the aliases of one memory range at 1 and 12
  levels are kept coherent by copies: without this the right eye was unlit). Per-mip barriers cover both layers.
- Overscan 0.08 tan each side (BB_VR_OVERSCAN): the shift uncovers each eye's outer edge. Pipeline cache: <serial>_mv.
- Measured: disparity scenery 0, gauges 84 px, lower cockpit 153 px (crossed); the right eye's lighting, mirror and
  gauges match the left. Racing at 90 Hz: 90.0 FPS, 1% low 81-83, over a period 0.8-1.2%, late 0-0.1% (as
  reprojection). Busy start grid: uncapped 110-113 FPS (reprojection 113-116), GPU busy 6.0 ms/frame (4.3); at 90 Hz
  9% over a period (4%); at 2160x2160 4.7%. BB_FRAMES_AHEAD=2 no help. Validation clean of multiview errors.
- Not handled: compute that writes buffers once from eye 0 (tile light lists?) serves both eyes; uploads into
  2-layer images reach layer 0 only (none seen in races).

## How it works

- **Head tracking**: hook at `Scene::SetCamera` (image +0x5e7a20, SysV: rsi = 4 KB camera description; world 4x4
  row-vector at +0, projection at +0x40). The player view (projection of the screen's aspect, P00 < 2, reversed
  infinite, near 0.02) gets world = head x world and the headset's asymmetric FOV, in a copy (rsi redirected) so the
  engine's previous-camera stays coherent (setter-level edits smeared TAA and motion blur).
- **Stereo from one render (depth reprojection)**: the frame is composited into the display buffer, then every HUD
  element draws over it. At the second display-buffer draw the scene and the main G-buffer depth (largest D32S8 of a
  3+ target pass) are copied and the buffer cleared; the HUD draws over transparent black. Per eye: splat
  (atomicMax on depth | offset, shift dx = K x reversed depth, K = -side x ipd/2 x P00 x width/2 / near), resolve with
  holes from the farther neighbour. The game renders once: the CPU-bound engine (~2200 draws/frame) can't render twice.
- **HUD layer**: the display buffer after the HUD (premultiplied) on a quad 1.4 m wide, 1.1 m ahead of the seat. While
  stereo runs, HUD draws into the display buffer get coverage alpha (the minimap blends SrcA/1-SrcA on alpha: a^2 lost
  its faded parts). The layer composite equals the flat frame (mean diff 0.5/765, only clock digits and animation).
- **Frame poses**: the G-buffer vertex shader's 512-byte camera constants hold the world position at dword 108; it
  picks the head pose that view was rendered with (the GPU runs 2 frames behind the hook). 1800/1800 race frames.
- **Resolution**: 2880x2880 render and output (square = 1:1 with Matt's eyes, same pixels as 4K), aspect kept 16:9
  (eboot 0xb29978) so the HUD lays out its full 16:9 canvas; HUD and flat-screen quads are 16:9. Aspect 1.0 cropped the
  HUD (positions, LAP gone). `vr_fixes`: cs 0x2d9c66a5 (half-res downsample) bounds 960x540 -> half the render size
  (the community patches' "depth bug"); fs 0xbef3454c holds 1/1920 (sprite brightness), not seen in races, untouched.
- **Motion blur**: blurs head turns (sharpness 4.70 still, 2.63 swaying +-15 deg at 1 Hz); the community patch
  "Disable motion blur and depth of field" (enableMotionBlur = false at eboot 0xa109f3) brings it to 5.08; anti-aliasing
  unchanged (the TAA compute 0xfdd72cf1 no longer runs; frame poses come from the G-buffer constants instead).
- **Lens dust** (a screen-space overlay) off for VR: eboot 0xa10dcd `movzx eax, al` -> `31 c0 90` after reading
  `lensdust` (same settings table, image +0x610xxx: fieldOfViewScale, enableMotionBlur, enableWaterDroplets at
  0xa10a92, ssao, enableSSR, ...). Water droplets left on (may be the in-world windscreen rain; check in a rain event).
- Menus without 3D: no split, the whole frame on a flat 16:9 screen 2.5 m ahead. Menus with 3D flyovers: stereo.
- Desktop window: the left eye with the HUD. F8 or a SteamVR seated reset recentres.

## Measurements (simulator, 2880x2880 eyes, meganex profile, DLSS n/a, racing behind the pack)

| Config | Avg FPS | 1% low | over a 90 Hz period | late (>1.5 periods) |
|---|---|---|---|---|
| VR at 90 Hz | 90.0 | 77-81 | 1.1-1.7% | 0.0-0.1% |
| VR uncapped (SIMXR_HZ=240) | 111-124 | 69-77 | n/a | n/a |
| Flat uncapped (same patches) | 113-126 | | | |
| VR, stereo off (flat screen) at 90 | 90.0 | 77-83 | 0.8-1.6% | 0.0-0.1% |

GPU 50-58% (RTX 5090) at 110 FPS uncapped: CPU-bound (the GPU command thread). The ~1% over-period frames and the
50-85 ms hitch every ~10 s are the same with stereo off and flat: the port's own. Prep workers (BB_PREP_WORKERS=4) did
not help (109-113 uncapped); BB_FRAMES_AHEAD=2 neither (over a period 1.2-1.3%).

## The recomp port (H:\driveclub-recomp, branch vr, 2026-10-18/19)

Matt's fork hookmanuk/driveclub-recomp (OverkillLabs3/driveclub-recomp 0.2.3, the same bbport/shadPS4 lineage as
DCport); the dcport-vr commits went across as one 3-way patch (14 small conflicts). Build: `bash build.sh` in MSYS2
CLANG64 (clang 23 needed gpu/libcxx_compat.h forced in and -Wno-error=unused-but-set-global); the DLSS bridge with VS
2026 (`cmake -G "Visual Studio 18 2026"`, DLSS_SDK_ROOT=F:/rpsc3/source/DLSS); `packaging/stage-vr.sh` lays out
release/vr-dev (Matt plays there; STAGE_OUT=release/vr-test for tests). Launcher: VR card (eye size 2160-4320, VR
DLSS Off/DLAA/Quality/Balanced/Performance); VR is opt-in (BB_VR=1), flat play never starts OpenXR.

### Findings

- **GPU quarantine**: after a lost device the recomp writes data/user/gpu_quarantine.txt and skips those compute
  shaders on every later launch (a6cfe095, lighting): broken picture, inflated FPS. Tests run BB_QUARANTINE=0.
- **Readbacks**: ~1.5 per frame CPU reads of pages the GPU wrote (0x3000404000, 0x3000420000 SystemShared,
  0x4004c0f000): the game keeps CPU objects (a flag at +0xa5, a vtable) in the same 4 KB pages as small GPU writes
  (4-16 bytes at 0x30004040f0.., 0x3000420560). Precise readbacks wait for the GPU each time (533 ms/s of fault time at
  4320). VR runs BB_READBACKS=0. Open: a precise fix (tiny GPU writes not marking the page, written back after the
  GPU finishes).
- **No TAA in VR**: the motion blur / DOF patch also takes out the game's TAA (one shader): no anti-aliasing in VR
  unless DLSS. DriveAA's hook (the TAA dispatch) never fires; vr_dlss.cpp runs DLSS on the lit scene (written by the
  lighting combine 0x2c918c06, R11G11B10F) at the first bloom draw (vs 0xb834cdf9), armed once per frame by the main
  view's camera constants. 0xcc8ecafb is the refraction copy's mip chain, not an AA pass.
- **Camera constants** (G-buffer VS, 512 bytes): 0-15 camera-relative view-projection (row vectors), 16-31 view
  rotation, 32-47 its inverse, 48-63 projection (reversed infinite, near 0.02 in races), 64-79 inverse VP,
  80-95 inverse projection, 96-97 target size (the mirror's is 384x136), 108-110 world position. Two identical copies a
  frame. Motion: inverse(VPcur) * translate(poscur - posprev) * VPprev, per eye with the eye's clip shift taken out.
- **Auto recentre**: stereo again after >= 2 s of flat screen (boot), and a main-camera jump > 100 m in one frame
  (race start, restart, menus).
- Scripted tests hold W from the end of the countdown (keys_safe.ps1: keys only while the game is in front).

### Clean frame rates (simulator, 2026-10-19, first event, throttle held, readbacks off, no quarantine)

| Eye | VR DLSS | game flips (uncapped) | new frames on the headset | headset over a period |
|---|---|---|---|---|
| 4320 | off | 79 | 73 | 9.7% |
| 4320 | DLAA | 73 | 65 | 7.3% |
| 4320 | Quality (2880) | 99 | 80 | 6.9% |
| 4320 | Balanced (2544) | 108 | 81 | 6.8% |
| 4320 | Performance (2160) | 112 | 82 | 5.9% |
| 2880 | off | 119 | 88 | 5.9% |
| 2880 | DLAA | 113 | 86 | 6.6% |

The headset thread showed ~80-88 new frames whatever the game made. What was measured (2026-10-19, simulator):
- Showing only finished publications, newest of the last three (BB_VR_WAIT_FRAMES=1 the old way): 2880 over a period
  6.0% -> 3.6%. Taking only the newest (not the last three) collapsed to 20 new frames (the newest is never done).
- Cap: one game flip per headset frame (a token set by each xrWaitFrame), adaptive (on at >= 112% of the headset's
  rate for 2 s, off below 95%; BB_VR_CAP=0 never). 2880: 90.0 new frames, 0.0% over a period, 0.0% late. A fixed
  period cap instead quantised to the 240 Hz present loop (12.5 ms: 80 FPS) and oscillated. Capping when the game
  cannot hold the rate is worse (4320 Quality capped: 12.7% over).
- Still open at 4320: xrWaitFrame-to-submit is fine except "record" (RecordEyes, a few vkCmd calls) stalling up to
  ~10-11 ms a few times a second (log: "headset loop ms", "show parts ms"). Not thread priority (TIME_CRITICAL: no
  change, reverted), not queue priority (0.1-1.0: no change, reverted), not implicit layers (loader ~implicit~: no
  change). 4320 Performance: ~82 new frames, 3-10% over a period (run to run).
- Eyes now copied straight into the swapchain images in multiview (was scene -> intermediate -> swapchain).
- The ~10 ms stall lands in whichever Vulkan call the headset makes first: recording (fresh), submit (commands
  recorded once and reused), or xrEndFrame (copies done right after the previous xrEndFrame): moved, not removed;
  both attempts reverted. It is gone at 2880 with the cap (GPU headroom): GPU back-pressure (a full GPU makes every
  submission wait), not a lock of ours. At 4320 the cure is headroom: DLSS Performance or a smaller eye size.
- Nsight Systems with DLSS on: the game died at startup after "DLSS: ready" (not seen without the profiler).
- One OpenXR Simulator crash inside its own xrEndFrame (D3D12 CommandAllocator::Reset) in ~40 runs.
- DLSS upscaling: the game's view of the lit scene swaps red and blue; the redirect view takes its swizzle.

## Tools (H:\dcport-play)

- `torace.sh FPS [env]`: start on the simulator, keys to the first race. `bench.sh LABEL [env]`: race, throttle via
  the pad file 30 s, frame stats (SIMXR_HZ=240 uncapped; BB_VR=0 flat). `recenter.sh`, `pose.sh YAW PITCH ROLL OUT`
  (simulator head + shots), `blurtest.sh` (eye sharpness), `mkpatches.py OUT NAME|@ADDR=HEX...`.
- Pad input for scripts: `BB_PAD_FILE` (tokens r2, cross...); keyboard keys don't drive the car.
- Triggers in %TEMP%\dcvr: EYES (full-size eyes), TSHOT <guest addr> (target per shader change; display buffer
  0x5000108000 at 4K, 0x5002160000 at 2880), DRAWLOG (draws with blend state), CAMLOG n, RECENTER.
- Env: BB_VR=0, BB_VR_STEREO=0, BB_VR_HEAD=0, BB_VR_FOV=0/1/2, BB_VR_WOBBLE=deg, BB_VR_KEEP_SCENE, BB_VR_NO_FIXES,
  BB_VR_HASHES (compute sizes), BB_VR_FINDCAM, BB_DMEM_MB=10056 (resolution patches). Simulator: SIMXR_HZ.
- The simulator's settings.json window_height got saved as 11 once (window shrank): restore 551.

## Open

- 1% low under 90 (frames over a period ~1-1.7%) and the periodic 50-85 ms hitch: the port's CPU side, not VR.
- Not yet tested in Matt's headset. Other events (day, rain: water droplets and lens dust are screen-space effects
  that may need turning off like motion blur, settings at the same table as enableMotionBlur: enableWaterDroplets,
  lensdust), photo mode, garage.
- Disocclusion fill is the background stretched (DIBR limit): edges of the A-pillars and mirrors.
