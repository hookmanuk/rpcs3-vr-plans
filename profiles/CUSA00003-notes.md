# DRIVECLUB (PS4, CUSA00003 EU disc, APP_VER 1.28): VR notes

Not RPCS3: the PS4 game runs on DCport (qnfn/Driveclub-Port: the game's x86-64 code natively, a shadPS4 Vulkan
renderer). The VR fork is `H:\dcport-runtime` (bloodborne_pc base), branch `vr` on top of `dcport` (the port's
runtime patch applied). Fork code in `gpu/shadps4/video_core/renderer_vulkan/vr/` (vr_openxr, vr_camera, vr_stereo,
vr_fixes, vr_dev), one-line `// VR` hooks in vk_platform, vk_instance, vk_presenter, vk_rasterizer, vk_pipeline_cache,
vk_temporal_upscaler.h, CMakeLists (shaders). Build: `bash H:/dcport-play/build.sh` (MSYS2 CLANG64; kills bb-probe,
copies openxr_loader.dll). Test root `H:\dcport-play` (data/, user/, scripts below). Play: `H:\dcport-play\Driveclub VR.cmd`.

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
not help (109-113 uncapped).

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
