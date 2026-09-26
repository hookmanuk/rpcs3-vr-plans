# Ridge Racer 7 (BCAS20001 v01.00, Asia, En/Ja) - findings

`EBOOT` PPU hash `PPU-de2b587bf99874b3fe390329ef4f18150e4f853f`. Profile `bin/vr_profiles/BCAS20001.json` is the
in-emulator generator's output (2026-09-25) plus the frame-timing fields and `max_fps`/`default_fps 0` (2026-09-26). Not yet checked in the headset (SteamVR was off).

## Rendering

- Camera `c[4]` (row_vectors), covering 97% of depth-tested scene draws; a second block `c[0]` (10 draws,
  a camera-space banner such as the countdown) gives `bare_projection`.
- The scene renders at **1408x768** into `0xc0880000`, is composited to 1280x720 (`0x50110000`), and the
  race HUD is then drawn back into `0xc0880000` at 1280x720.
- **HUD**: program `f78118c010d9eba2`, matrix-less (reads only `c[467]`, positions already in screen space),
  no depth test, 6-vertex quads, ~75 per frame. Generator: `passthrough_hud` + `hud_programs`.
- **Units are metres**: the player car's body puts the camera at (0, 1.97, 5.74) in car space (chase camera
  5.7 m back, 2 m up) and its wheels at x = +-0.8 (1.6 m track). Near plane 0.3. `eye_baseline` 0.064.

## Head-locked wheels and lights; black right eye in movies (2026-09-26, fork 50f7c0ea)

- **Wheels and light glows followed the head** (seen in the headset at the countdown). Their object
  matrices carry strongly non-uniform scale: `c[4..7]` of program `fc0f96d1` (13 draws a frame, clip x/y/w
  directions up to cos 0.39 apart, w row length 3.6-6) and some draws of `8b1da3c1` and `a270d0eb`. The
  generated profile had `require_rigid_camera: true` (tolerance cos 0.1), so those draws were rejected and
  stayed on the game camera. Fixed with `require_rigid_camera: false`. Nothing else gains the rotation: the
  other rejected draws are the 512x512 reflection pass (`fc500abf`, `b074df25`, viewport 256x256), which the
  output-aspect gate already excludes. Rotation audit (yaw 25) at the race start: wheels, headlight and
  street-lamp glows stay with the scene.
  - Why the generator chose rigidity: its stray-data rule (cos > 0.3 and off-aspect) matched `fc0f96d1`.
    It now ignores depth-tested draws that sample no colour render target (world geometry). A rerun in a
    race (evidence `evidence/rr7/BCAS20001.generated-2026-09-26.json`, desktop, 60 Hz) no longer writes
    rigidity, but also picked up a small `c[3]` block (23 draws) and `require_camera_aspect`; the checked-in
    profile keeps `[4, 0]`.
- **Xevious loader and intro movies black in the right eye.** The play area is one quad (HUD program
  `f78118c0`) sampling a CPU-written texture (`0xc2fd0f50`, 256x512), drawn **with depth test** against
  `0xc1100000`. Both eyes sampled the same texture; the right-eye quad failed the depth test. The right-eye
  surface cache never ran the left eye's surface initialization (`write_barrier`: clear, or inherit from
  older surfaces), so a new or recycled right-eye depth buffer kept stale contents. Confirmed by clearing
  the right depth before each draw (Xevious appears), then fixed in the renderer: `prepare_rtts`
  initializes bound right-eye surfaces that have `erase_bkgnd` or `old_contents`. Checked on the desktop:
  Xevious and the title's intro movie (Reiko) and attract replay in both eyes. No pre-fix capture of the
  movie itself; the user reported it.

## Road reflections follow the head (open; b855eda1 reverted in 6c4e1a88)

Headset report: street-light and headlight reflections on the tarmac (grid, tunnel ceiling lights) move with the
head; separately, other cars' brake lights float in the wrong place (not on the road). Findings so far:

- The road (`1397dca5`, fragment programs sampling unit 1) reads a 512x128 target `0xc1a00000` of 128x128 tiles at
  its **own clip position**: its vertex program writes `dst_reg8 = dst_reg0` (tc1 = clip position) and the
  fragment samples at `tc1.xy/tc1.w`, remapped into the tile by a fragment constant. So the tiles need exactly
  the road's per-eye transform.
- The tiles are drawn with the game camera `c[4..7]` into 128x128 viewports. The per-eye path applies the
  headset-FOV remap and then `undo_viewport`, which stretches each tile over the whole 512x128 target: a
  mismatch with the road's lookup. b855eda1 (off-aspect targets keep the game camera) was wrong and is reverted.
  Tried (uncommitted, not kept): per-eye transform without `undo_viewport` for off-aspect draws with a 16:9
  projection; the desktop audit (`RPCS3_VR_AUDIT=25`, `RPCS3_VR_AUDIT_FOV=1.0`) still showed the car's reflection
  wedge at the unrotated screen position.
- The tile draws (`970af287`) sample `0x50110000`, the game's previous finished frame (screen-space
  reflection), which is the next thing to check (how their shader addresses it).
- Repro on the desktop needs `RPCS3_VR_AUDIT_FOV` (otherwise the headset remap and `undo_viewport` never run).
  Isolate the reflection layer by diffing frames with probe `hide=` of `970af287` (that probe option was part of
  b855eda1 and is reverted too).
- **Do not enable `Log shader programs` for this game:** it froze emulation when the main-menu video
  (`menu.pam`) started, three times.

## Scene soft at any resolution scale (2026-09-26, fork 6e0d69cd)

Headset report: grainy/muddy, lines never sharp even at 600%, unlike WipEout. Full-resolution captures
(stereo screenshots are no longer squashed) showed scene edges smeared over ~6 px at 600% (one native pixel)
while the HUD, drawn afterwards, was crisp. Cause: the pass that resolves the 1408x768 scene to 1280x720
(vertex program `e2b9761e8fd87794`, fragment `r = (tex(uv+c467.zw) + tex(uv+c467.xy) + tex(uv+c466.xy)) * c0.x`)
is a three-tap softening filter with tap offsets of about a quarter native pixel held as vertex constants
`c[466..467]` in texture coordinates, so resolution scaling does not shrink them. Fixed by the new profile field
`resolution_scaled_constants` (divides the slots by the scale). 600%: gradient energy of scene regions x1.9-2.2
(`evidence/rr7/sharpness-600pct-before-after.png`, top before, bottom after). Not checked in the headset yet.
Earlier theories that did not hold: anisotropic filtering (already 16x, live setting), SteamVR downsampling.

## Start-grid frame drops (2026-09-26, fork 243a7ad2)

Headset report: well below 90 FPS on the start grid (46 even paused), 90 alone on track, GPU use low, worse at
higher resolution scales.

- **Lockstep with the game.** The RSX thread waits once a frame on the game's semaphore `0x60300800` (NV406E
  acquire), and the game's PPU threads spend 92-96% in `sys_semaphore_wait`. The frame is therefore bounded by
  RSX-thread work. Paused on the grid (~1300 draws/frame, 400%): RSX idle on that semaphore 5.5-7 ms/frame flat
  vs 1.5-2 ms stereo, i.e. stereo cost ~3.5 ms/frame on a 11.1 ms budget. Alone on track (~320 draws) it idles
  4-8 ms. Even flat, the grid is tight at 90 Hz (it had 16.7 ms on a PS3 at 60).
- **Cause of most of the stereo cost:** car reflections sample an environment cube map built by a deferred copy
  from six 256x256 faces (`0xc1a50000..0xc1b90000`). The left eye's copy is cached by the texture cache; the right
  eye rebuilt it uncached from the right-eye faces on every draw: 36 rebuilds a frame on the grid, GPU copy work
  that grows with the resolution scale, and each copy split the right-eye batches (87 a frame).
- **Fix (renderer):** a right-eye copy whose sources are all off-aspect targets uses the left eye's copy (such
  targets are never moved per eye). Rebuilds 36 -> 0, batches 87 -> 30, stereo idle 1.5-2 -> ~3.5 ms/frame;
  restart + countdown in headset mode at 400% held 88-90 FPS (was 49-61). Also `camera_probe::profile()` no
  longer rebuilds its key each call (it was ~5% of RSX-thread samples).
- Not the cause: Multithreaded RSX (no change), host GPU labels (off), readbacks and hard syncs (0), the Draw
  Thread's 24 `sys_event_queue_create/connect/destroy` per frame (~0.1 ms).
- Tools: `plans/tools/threadcycles.py` (per-thread CPU; GetThreadTimes undercounts RPCS3's bursty threads),
  `plans/tools/rsx_sample.py rsx::thread 10` (stack sampler with rpcs3.pdb; slows the game while it runs),
  `RPCS3_VR_GPUPROF=1` (now also reports right-eye batches and rebuilt copies per frame).
- Remaining stereo cost (~2 ms/frame on the grid) is the right eye's second pass through the driver and the
  per-draw eye constants; multiview would be the structural fix.

## Frame rate: runs at the headset rate (2026-09-26)

Native 60 FPS, one game step per vblank, time counted in frames: at a 90 Hz vblank everything ran 1.49x.
Fixed by the patch "Frame rate follows VR" (`bin/patches/BCAS20001_patch.yml`, on by default) plus profile
fields (`max_fps 0`, `default_fps 0`, so VR runs the vblank at the headset rate):

| What | Where | Fix |
|---|---|---|
| Physics step | 21 static 1/60 floats 0x4af520..0x4d767c | `game_frame_time_f32` (1/fps) |
| Race ms timer (0x104ac750, per car) | `li r5,17` at 0x13143c/0x13145c/0x131ebc/0x131ed4 | reads ms word 0x4d8ff0 (`game_frame_ms_u32`) |
| Per-car frame counter +0xc (0x10311934) | 0x26ba98 | tick cave |
| Car state +0x10, global frame count 0x104a5160, race object +0x324 | 0x12e718, 0x12e378, 0x2c6a04 | tick caves |
| HUD frame timers (14 x {count, running}) | 0x30c33c | tick cave |
| Per-car race objects +0x1b0, +0x1e8 (stride 0x270) | 0xff5bc, 0x100640 | tick caves |
| 2D/HUD animation ms (16,17,17 pattern) | 0x129c8c | exact ms per frame |
| Race timeline object +4 (frame events) | 0x2471e0 | tick cave; event checks skipped on a zero tick |
| **Lap/race/time-limit clocks** (race object +0x3f4, +0x4b8, +0x650 up, +0x3e4 down; 1/3000 s, 50 per frame at ~55 sites) | one cave after the race loop's state update (0x23ad34) | a step of exactly +-50 since last frame becomes this frame's real 1/3000 s; other jumps (new lap, reset) kept |

Tick caves add `floor(k*A/fps) - floor(k*(A-1)/fps)` (A = vblank count at 0x1028d6e4, fps from word 0x4d8ff4
written by the profile, k = 60, 1000 or 3000) instead of a constant; at 60 Hz they reduce to the native steps.
Spare words 0x4d8ff0..0x4d9004 (unreferenced by the game) hold ms, fps and the clock shadows.

Measured (desktop stereo, 90 Hz): camera 0.66 m/frame (real speed), race timer 0.99x, all four race clocks
0.99x, lap display 1.0x over 48 s steps; 60 Hz unchanged (lap display 9.33 s in 9.3 s). Same-moment 2D vs VR
captures (probe `render=0`/`1`) at the countdown, coasting and stopped: HUD, minimap, speedometer and scene
identical apart from parallax.

Dead ends: slowing the global frame counter 0x1049fb0c (0x1027f0) or feeding the render stages a scaled copy
deadlocks: it indexes GPU buffers (RSX semaphore timeout). The main loop's vblank step multiplier (0x39714)
has no effect on physics. Several counters matched the displayed lap time by coincidence (the HUD timers,
per-car +0x1b0/+0x1e8, the timeline object); the display's source was found by its formatter (division by 3,
1/3000 s units) and an in-run watch on the race object.

## Benchmark (desktop stereo, Resolution Scale 300%, RTX 5090, 2026-09-25)

| Vblank | FPS (mean / min) | Notes |
|---|---|---|
| 90 | 88.5-89.5 / 82 | holds 90 |
| 144 | 139.8 / 114 (load) | 7.0 ms/frame between flips; RSX thread busy 0.6 ms; ~310 draws; no readback stalls |

Stereo at 3x resolution has ample headroom for 90; no performance work needed.

## Open

- **Screenshot crash in a headset session without a profile**: on first boot (no profile) with SteamVR
  running, the screenshot hook crashed the NVIDIA driver (`nvoglv64.dll`, access violation) and then hit
  `ensure(current_queue_family ...)` in `vk::image::push_layout` (`image.cpp:227`) during the screenshot.
  Fine with `-NoHeadset` and with a profile and no headset session. Suspect the OpenXR publish path leaving
  the display image owned by another queue family (the XR queue) before the screenshot copy.
- Headset check: HUD box, `bare_projection` banner, world scale, menus, 90 Hz play; recheck wheels/lights
  at the countdown and the movies after 50f7c0ea.
- A full race to the finish at 90 Hz (results, lap records, time-limit expiry): the test driver only holds
  accelerate and stalls on a wall.
- Boot script used for tests: title -> Start x several (logos, Xevious loader, attract) -> Arcade (Down x3) ->
  Single Race -> Rave City Riverfront -> Normal -> machine -> Start Race.
