# SEGA Rally Revo (BLUS30068) - VR notes

Disc 01.00 (`SEGA Rally Revo (USA) (En,Fr,De,Es,It).iso`), PPU hash `PPU-cf7bf795662e7da4af16f0131ac7c3bef86776ce`.
Route: `tools/re/sr_boot.sh` (Start > Premier > Amateur > AZA Challenge > Safari > Subaru > race). Savestate
`sr_race0` (the Safari grid, race clock running).

## Savestates

Saving fails ("failed to lock SPU threads") even with Compatible Savestate Mode: an SPU sits in a GETLLAR reservation
wait (`exec_mfc_cmd<false>`, `unsavable` stays set). `Core > Disable SPU GETLLAR Spin Optimization: true` makes the
GETLLAR spin return to the SPU code, and the save works. Both are set in Matt's custom config
(`bin/config/custom_configs/config_BLUS30068.yml`).

## Frame rate: "Unlocked frame rate (follows Vblank Rate)"

- Native 30: the flip (`0x1e3978`, called from `0x1df7a4`) releases GCM label 0x42 with the vsync interval from the
  global `[0x10361bd4]` (2; set by a vsync-mode setter at `0x1d3f9c`-`0x1d40ec`); the GPU waits for label 0x42 = 0
  before the next flip and the vblank handler (`0x1e1fb4`) counts it down. The patch loads 1 (`0x1df79c`: `li r5, 1`).
- Game time is measured: the race clock keeps wall time at Vblank 120 (11.46 s over 11.41 s), and 5 s of throttle from
  `sr_race0` reaches the same place and 63 mph at Vblank 60 and 120. Profile `max_fps 0`.
- Flat ceiling with the patch: 175-225 FPS racing (Vblank 240), RSX thread ~5 ms.

## Culling: "Wider view (VR culling)"

The projection builder `0x174608` (8 callers, every camera mode) loads the FOV from the camera record (+0x4b8, 60
degrees high in the race) at `0x174640`; the patch calls a cave in the code segment's last page (`0x4d7140`, past the
segment end `0x4d7100`) that multiplies it by Scale (default 2.5) and clamps to 150 degrees. Found with a PINE scan for
perspective matrices (`tools/re/findproj2.py`: `0x10349cd0`, fovy 60) and a PPU write watch on it.
Trap: `lfs f0, -0x8e80(r12)` can't be encoded (16-bit signed offset); with `lis r12, 0x4e` the offset 0x7180 read
0x4e7180 and the scene went black. `lis r12, 0x4d` + 0x7180 is right.
On the simulator the view is filled straight, turned 25 degrees and pitched up 25 degrees.

## Frame rate in VR (OpenXR Simulator, 300%, `sr_race0` holding the throttle)

| Wider view | 72 Hz | 90 Hz | 120 Hz |
|---|---|---|---|
| 2.5 | 67.6, RSX 14.3 ms | 69.6 | 69.7 |
| 2.0 (default) | **71.9, 0% late**, RSX 11.9 ms | | |
| 1.0 | 71.9, 0% late, RSX 11.8 ms | | |

Sustained **72 Hz** with the default Wider view 2.0 (still fills the view turned and pitched, a sliver missing at the
far left when turned).

## VR profile

Generated in the race (`row_vectors`, camera blocks `c[8]` (most scene), `c[0]`, `c[4]` (the road: removing it puts
the road at the game camera), camera position `c[4]`, near 0.1 = metres, `passthrough_hud`), then `max_fps 0`,
`default_fps 0`. HUD box straight and turned: OK (the left-eye edge crop with the head turned is the simulator
preview, as in DW Gundam).

## ~~Open~~ Fixed: dark shadow-like blobs, different in each eye (see "Cause and fix" below)

While driving, dark patches (shaped like cast shadows, often car-sized, sometimes thin streaks) appear on the road in
one eye and not the other; the car's own shadow is missing or displaced in one eye. Same with Wider view 1.0, with
zero eye separation (`per_eye_separation` 0, `eye_baseline` 0: so it follows each eye's projection, not the offset),
without `camera_position.slot` (Wolverine's per-eye cause; c[4] is also a camera block here), in two-draw unbatched mode (`RPCS3_VR_MULTIVIEW=0 RPCS3_VR_BATCH=0`), with `require_camera_aspect`, with
`hud_display_buffers_only`, with `unboxed_draws` for the HUD program's full-screen sizes.
**Gone** with `passthrough_hud: false` (HUD drawn full-view in each eye; car shadow then matches in both eyes) and
with probe `hide=ae5d1f3fa4187794+f780e2c460d9eba2` (both matrix-less HUD programs). Not gone hiding only
`f780e2c460d9eba2` (or only its main-target draws), the 640x720 pass `f78638bb1ce5eba2@50610000` (reads the depth
buffer), the draws into the 512x512 `c3574000`, the blended decal programs.
Frame layout (inspector, `insp/BLUS30068_20261004110745_f1890_stereo.jsonl`): 512x512 `c3678000` (563 scene draws
with the camera blocks) and `c3574000` (96), 912x912 `c8250000` (shadow map, 30 draws + `f780` blur ping-pong), main
1280x720 `c0580000`, then `f78638` (640x720 from depth), composite `f780`, bloom 320x180/160x90, final `f1458d64`
into the display buffer `c2542000`, HUD `ae5d1f3f` (27 draws, fp 175) + `f780` into the display buffer. The 512 and
912 targets exist once (RTDUMP has no right-eye surface for them).
Hiding `ae5d1f3fa4187794` alone: blobs remain. The runs don't replay exactly (the car took another line in the
hide-both run), so the two "gone" results need repeating at the same track spot (blobs show at fixed places, e.g.
right of the car at race time 0'29"6). Then find what the HUD box path changes outside the HUD draws (state left
over into the next frame's first draws: the 512 / 912 passes are matrix-less `f780` blurs that follow the last boxed
`f780` draw).

Scripts: `tools/re/sr_boot.sh`, scratchpad `srdrive.sh OUT [PROBE]` (simulator, `sr_race0`, throttle, 4 SBS shots).

### More on the blobs (2026-10-04 afternoon)

- Not `camera_position.slot`, not `eye_offset baseline_per_w`, not `clip_space_scene_draws`, not the 17 programs
  drawing into the 512x512 `c3678000` (hidden).
- A paused frame keeps the blob (the pause screen blurs a frozen copy of the last scene frame), so hide tests on a
  paused frame show nothing.
- **Timing-dependent:** three identical runs (`sr_race0`, throttle 9.3 s, pause; scratchpad `srpause.sh`) gave the
  left-eye blob in two and not in the third (region mean 44 vs 53). Bisecting with `gamecam=` sets is therefore
  unreliable (both halves "fixed" it). A per-eye difference that comes and goes between identical runs points at data
  that changes between the left and right eye's draws (a buffer or texture the game rewrites mid-frame), not at a
  profile key. Next: RTDUMP the main target per eye right before the post chain (`prog=f78638bb1ce5eba2`) over many
  frames to catch one with the blob, then step back with `prog=X#n` to the draw where the eyes diverge.

### Cause and fix (2026-10-04 evening)

Per-eye RTDUMPs of the 912x912 shadow map `c8250000` (two-draw, 100% scale) showed the eyes' copies differing by
3-9% of their bytes, and identical before the first caster draw: the right eye's copy of this light-space target had
casters missing or from older frames (some dumps had no right copy at all). The right-eye surface cache keeps its own
copy of every render target, which it can evict and rebuild out of date; for a target no camera draw reaches, both
eyes' images are by definition the same. Renderer fix (fork, `VKGSRenderVR.cpp`):
`vr_eye_invariant_target()` = an off-aspect colour target with no 3D content (`vr_has_3d` false, not
`is_view_target`, profile without `offaspect_player_views`); the right eye samples the left eye's surface (direct
views and format-converting copies), and with multiview its layer 1 takes a copy of layer 0 after each write before
it is read (`vr_restore_texture`). Result: the tree shadows on the road now appear in both eyes, at matching places,
on two-draw and multiview; 72 Hz unchanged (71.9 FPS, RSX 12.0 ms).

## Head poses on the OpenXR Simulator (real head pose, 2026-10-05)

Straight, yaw +-20, pitch +-10, roll 15 (`posecheck.sh`, race): road, car and HUD right, HUD in the world-fixed box. Sheet `evidence/headpose-2026-10-05/pc_sr_sheet.png`.

## Open (Matt, 2026-10-05)

- **Menu flicker, fixed 2026-10-05 (fork 17b02348e):** in Matt's `BLUS30068_1_2` (league select) the headset view
  showed only the card panel and the 3D card stack on black: the blue background, title and button prompts were
  missing (they flicker in Matt's headset). The front end draws a 3D jungle backdrop and cards through camera-like
  blocks, so the frame counted as 3D. Inspector menu vs race frames: programs only the front end uses are the
  background `860c2ce6c6398a2c` (draws into `c3460000`), `9e0f6220216133cc`, `1be7ebf6362e1549`, the cards
  `5e4fd5886053bfac` and `ae47d748b3e87794`. `screen_frame_draws` with the background and cards, texture `0x0`
  (their textures start at unit 1; unit 0 is unbound, so `2048x1024` never matched). 14 shots over two menus all
  whole on the fixed screen, matching flat (`evidence/sr-menu-2026-10-05/`); the race state stays 3D.
- **Performance: 90 Hz reached 2026-10-06 (fork 24f0bf997).** `tools/rsx_sample.py rsx::thread 10` in the race
  (`vrtest_segarally_race`, R2 held): 22% in `VKGSRender::get_occlusion_query_result`, 26% semaphore waits. The
  config has `Accurate ZCULL stats: true`. Measured with `vr1pct.sh ... W` at 300%:
  | Setting | Vblank 90 | Vblank 180 |
  |---|---|---|
  | as before | 79.0 FPS, late 0.16% (RSX 11.9 ms) | 82.0 |
  | Relaxed ZCULL Sync (config) | 89.1, late 0% | 105.3 |
  | + Accurate ZCULL stats off | | 100.7 (no gain) |
  | profile `zcull_approximate` | 77.7 (no gain; reverted) | |
  | profile `zcull_relaxed_sync` (new) | 90.0 / 88.8, late 0-0.28% | |
  After: the RSX thread waits on the game ~35% of the time (6.8-10 ms a frame); race burst shots relaxed vs strict
  show nothing missing or flickering. Profile now `zcull_relaxed_sync: true`.

## Open (Matt, headset, 2026-10-06)

New state `BLUS30068_1_3` (10:11, a 147 MB state, so likely in a race; check what it shows). Not investigated:
1. **Main menu, track choice:** a "SEGA Rally" text logo behind the track choice is drawn in 3D, wrongly and painfully;
   it should be flat. The 2026-10-05 fix put frames with the menu background `860c2ce6c6398a2c` or the cards
   `5e4fd5886053bfac` on the fixed screen; the track-choice screen is probably drawn without either, so it stays in
   the headset view. Find its own marker program (inspector capture of that screen vs a race) and add it to
   `screen_frame_draws`.
2. **Bird shadows head-locked in races:** when birds appear, their shadows stay fixed to the HMD wherever the birds are.
   Probably a shadow/decal program drawn without a camera block (projected by the game), as `preprojected_programs`.
3. **Rear-view mirror head-locked** instead of sitting at the top of the HUD box. GT5's mirror used
   `subviewport_cameras_in_box` (with `hud_box_after_shader`); check how SEGA Rally draws its mirror (its own target
   copied in, or a sub-viewport of the scene).

## 2026-10-06

- **Mirror fixed (fork d65dc5c7b):** the rear-view mirror is rendered into a 512x512 target (`0xc3470000`, the first
  ~800 draws) and put onto the scene by a matrix-less quad `5c0d80187ad91a90` before post-processing, so it stayed fixed
  to the HMD while the HUD box was world-fixed. Listed in `hud_programs`: it sits at the top of the HUD box
  (`evidence/sr-mirror-2026-10-06/`).
- **Bird shadows:** not reproduced: 12 captures over a minute of driving from `BLUS30068_1_3` had no extra matrix-less
  scene draws and no birds on screen. Needs the place where birds appear.
- **3D "SEGA Rally" logo behind the track choice:** not found yet: the league, car and event screens reached from
  `BLUS30068_1_2` are all flat on the fixed screen; the logo screen is elsewhere in the menus.
- **Fixed (later 2026-10-06): the title screen** ("SEGA RALLY REVO" logo, PRESS START BUTTON, after the boot logos) was
  drawn in the headset view in stereo: a small panel with the text below it. Its frame has neither menu marker; it
  draws a 3D background with `9e0f6220216133cc` (texture on unit 1, unit 0 unbound), which no race uses. Added to
  `screen_frame_draws` (`0x0`): the title is now whole and flat on the fixed screen
  (`evidence/sr-title-2026-10-06/`). The attract-mode replay after it stays 3D (a race). The menus reached from the
  title (Championship, Quick Race track choice, leagues, cars) were already flat.
- **Bird shadows / right-eye smear: fixed (fork b27f65716, generic).** From `sr_blob` the right eye showed a brown smear
  on the car's rear window that moved with the car (not head-locked); flat shows only a small bird shadow there
  (`evidence/sr-dust-2026-10-06/`). The soft dust particles (`ba8d669882cb85e2`, 640x360) read a 640x720 half-width
  depth (`f78638bb` into `50610000`) that the renderer shared between the eyes as 2D content (a camera draw marked
  only its colour targets as 3D). Depth buffers now count as 3D: both eyes clean. Matt's "bird shadows stuck to the
  HMD" is probably this (dust drawn with the wrong eye's depth); recheck in the headset where birds fly.

## Open (Matt, headset, 2026-10-07): shadows slide across the ground with head yaw

Matt confirmed the menu (title screen) fix. New: start the first race (press Cross through all the menus) and turn the
HMD left and right: shadows move across the ground, which they should not (they must stay fixed to the world). Not
investigated yet. Candidates: a screen-space shadow/projection pass rebuilding positions from depth with the game
camera's constants (as Asura's Wrath, Sonic and R&C: `depth_remap_programs`, `depth_remap_uv` / ray variants); or the
shadow map / tree-shadow blobs tied to the eye's view. Check with `tools/re/simpose.py` yaw -20 / 0 / +20 on the
simulator from a fresh load of the first race.

**Matt, headset, 2026-10-08: still wrong (bird shadows).** Start the first race, sit on the start line and turn the head:
the large dark shadow shapes on the ground (a bird-like silhouette bottom left, a big dark wedge beside the car) are the
birds' shadows, and they slide over the ground as the head turns instead of staying put. Matt's shot:
`evidence/segarally/matt-bird-shadows-2026-10-08.png`. The 2026-10-06 dust/depth fix did not cure it. Reproduce on the
simulator from a fresh first-race start with `simpose.py` yaw -20 / 0 / +20 (compare against flat).

## 2026-10-08: bird shadows investigated (not fixed)

- Reproduced on the simulator: `tools/re/sr_boot_vr.sh` (boot to the Safari grid in VR, `gclean.sh BLUS30068` after);
  bird silhouettes and a large dark wedge right of the car show on the ground at the start line, best seen at pitch
  -15 (`evidence/segarally/birds/p_sheet.png`). New state `vrtest_sr_birds` (start line, birds flying; saving it cost
  Matt's `_1_0` to the cap for a moment: restored from `F:psc3ackup_savestates_BLUS30068_20261008`).
- Same game moment, flat vs VR (`ab_sheet.png`): the wedge right of the car is in VR at yaw 0, not in flat. Hiding draws
  live: the wedge goes only with the road (`1965d57fee836671`, `h_sheet.png`), i.e. it comes from the road's
  shadow-map lookup. The road computes the shadow coordinate from world position (`tc2` = `c[5..8]` x local position),
  eye-independent.
- Shadow map `0xc8250000` (912x912, perspective light in `c[0..3]` of `87d6a020f69e1d79`, blurred via `0xc85f8000`):
  dumps (`RPCS3_VR_RTDUMP`, 2736x2736 at 300%) at the same moment differ by ~197k pixels between head yaw 0 and 25 in VR
  (`smap_cmp.png`), ~1.3k between two moments at yaw 0, ~7.7k between yaw 0 and 25 flat, and VR vs flat at yaw 0 by
  ~321k. Not the cause: occlusion queries (Disable ZCull Occlusion Queries + no `zcull_relaxed_sync`: same),
  `game_camera_target_widths [912]` (no change), `camera_blocks [8]` (worse), the camera-position slot. The guest light
  matrix and scene camera are the same at both yaws; the shadow-pass draws are never classified by the probe
  (`why=` logs nothing; the trace has no camera draws before the scene). The skinned spectators' bone rows `c[28..90]`
  vary over time in flat too, so the dumps are confounded by animation timing and by when in the frame the dump
  lands (the map is reused as a blur target). Next: dump the map right after the last shadow draw (a capture hook at
  the end of the 912 pass), and a frame-exact A/B (same frame number after load) before concluding what changes it.

## Fixed 2026-10-08 (fork 9d39f9c93): bird and car shadows slid with the head

Frame-matched tests (fresh load, same delay; pitch alternating -15/-20 within one run; shadow map dumped just before
the road's first draw with `RPCS3_VR_RTDUMP` `prog=1965d57fee836671`, script `tools/re/sr_pd_test.sh`): the map changed
with the head pose (~160k pixels at -20 vs ~3k at -15), while the game's draws and constants were identical. A
temporary log of HUD-boxed draws showed the shadow-map passes (`819644c26148110e`, `52b1a611ea2a63a8`, the blur
`f780e2c460d9eba2` into `0xc8250000`/`0xc85f8000`, 912x912) going into the head-fixed HUD box: `vr_is_passthrough_hud`
compared the target's width with the latest camera target, which here is often a small view (the 512x512 rear-view
mirror, the 384/768 trackside screens). Fix (generic, for profiles with `hud_display_buffers_only`): only
display-buffer draws can be passthrough HUD. After: the map no longer depends on the pose, the shadows are the same at
-15 and -20, and VR matches flat at the same moment (`fx_sheet.png`, `fix_flat_vs_vr.png`). GT5 (the other profile
with the key): HUD and mirror boxed, 120 Hz; SEGA Rally 72 Hz (`evidence/vrtest/2026-10-08-1516-sr-hudfix`).
Needs Matt's headset check.

## Open (Matt, headset, 2026-10-08 evening): very high CPU use and stutter in races

Racing around a track: very high CPU usage and stutter.

2026-10-08 evening, measured on the simulator (300%, `vrtest_segarally_race`, holding R2 for 60 s, fresh load):
- **CPU:** rpcs3 uses 1.5-2.0 cores the whole drive (about 12% of this 16-thread CPU), at 72 and at 90, with and
  without *Disable SPU GETLLAR Spin Optimization* (90 Hz: 1.3-1.8 cores on, 1.5-2.0 off; 88.9 / 89.0 FPS). The
  busiest threads are the game's SPU physics/tessellation threads (20-30% of a core each). Not reproduced as "very high":
  if Matt saw high CPU, check his run for the old cryptominer (it was removed 2026-10-08 after his earlier tests) or a
  first run compiling shaders/SPU code (here only in the first 5 s after load).
- **Stutter:** at 90 Hz the race drops to 84-86 FPS for several seconds in dense sections (33-36 s and 42-47 s into
  the drive; render thread), plus a 33 ms hitch: on a 90 Hz headset that is the stutter. At 72 the same drive holds
  71.5-72.0 throughout.
- **Fix (fork 501898a82):** the profile's `default_fps` is now 72 (90 still selectable in the VR menu, `max_fps 0`).

## 2026-10-09: holds 90 Hz (fork f0087d552)

Matt: fix it properly, optimise for 90 (72 is not the answer). Measured with `tools/re/sr_drive.sh` (fresh load of
`vrtest_segarally_race`, Vblank 90, R2 held 60 s, per-second frame stats; `sr_score.sh` counts the seconds under 88 FPS
over seconds 10-52). Run-to-run spread is large (the same setup gave 1 and 9 s), so each setting was run 2-3 times.

What limits it, in the dense sections (2-4k draws a frame):
- **Draws:** the Wider view patch widens the game's own frustum, so draws grow with its Scale: mean 1790 at 1.0, 2054
  at 1.5, 2370 at 2.0 (max ~4000). The RSX thread costs ~3 us a draw; the VR eye transform ~0.55 us of it.
- **GPU:** 82-100% busy on the RTX 5090 at 300%. Per dense frame: scene 6.0 ms, the 912x912 shadow map 1.6 ms, its
  one-draw 912x912 blur 1.6 ms, the 512x512 reflection map 1.4 ms (all scaled 3x like the view).
- No CPU thread is saturated (SPU physics/tessellation 20-30% of a core, RSX 15-20%, main 3-5%); the frame is a chain.
  Not helping: SPU Block Size Mega, Accurate ZCULL stats off. Wider view 1.5 or 1.75 leaves holes in the ground at the
  lower corners with the head yawed 20 degrees (`evidence/segarally/wider_view_1.5_vs_2.0_poses.png`).

Changes:
- **`culling_scale_f32`** (new key): the Wider view Scale word `0x4d7180` is written each frame from the head pose: the
  smallest scale whose frustum holds both eyes' frustums, + 2 degrees (rises at once, falls 0.01 a frame). ~1.5 looking
  ahead, 2.0-2.4 at 20 degrees of yaw, 2.5 (max) at 35. Head poses on the simulator (0, yaw -20/+20, pitch 10, roll 15)
  are filled (`culling_scale_head_poses.png`); at yaw -35 the cap leaves a sliver at the outer edge (fixed 2.0 did too).
- **`camera_block_cache: true`** (new key): 95% of the left-eye camera draws repeat the previous camera block; their eye
  transform is copied. Pictures with it on and off differ no more than two runs with it off (2.1-2.4% vs 3.1% of pixels,
  animation). Small gain alone (eye constants 0.57 -> 0.53 us a draw).
- **`min_scalable_dimension: 912`**: the shadow map, its blur and the reflection map stay native: ~3 ms of GPU a frame.
  The car's shadow edge is a little softer (`min_scalable_912_shadow.png`), otherwise the same.
- Game config: Multithreaded RSX on (1-3 s under 88 vs 3-5 without).
- `default_fps` back to 0 (90 Hz).

Result (final profile, 3 runs each): Multithreaded RSX on: 89.5-89.7 FPS mean, 1-3 s under 88, min 84.4-86.9, late
frames 0.05-0.26%; off: 89.6-89.7, 3-5 s, min 86.2-86.6, late 0-0.08%. Before (fixed 2.0, nothing else): 88.1-88.5,
11-15 s under 88, min 70-81. Headset check needed: 90 Hz feel in races, the scenery at the view edges when glancing
around (pop-in as the scale catches up), shadows.

## 2026-10-09: hangs before a race (Matt)

- Clicking through the menus to start a race hangs on a black screen before the race loads. The regression states
  load mid-race, so they skip this path: reproduce from a fresh boot through the menus (`tools/re/sr_boot.sh`).
- Suspects, all new since the last working boot: the profile keys from fork f0087d552 (`culling_scale_f32` writes
  `0x4d7180` every frame, also in menus and loading; `camera_block_cache`; `min_scalable_dimension 912`),
  Multithreaded RSX on in the game config, and the `vr-eye-shape` branch build in `bin/`. Try each off in turn.

**Fixed (fork f2c09242b, on `openxr` and `vr-eye-shape`).** Reproduced from a fresh boot with VR on (`-Probe render=1`;
without it the run is flat and does not hang): the log ends with `VM: Access violation writing location 0x4d7180
(read-only memory)` from the RSX thread at 0:40 (title screen), then "Emulation has been frozen". `update_culling_scale`
wrote the Scale word with a plain pointer; the word is in the patch's code cave (the code segment's last page), read-only
on a fresh boot. It now writes through `vm::get_super_ptr`. Same run after the fix: no fault, menus, the pre-race
flyover, then the race in stereo with the HUD. Lesson: a profile key that writes guest memory needs a fresh-boot run,
not only the regression savestates.
