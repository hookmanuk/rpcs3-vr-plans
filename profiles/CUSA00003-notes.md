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

### Final build b169788 (simulator, 90 Hz, throttle held, readbacks off, adaptive cap)

| Eye | VR DLSS | new frames on the headset | game flips | over a period |
|---|---|---|---|---|
| 2880 | off | 90.0 | 90.0 | 0.0% |
| 3200 | off | 89.7 | 89.8 | 0.3% |
| 3200 | Quality (2128) | 87.7 | 85.8 | 0.8% |
| 3840 | Balanced (2256) | 87.4 | 84.9 | 1.1% |
| 4320 | Performance (2160) | 84.6 | 83.5 | 3.3% |

Stability with readbacks off: 16 of 16 boots of b169788 at 3200 clean (no lost device, no crash); over the night one
lost device in ~37 readbacks-off boots (an earlier build at 4320, compute a6cfe095 reading 0xa000).
- One OpenXR Simulator crash inside its own xrEndFrame (D3D12 CommandAllocator::Reset) in ~40 runs.
- DLSS upscaling: the game's view of the lit scene swaps red and blue; the redirect view takes its swizzle.

### Per-eye differences (2026-10-19, 82921e0)

- Matt: other cars looked different in each eye. Dev log `BB_VR_MONO_COMPUTE=1` prints every compute ("reads both
  eyes, writes one-layer images only") and draw ("a one-layer pass samples both eyes' images") that runs for the
  left eye only while reading the stereo scene.
- Bloom: 4/15 of the render size (2880 -> 768) and its halvings, within a pixel. Added to the two-layer family.
- Half-size 4x MSAA pass: colour fmt 97 + depth fmt 126, 1440x1440 at 2880 (960 with DLSS Quality). BackingLayers
  excluded multisampled images; now allowed, and ResolveImage resolves both layers (Multiview::ResolveLayers).
  The images are created at 4 samples (SetBackingSamples' ms<->1x copy, layer 0 only, is not used for them).
  Skipping its draws (temporary switch, removed): the headlight halos shrink; 4320 race 78.3 vs 79.7 fps (no gain).
- Left mono, fine: 0xffd5ce3 (32x32 exposure), 0xc56053b9 / 0x59b8e960 (512x512 reflection cubemap mips).
- Eye stack eye_diff.py (grid, three crops): no gross difference before or after; the bodywork matches, edges
  differ by parallax and aliasing (AA off).
- Test copy gotcha: the launcher runs `runtime\DriveClubGame.exe`; copy builds there (not the folder root).
- DLSS-only one-layer passes (192x68, 384x136, 2048x1024 fmt 43, 2048x2048 fmt 91, 768x512 mirror scene): they read
  game textures (512/256/128/64/32 square) that the bloom rule made two-layer: DLSS Quality renders 1920, bloom 512,
  and its halvings are texture sizes. Uploads filled layer 0 only, so the right eye could sample unfilled memory.
  Fixed fdfd71b: the bloom is one image with mips (768x768 levels 10 at 2880, fmt 97 R16G16B16A16F and 122
  B10G11R11), so only that exact size and those formats; Runtime::UploadImage fills both layers of a two-layer image
  (Multiview::StereoUploads). Left: a 512x512 fmt 97 game texture (0x510bc90000) still matches at DLSS Quality, read
  by one mono pass (layer 0, correct). The dev log now names the pass's vertex shader and the two-layer images it reads.

### Afternoon 2026-10-19: blackout, culling, per-eye lighting (68bd57c, 0bb36a0, 5854b87)

- Blackout at dawn (about 45 s into the first race, after the tunnel and the hairpin; HUD intact, until a restart):
  VR runs BB_READBACKS=0 and the CPU never saw the tiny GPU writes at 0x30004040f0... Relaxed readbacks fixed it but
  cost 10-17%. buffer_cache/small_writeback.cpp: written bindings up to 1 KB copied at each submit and written into
  guest memory when the GPU has passed them (~27 ranges, 6 KB a frame; no cost). BB_READBACK_SMALL=0 off.
- Culling: Camera::Set (+0x72d9e0, rdi camera, rsi world = identity, rdx a block: projection, near/far +0x40/+0x48,
  six view-space planes at +0x60, outward normals, inside n.p+d <= 0: near, left, right, bottom, top, far). The
  player camera's planes are replaced by the headset's tangents turned with the head (rotation only: the head's
  position is metres off in the menus). The game's FOV constant (image +0x12efac4 = 0.5, the "FOV fix" patch's
  0x16efac4) widens culling but cuts draws 30% (its detail selection): dropped. BB_VR_CULL_HEAD=0 off.
- Per-eye lighting: computes 0x409b1cc4 (1 MB) and 0x7ceec0f3 (256 KB) build the forward pass's light data from
  depth (fmt 100) and normals (fmt 91); the forward pass vs 0xbe79b5f2 writes the lit scene for both eyes. Guest
  storage buffers are now two-element descriptor arrays in VR shaders (EyeBuffers at the start of main: element =
  view index / vr_eye); bindings give the right eye's copy for per-eye buffers; those computes run per eye
  (BB_VR_EYE_COMPUTES=hex,...); barriers around the right eye's dispatch. Shader cache suffix _mv2.
- BB_VR_AUDIT=1: ONE EYE (a pass run once from per-eye inputs) and BOTH EYES READ LEFT lines, data followed through
  passes (images and buffers). Left after the fix: 0xc6edad8b's 0x300 block (shadow map, scene copy) read by
  vs 0x145f0d43, exposure (32x32, 0x832138ea, 0xeea18ba7), 0x5bc75fd9's 4 bytes: shared on purpose.
- Test harness lessons: the OpenXR simulator walks its head with W/A/S/D while the game is in front (race10 held W:
  benchmarks before this were rendered from a drifting eye; a stuck W from a killed script made every run look
  broken). race10 throttles through BB_PAD_FILE (r2) now; scripts release keys on exit. Dev tools: BB_VR_CAM_FILE
  (camera position for drivebot.py), WATCH "addr len x" (execution breakpoint with caller), BB_VR_LOOKLOG,
  TSHOT accepts B10G11R11. The game's look-around angle lives as a parameter (degrees, -35 right) the cockpit reads.

### Evening 2026-10-19: fire, vents, rain (0ece1e7..a51746f)

- f317055: the right eye's copy of a per-eye buffer is seeded from the original before each per-eye dispatch (the
  compute only writes part of it: the fire and dust differed per eye).
- d1ce29f: deferred light volumes (vs f719615a with cookie and shadow map, 34f93d62, f8440925, 1fbbf338,
  b0adf65b) pass clip x / w to the pixel shader as the G-buffer coordinate, computed before the eye's clip shift:
  each eye lit the G-buffer shift / w away (~100 px at cockpit distance). Vertex outputs that are pos.x / pos.w
  (times a constant, plus one; found in the IR) now get scale * shift / w (Vr::ScanScreenParams). Shader cache _mv3.
  Their view ray (p / z) is still the centre's: position error e * (d / z_volume - 1). A full eye translation
  (v - e with M e = (-shift, 0, *, 0) solved from the matrix rows, view-dependent outputs evaluated again; 57
  shaders) is in the scratchpad as eye_translation.patch: no visible change to the headlights at 8x separation
  (BB_VR_WORLD_SCALE=8), not committed.
- Rain on the first event starts ~150 s after the start. The compositor copies the scene before the first HUD draw
  into the display buffer; vs 0x44606ffd (windscreen drops and wiper streaks, w = 1) and vs 0xdc8e480a
  (perspective, some frames) are scene overlays drawn after the composite 0x8d52ab95; HUD: 8b76f6cd (minimap),
  53b0217e, b0295518. 5218f68, a51746f. BB_VR_LOG_DISPLAY_SEQ=1 logs each display-buffer draw sequence (* = copy).
- Dev: BB_VR_TSHOT_LAYER=1 (TSHOT dumps the right eye's layer), audit flags one-eye draws with the player camera
  and per-eye passes reading one-layer renders, BB_VR_LOG_SCREEN_PARAMS=1, BB_DUMP_SHADERS=1 (dumps at compile:
  move the cache aside), shaders decompile with spirv-cross.

### Headlit car sides (2026-10-19 night, 7b29b1c)

- Symptom (Matt): behind a car at night with our headlights on it, its side looks different per eye (livery hidden
  in one eye). Not reproducible on the grid (random grid order); traced on Matt's paused game with live triggers.
- TSHOT dumps are taken when the vertex shader changes: a dump named after shader X holds the draws before X.
- Reflections: vs 0x4fcf9162 + fs 0x788bb287 adds the lit scene at the hit coordinates of a two-channel buffer
  (0x5031250000): it mirrors whatever lighting each eye has. Sprites/quads vs 0x3528cba (fs 0xe40b5f55 a 256x256
  texture, fs 0x809dd808 depth only) were not it.
- Our headlights: vs 0xf719615a with fs 0xd80f041b (shadow map 1024x1024) or 0x7b2b16ed; depth bounds on, no
  stencil. Light buffer 224 B (vs buffer 0 = fs buffer 1): 12-15 cone, 24-34 light matrix M (columns per v
  component), 40-42 light - camera, 44-46 light-space origin, 48-51 projection, 54 shadow. Camera 512 B. The pixel
  shader's view depth is negative like the ray's z: light vector = C40 - v, light space = C44 + M v.
- Fix: eye translation in the shader recompiler (Vr::ScanScreenParams: v = the 3-vector the position matrix
  multiplies; e from the matrix rows; outputs with a v-dependent division evaluated again with v - e) plus per-eye
  light buffer copies (Rasterizer::BindEyeLightConstants; C40 - e, C44 + M e) in two-eye passes. Shader cache _mv4.
- Triggers added: SKIP (hex shader hashes, live; empty clears), EYELIGHTS (0/1/2), FSIMG <vs> (pixel shader
  images, buffers, depth/stencil state), TSHOT writes _R, _D, _DR files. grid.sh: X via the pad file.

### Readbacks (2026-10-19 late, 845afd0)

- VR ran BB_READBACKS=0 (4320: 65 -> 80 FPS). The game reads GPU results it needs: crowd placement (people in
  mid-air on the stands right of the grid), windscreen drop sprites (vs 0x44606ffd: 594 quads, one draw per
  window, vertex alpha per drop; on/off for frames, VR only), and the dawn blackout (small_writeback.cpp).
- Precise readback CPU reads (BB_READBACK_LOG=1): ~12 pages, 8-byte reads, mostly CPU data sharing pages with
  GPU writes; GPU-written ranges read: 1 KB ones (covered), 0x30004861c0 +8 KB, 0x3000430060 +1.25 KB. Copy-back
  up to 8 KB (BB_READBACK_SMALL_MAX=8, 3 MB/s) did not fix the crowd; unlimited is 1.4-1.9 GB/s.
- Toggles (data/user/toggles.txt, live; the launcher rewrites it at start): ThreadedRecording (16) +
  ConstantRing (1<<36) off fixed the drops only (game 93 -> 83 FPS). Relaxed readbacks (1): crowd floats, 78 FPS.
- Now precise by default: 3200 per eye race start 76 game / 72 headset FPS vs 94 / 88 off.

### Performance (2026-10-20 night)

- Bench tools (scratchpad): bench_toggles.sh LABEL MASK [env] (SIZE env, toggles written live after the grid,
  10 x 1 s flips + headset + nvidia-smi busy), pipe_crash.sh (flat 4K boots, mask set before the race loads),
  vr_stress.sh, crowd_check.sh (grid shots, head to the stand). Stage A wait sites: BB_FRAME_STATS "stage A waits"
  and "Draw pipe: ... drains/s that waited, stage A waited %, stage B busy %" lines.
- Draw pipe (toggle bit 37, upstream's launcher keeps it off): the GPU command thread (stage A) posts draws to the
  draw recording thread (stage B). Stage A drained it on every DumpConstRam (CE, ~650 per frame): 38% of stage A's
  time. 6d1291c: pipe_reads.h tracks what stage B reads straight from guest memory per packet (non-ring buffers,
  vertex/index buffers; all memory for tasks, special and indirect packets); dumps drain only on overlap.
  BB_PIPE_READS=0 restores the drain. Shader::Info::UdMemoryCopy: the fetch shader's V#s copied by stage A, used by
  ReadUdReg on stage B (ReadUdReg dereferences user-data pointers into guest memory; the snapshots only covered
  user data and flattened tables).
- Crash analysis: crash dumps now include referenced memory (0944c4f, probe.c); lldb from MSYS2 clang64 opens them
  (`target create exe --core dmp`, `memory read`). VR race-load crashes: recorder thread in RecordChunk::Execute ->
  vkCmdSetVertexInputEXT with corrupted attribute descriptions. Flat: endRendering in the driver (null + 0x130),
  still open with the pipe on in flat. Record/chunk ownership checks (scratchpad record_check.patch,
  chunk_check.patch) found no overlapping recording.
- At 1080 with 6d1291c: stage A still waits ~29% (ConstRam drains ~8k/s remain), stage B busy ~84%, GPU ~52%.
- Root cause of the race-load crashes (0f2447e): ProcessCommands checked num_commands, drained, then looped; a guest
  thread's SendCommand (OffloadReadback -> RecordReadback, then a flush) landed between check and loop and ran on
  stage A without a drain. Found with a per-chunk op log (scratchpad edit_chunk_log.py + switch stacks: every
  Push/Allocate with offset, thread and site; RtlCaptureStackBackTrace when the writing thread changes; abort with
  the log when a command's vtable is outside the executable). Caught within 1-6 VR boots at 1080 with BB_PROFILE=1.
- Ideas not done: exact ranges for ordered tasks (WriteData/EOP/DMA) instead of all memory (tried keeping
  catch-all entries separate: drains 8.8k -> 6.9k/s, FPS unchanged).

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

## Readback hybrid: what it may and may not do (2026-10-21, see 6-wip-games.md for the day's record)

- A page the hybrid learns "fast" (unprotected) must never carry GPU-written bytes the game reads back the same
  frame. Driveclub's hot CPU pages share 4 KB pages with the heads and tails of its GPU-written cluster lists; a
  fast page gave the game those bytes a frame late or never, and the clusters they index floated in the sky.
  `LargePartFast` (da46791) makes such a page exact for good; in practice no page learns fast then, and the hybrid
  runs at precise-readback speed (66-67 benchmark FPS at 3200, same 1% lows as the fast-page build's 74).
- GDS counters: the ring slot's EOP label is written after the GPU's copy (gds_fence.cpp, e37c6fd), free; the four
  fixed-slot copies a frame keep decode-time fences (deferring them serialises the game with the GPU: 50 FPS).
- Evidence rule learned the hard way: eye dumps (EYES) force a GPU sync and hide timing bugs; judge with mirror-window
  grabs (`grabwin.py`, no sync) at a loaded GPU (EYE=4800), same race moments side by side at native resolution.

## Single-frame flashes and the draw thread (2026-10-22, 9037616; record in 6-wip-games.md)

- Find them with the frame log: dev key FRAMELOG (frame count; BB_FRAMELOG_SIZE for bigger thumbnails) writes the
  left eye of every shown frame to %TEMP%\dcvr\framelog.raw; flana.py (session scratchpad) flags frames unlike both
  neighbours and prints the run's duration. Screen grabs and EYES dumps miss them or sync them away.
- Cause: per-thread batches of small guest copies. A submission or fence waited only for its own thread's batch;
  copies the draw recording thread had queued could run after the GPU read their staging. Fixed in BbCopy (every
  thread's batch is started by a wait). Any new per-thread deferred work needs the same care.
- A zero only counts at full speed: configurations that keep CollectRingBindings from running (constant ring off)
  slow stage A to 21-26 FPS through its unpruned pending-write list, and slow runs hid the flashes.

## Crash and performance tools (2026-10-22)

- A process that vanishes without a Fault line: Windows Application log event 1000 names the module and offset
  (ntdll RtlAcquireSRWLockExclusive = a lock on freed memory). BB_NTDLL_FAULTS=1 (probe) reports ntdll access
  violations with BB_CRASH_DIR dumps; scratchpad unwind.py DUMP unwinds a dump's thread with .pdata and symbolises
  with llvm-symbolizer (the exe has DWARF); stacks.py PID for a live (hung) process. hangloop2.sh N EXE: N short
  benchmark boots, keeps the log of any that does not reach the race.
- Stage A is the CPU bottleneck in VR (BB_FRAME_STATS "idle" ~1%); its "stage A waits" line names the drain sites.
  Benchmark uncapped at Matt's size: `EYE=2560 vrbench2.sh TAG EXE` (runs at 240 Hz); interleave A/B pairs.

## Open

- 1% low under 90 (frames over a period ~1-1.7%) and the periodic 50-85 ms hitch: the port's CPU side, not VR.
- The grid is CPU-bound on the GPU command thread (fpsVR 22 ms CPU frame, one core at 96%, GPU 71%, 54 FPS in
  Matt's headset at the lights). ~4,200 draws a frame (two eyes); profile: memcpy ~16% (stream uploads per bind),
  kernel lock waits ~11% (hybrid mutexes per bind vs guest faults), BindBuffers 4%, barrier tracking ~3%.
- A flat grey quad above each opponent car where the driver tag should be; also in flat mode, so the recomp's tag
  rendering, not VR. Not investigated.
- Car-selection eye comparison on da46791 not re-done (earlier builds matched).
- Not yet tested in Matt's headset. Other events (day, rain: water droplets and lens dust are screen-space effects
  that may need turning off like motion blur, settings at the same table as enableMotionBlur: enableWaterDroplets,
  lensdust), photo mode, garage.
- Disocclusion fill is the background stretched (DIBR limit): edges of the A-pillars and mirrors.
