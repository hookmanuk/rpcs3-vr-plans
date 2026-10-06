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
