# Blur (BLUS30295 v01.00) - findings

Disc 01.00, PPU hash `PPU-3b47310f79296f8852107bb54e5522b797961998`, TOC `0xe5d230`. Own engine (Bizarre
Creations), libgcm directly (no PSGL). Evidence: `plans/evidence/blur/`.

## Running it

- **Needs `Write Color Buffers: true`.** Without it the game runs (30 FPS, audio) but the screen stays
  black: the frame is built from render targets in main memory (G-buffer `0x30540000`, light buffer
  `0x31600000`). Accurate RSX reservations / accurate xfloat are not needed (tried, reverted).
- Scripted route (keyboard pad template): title `Return`, then `X` x8 with ~5 s gaps: Single Player >
  Career > Proving Grounds > Race (Barcelona Oval) > event > car (Ford Focus RS) > race start.

## Frame rate (2026-09-23)

- The vblank handler (`0x33bb70`, registered at `0x344064`) counts a countdown at `*(toc+0x2918)` down and
  flips the next queued buffer when it reaches 0. The countdown is reloaded at `0x349f80` from
  `renderer+0x101c8`, which `0x699960` sets from a global setting (`*(toc-0x3f4c)+0x24` = 2).
- Patch `BLUS30295-patch.yml` (installed as `bin/patches/BLUS30295_patch.yml`): `li r12,1` at `0x349f80`.
  Menus and races then run at the Vblank Rate.
- **Game speed is real-time.** Throttle held 3 s from the grid (same car, same spot), speedometer after:
  37 mph at 30 FPS (unpatched), 40 mph at 60 FPS, 44 mph at ~80 FPS (Vblank 90). A frame-locked clock would
  have given 2x and 2.7x; the few mph are key/screenshot timing. So no refresh-rate constant is needed and
  the profile sets `match_headset_refresh_rate: true`.
- Performance here (100% resolution, desktop): mono ~80-84 FPS at Vblank 90 (CPU-bound), stereo ~45-50.
  `config_BLUS30295.yml` has `Vblank Rate: 90`.

## VR profile (2026-09-23)

`bin/vr_profiles/BLUS30295.json`, from the in-emulator generator (race, driving) then edited by hand
(`plans/evidence/blur/generated-in-emulator-BLUS30295.json` is the generator's output).

- Camera `c[4..7]` `row_vectors` (619 of ~800 camera-view draws per frame), plus `c[32]` (the rear-view
  mirror camera and a few effects) and `c[12]` (a bare projection used by the deferred light volume at
  draw ~979, with the view in `c[0..3]`). Camera position `c[145]`. Near plane 0.1 -> `eye_baseline` 0.064
  (metres). Projection A = 0.883 (97 deg horizontal).
- **3D HUD.** The HUD is not orthographic: it is drawn with `c[32..35]` = a projection with no rotation and
  `w = z + 42.65`, i.e. in the camera's own space 42.65 units ahead. New profile key
  `screen_space.depth_offset_projection` puts such draws in the HUD box in the headset. `bare_projection`
  is deliberately *not* set: the light volume's `c[12]` is an exact bare projection and must follow the head.
  (On the desktop stereo path the HUD keeps far-object disparity, +14 px at 1280; only the headset path
  uses the HUD box.)
- **Rear-view mirror.** Its camera renders to a 320x180 target (draws 8-38). New profile key
  `game_camera_target_widths: [320]` keeps that target on the game camera in both eyes, so the mirror does
  not turn with the head. (The 320x180 bloom targets have no camera block, so they are unaffected.)
- **Renderer fix:** the opaque scene is 4x MSAA (`aa_mode 3`, 2560 pitch) at `0xc0af0000`/`0xc1220000`,
  resolved to `0xc1950000`/`0xc0750000` by 0.5x-scaled NV3089 blits in 1024+1024+512-column chunks. The
  right-eye blit mirror only did 1:1 copies, so the right eye had no opaque world (only particles and HUD).
  `VKGSRender::vr_mirror_blit` now repeats scaled blits through the texture cache's own blit on the
  right-eye surface store (`vk::texture_cache::blit_vr_right`, only when both ends are right-eye surfaces,
  never flushed to guest memory).
- Stereo on the desktop (`sbs-race-stereo.png`): far scenery +14 px (expected 2 x 0.011 x 640 = 14), mid
  track +10, car +6.
- Rotation audit (`audit-yaw25-race.png`, yaw 25): world, cars and sky follow; HUD moves with it in the
  audit only (the audit does not apply the headset HUD box).

Open:
- Under rotation the car's shadow can stay where the unrotated view had it (seen once at the start line).
  Likely the deferred light/shadow pass rebuilding positions from constants the profile does not rotate.
- The mirror's motion blur shows streaks in the right eye when moving (its history buffer).
- Headset run not done (scale, HUD box, comfort). Stereo FPS is well below 90 at 100% here.
