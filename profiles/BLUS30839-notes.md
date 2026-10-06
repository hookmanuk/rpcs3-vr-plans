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
differs between the left and right eye. 
**Investigation 2026-10-05 (night):**
- The state is the pre-race fly-by (character intro, "CONTINUE"). ~18 s after loading, the game pauses with "WARNING! A
  Controller has been removed. Please reconnect to continue." (the state was made with Matt's pad); Cross on the
  keyboard pad accepts it. While that dialog is up the headset view stays frozen on the last frame before it (VR frame
  stats stop too) though the desktop window shows the dialog: not yet looked at.
- **The lines:** rows of short light-blue bars on the inside of the loop (sky seen through gaps in the track surface),
  `evidence/sonic-lines-2026-10-05/son_v4z.png`. Present at Wider view 3.0 and 2.0, gone at 1.0 (same moments,
  `son_w_sheet.png`); flat at 3.0 shows the same ragged gaps. So the game's own rendering at the widened FOV (most
  likely level of detail picked from the render camera's FOV), not the VR renderer.
- **The per-eye shadow:** pillars lit in the left eye and black in the right (`son_v_sheet.png`); at Wider view 1.0
  both eyes agree (`son_w3_both.png`); 2.0 still differs. The cascade fit reads the widened FOV too, and this frame
  has none of `ed46d28a122d7235` (the remapped cascade program).
- Direction: widen only the culling, not the render camera's FOV (as Asura's Wrath: a culling frustum copy), so
  projection, LOD and shadow fit keep the game's FOV. Needs the culling code (readers of render camera `+0x38`).
- **Readers traced (2026-10-06):** render camera at `0x30696680` in `vrtest_sonic_race` (FOV 2.618 at +0x38, aspect
  1.778, near 0.25, far 20000). PPU read watch (interpreter) on +0x38: the projection build `0x1dd974` (from `0xb8004`),
  a getter `0x1dd778` (from `0x28a308`), and five render-pass setups under `0x244e24` that all compute
  2 atan(aspect tan(fov x 0.5)) from a per-function 0.5: `0x23c6a0` (table `0x23c520`), `0x241fa0` (`0x241c60`),
  `0x247bf8` (`0x247974`), `0x248d50` (`0x248aa8`), `0x24957c` (`0x249510`). Poking all five 0.5 -> 1/6 (they see the
  game's own FOV) changes neither the loop's bars nor the per-eye pillar shadow, under LLVM and under the interpreter
  (`son_pa`, `son_pi` sheets). Wider view 1.5 still has both, and culls the view edges (`son_s15_sheet.png`). Left: the
  getter `0x1dd778`, and SPU code (SPURS jobs reading the camera by DMA are invisible to the PPU watch). Next: trace the
  getter's callers' use, and an SPU-side search for the camera address (RSX/SPU DMA log of `0x30696680`).
- **The culling frustum is the getter `0x1dd760`** (called from `0x28a304`; builds a perspective matrix from FOV
  `+0x38`, aspect `+0x3c`, near/far `+0x40/+0x44`). Cave at `0xbe8fc0` (`bl` from `0x1dd778`), interpreter + POKE:
  - FOV / Scale there at Wider view 3.0: the scenery is culled to the game's frustum again (`son_pg_sheet.png`).
  - **Wider view 1.0 + FOV x3 (cap 150) there only:** the view is filled, as at 3.0, while the render camera, projection
    and shadow fit keep the game's FOV (`son_pc_sheet.png`). Cave: `lfs f28,0x38(r3); lis r12,0xbf; lfs f0,-0x7018(r12)
    (3.0 at 0xbe8fe8); fmuls f28,f28,f0; lfs f0,-0x704c(r12) (cap); fsubs f13,f28,f0; fsel f28,f13,f0,f28; blr`.
  - The bars at the top of the loop are still there with it: they come with the wider culling (objects or a level of
    detail the game never shows from that angle), not with the render FOV. The per-eye pillar shadow was not judged
    reliably in this run (the shots are 4 s apart under the interpreter).
  Next: a patch version doing only the getter widening (verify under LLVM, check the shadows and frame rate), then look
  for an LOD decision in the cull pass (`0x28a2c0` onwards) to keep the loop's full mesh.
- **Tried 2026-10-06, reverted:** *Wider view* 2.0 doing only the culling getter (cave at `0xbe8f90`, `bl` at `0x1dd778`,
  and `0xb8024` restored to `lfs f1,0x144(r31)`: Matt's savestates hold version 1.0's `bl` there, and without the
  restore everything was culled). Under LLVM the view fills as with 1.0 (`son_cullonly_sheet.png`), but the loop's bars
  remain and the pillars at the left are still lit in the left eye and black in the right (`son_cullonly_eyes.png`).
  So the per-eye shadow is not the render FOV either: it appears whenever culling is wider than the game's view
  (objects the game never draws at the screen edge get a shadow lookup from cascades fitted to its own frustum, which
  differ per eye). Next: the shadow cascade fit's coverage (make it fit the culled area), or a per-eye shadow-mask
  program to remap, from an inspector capture of this frame (none taken yet for Sonic).
- **Shadow mask per eye (2026-10-06):** inspector capture of the fly-by: the deferred shadow mask is `c1d38000`
  (1280x720, white = lit), drawn by `ed46d28a122d7235` cascade boxes with stencil passes `2fe8ebfb47d877be` (draws
  1414-1423, three cascades), plus the 640x360 pass into `c0dc0000`. Per-eye RTDUMPs (multiview off, 100%):
  `m_wv1.png` (Wider view 1.0): masks agree. `m_cur.png` (3.0, profile as is): the masks differ along the cascade
  boundaries (the right eye has a shadowed ring over the loop and the left pillars). `m_noremap.png` (depth remap off):
  they differ too, differently. Hiding every `ed46` draw removes the loop's shadow on the track but leaves stale mask
  contents, so that test proves nothing. Also tried, no change: cascade-fit FOV readers x2 with the cull-only patch
  (`son_cw`). So the 2026-10-04 ray remap is right at the game FOV but not when the game's projection is widened
  ~3x: next, check `game_projection_scale` (A, B) against the cascades' own camera rows at Wider view 3.0 (log them for
  `why=ed46d28a122d7235`), and whether the box draws' eye transform and the remap use the same projection.
No sound in that run was a test leftover (`Audio Renderer: Null` in the custom config), restored to Cubeb.
