# Sonic & All-Stars Racing Transformed (BLUS30839, disc 01.00)

Added 2026-10-04. Profile `bin/vr_profiles/BLUS30839.json` (generated in a race, hand-fixed), patch file
`bin/patches/BLUS30839_patch.yml`; copies in `rpcs3/vr-non-working/`. No community patches exist for this game.
Executable `PPU-ffd4f8966a67f15ea02a903c3a9bc96c39fa7087`; decrypted copy `tools/re/elf/BLUS30839.elf` (+ `.imports`).

## Boot

SEGA logos, title (Start), autosave notice (X), a "new content" popup (X), main menu. Career > Single Race (Right x3)
> cup (X) > Ocean View (X) > Medium (X) > Sonic (X); the track flyby skips with X. Savestates (made by me, nothing of
Matt's in the folder): `sonic_race0` (start grid, before the countdown), `vrtest_sonic_race` (mid lap 1, regression
state; made flat with the unlock patch), `sonic_rock` (beside the waterfall rock, made with Wider view 3.0).

## Frame rate: "Unlocked frame rate (follows Vblank Rate)"

- Native 30: the game's GCM vblank handler (`0x21821c`, registered at `0x217bd0`) releases the flip label every
  `[0xc2e4d8]` vblanks (2, set at init from a config field at `0x217bec`). The patch loads 1 there instead
  (`0x218230`: `li r5, 1`). `Apply To Savestates`.
- Game time is measured, not stepped: memory dumps at 60 FPS (`memclock.py`) show the game clocks at 1.0x, and the
  same savestate at Vblank 60 / 120 / 180 reaches the same track positions at the same wall-clock times
  (screenshot timelines 2 s apart, `tools/re/tlp*`). Profile `max_fps 0`.
- Flat ceiling with the patch: 130-140 FPS racing (180 on light screens), RSX thread ~7 ms.

## VR profile

Generated in the race at Vblank 90: `column_vectors c[138, 4, 0]`, HUD `c[138]` (pixel ortho), `hud_box_after_shader`
(the minimap mask), near 0.125 = metres (`eye_baseline 0.064`), 99% of depth-tested scene draws covered. Hand fixes:
- `depth_offset_projection` removed: the generator took 262 camera draws for a 3D HUD at a fixed depth, but in the
  headset that put a dark band (a deferred shadow box) into the HUD box (Known traps: Super Stardust HD).
- `by_target_width` (640 wide at 0.845x) removed: the only 640-wide camera draws are the shadow-cascade boxes (their
  matrix is the camera times the box size), so the rule was not a real half-resolution camera.

## Culling: "Wider view (VR culling)"

The race camera is 50 degrees high on the grid (up to ~80 with boost; the record at render camera `+0x38`, written at
`0xb8024` from the game camera `+0x144`). Turning or looking up showed the sky and scenery ending at the game's
frustum. The patch multiplies the field of view where it is copied (`bl` to a cave in the unused end of the code
segment, `0xbe8f90`) by a Scale (1.0-3.0, default 3.0) and clamps to 150 degrees. Found by snapshotting every f32
that looked like the FOV (`tools/re/valtrack.py snap`), driving, and listing what changed (`valtrack.py check`), then
a PPU write watch on the word. All readers of the FOV (projection, the shadow cascade fit) see the widened value.
On the simulator, 3.0 fills the view straight, turned 25 degrees and looking up 25 degrees; 2.0 still cut the sky
when looking up.

## Frame rate in VR (OpenXR Simulator, 300%, `vrtest_sonic_race` holding R2)

| Wider view | 90 Hz | 120 Hz |
|---|---|---|
| 1.0 (off) | 0% late | **120.0 FPS, 0.21% late** (RSX 5.3 ms) |
| 2.0 | | 112.2 FPS, 0.93% late |
| 3.0 (default) | **89.8 FPS, 0% late** (RSX 8.8 ms) | 107.2 FPS, 1.17% late |

Sustained: **90 Hz** with the default patch, 120 Hz with Wider view off.

## Headset checks (simulator)

- Race: stereo and HUD box right, straight / turned / pitched; pause menu (panel and menu boxed, the world behind
  stays); title screen (3D sky world in the headset view, logo boxed); intro movie on the world-fixed screen.
- **Fixed 2026-10-04 (fork 1aef7457b): distant soft shadows differed between the eyes.** Profile `depth_remap_programs:
  [ed46d28a122d7235]`, `depth_remap_ray_texcoord: 1`, `depth_remap_xyw: true` (new renderer variant). Rock and pillar
  now lit the same in both eyes, straight / turned / pitched, multiview and two-draw; 90 Hz kept (89.7, 0% late).
  History: The game draws shadows as deferred cascade boxes
  (`ed46d28a122d7235`, light-space lookup from the depth buffer with fragment constants built for the game's camera).
  The full-resolution cascades are right in both eyes; the distant cascades are drawn at 640x360 (with a half-res
  depth copy and a split-depth quad), downsampled, blurred and upsampled under them, and these come out wrong in
  parts of one eye's view (a rock face dark in the right eye only, a track region dark in the left eye with the head
  turned). Shown: hiding that pass at 640x360 (`hide=ed46d28a122d7235@c0dc0000`) makes the eyes agree but loses the
  tree shadows on the track. Not the cause: the shadow map (identical in both eyes, RTDUMP), the per-eye depth, the
  split quad (pure NDC), the stencil draw, right-eye batching, multiview vs two-draw, Wider view, c[4], the half-res
  stereo rule. `depth_remap_programs: [ed46...]` fixed straight-ahead shadow placement but made a hard seam with the
  head turned, and needed renderer changes for this program (its clip position is packed as (x, y, w), and the mask
  is 640x360 against a 1280x720 depth); reverted. Next: dump the 640 mask per eye while turning the head on a paused
  frame, and find which input differs (the half-res depth copy's sampling, or the cascade selection).

  **2026-10-04 evening:** per-eye RTDUMPs (`sonic_rock`, two-draw, 100%): the half-res depth `c0cd0000` (built at
  draw 1128-1129 from the full depth `c0840000`) is right in each eye (matches that eye's full depth halved). The
  640x360 mask `c0dc0000` after the cascades (1130-1133) has the rock and pillar lit in the left eye and fully
  shadowed in the right. `why=` shows only `c[0]` (clip x) changes per eye. The fragment program (fp 560) rebuilds the
  position as: uv from `tc0` = clip (x, y, w) packed; view depth from the depth texel (`fc1`, `fc3`, `fc4`); view
  position = normalize(`tc1`) scaled to that depth, where `tc1` is a view-space ray the vertex shader computes with the
  game's view (not a camera block), then light space via `fc7`/`fc8`/`fc15`. So the ray is the game camera's while uv
  and depth are the eye's. A fix must remap both `tc0` and `tc1` (the existing `depth_remap_programs` path replaces
  only the position varying and assumes (x, y, z, w) packing and a full-size depth). The eye-invariant target fix
  (fork a3d6d1822) does not change it (the shadow map was already identical per eye).

## Head poses on the OpenXR Simulator (real head pose, 2026-10-05)

Straight, yaw +-20, pitch +-10, roll 15 (`posecheck.sh`, 300%): world and HUD right, HUD in the world-fixed box at every pose. Sheet `evidence/headpose-2026-10-05/pc_sonic_sheet.png`.

## Open: horizontal lines and per-eye shadow (Matt, 2026-10-05)

Matt's state `BLUS30839_1_0` shows graphical corruption (many horizontal lines across the image) and a shadow that
differs between the left and right eye. Not investigated yet. First steps: load the state on the simulator,
take per-eye shots, and check whether the shadow is the cascade program `ed46d28a122d7235` (already remapped) or
another shadow pass; for the lines, check flat vs stereo and with/without Wider view.
No sound in that run was a test leftover (`Audio Renderer: Null` in the custom config), restored to Cubeb.
