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
  **Logged (temporary, reverted):** the remap's game projection scales follow Wider view (A 0.151 / B 0.268 at 3.0,
  0.605 / 1.075 at 1.0) and the eye -> game matrix is exact (`store_depth_remap`: eye^-1 x game of the stored camera
  draw); its x-on-depth term stays ~0.455 at both settings while its x scale follows A, so the remap is not the simple
  culprit. Remaining suspects: the cascade box volumes (stencil `2fe8ebfb47d877be`, depth-tested) clipped differently
  per eye at the 150-degree projection, or the ray variant's assumption of a symmetric game projection. In the masks
  the right eye has the loop's ring shadow that the left lacks, so which eye is wrong is not settled: compare with a
  flat 3.0 mask (VR off, same moment) first.
- **Flat at Wider view 3.0 (VR off): the game's own shadow mask is already broken** (`flat_wv3_mask.png`): large flat
  shadowed areas and streaks across the ground. The shadow cascades cannot cover a 150-degree frustum, so the per-eye
  differences in VR are reads of a broken mask, not a VR renderer fault. **Options for Matt:**
  1. Keep 1.0 (render FOV widened x3): view filled, broken shadows, loop bars.
  2. Cull-only widening (tried as *Wider view* 2.0, see above): view filled, game-FOV shadows and projection; geometry
     beyond the game's own frustum still gets per-eye shadow differences (outside the cascades) and the loop bars stay.
  3. Wider view 1.0 (off): shadows and loop right, sky and scenery cut when turning or looking up.
  The loop bars are culling-related (they come with any wider culling).
No sound in that run was a test leftover (`Audio Renderer: Null` in the custom config), restored to Cubeb.

## Proper fix in progress (2026-10-06)

- The getter `0x1dd760` ("cull-only" 2.0 above) is not cull-only: flat with it the game renders a 150-degree fisheye.
  It builds the camera's projection; `0x1e1174` multiplies it with the view into the camera object, then `0x1e3dfc`
  copies the view-projection (transposed) to `0xcf1810` and the 0x80-byte block `0xcf1800` (header, VP, viewport
  640/-360/1, 640.5/360.5) into a per-frame buffer whose pointer (`0xcf1884`) goes into every SPU render job
  descriptor (`0x1e5734`); `0xcf1888` is a per-object 3x4. So the SPU jobs transform and cull with one matrix.
- **Candidate *Wider view* 3.0** (`tools/re/son_wider_v3_candidate.yml`, not shipped): the camera is built twice a
  frame, first at the game FOV (render matrices for the RSX and the SPU jobs), then widened with the global copy
  skipped, so only the camera object's own matrices are wide (caves at `0xbe8f90`/`0xbe8fbc`/`0xbe8fe8`, calls told
  apart by return-address bit 2; `0xb8024` restored). Result (`son_v3_twocall_sheet.png`): near scenery and the loop are
  filled, with no blue slits on the loop and the pillars' shading alike in both eyes; but the sky dome and the distant
  land and sea still stop at the game's frame (cyan beyond): those are culled by the SPU jobs with the narrow matrix.
- Next: find the SPU job's frustum test (the job image the descriptor at `0x1e5708` launches) and widen only its clip
  comparison (an SPU patch), keeping the transform. Then check shadows and frame rate.
- **Candidate 4.0** (`tools/re/son_wider_v4_candidate.yml`): a `calloc` cave builds the camera at the game FOV, then
  widened, then copies the first build's block back over `0xcf1800`. Same result as 3.0 (`son_v4_restore_sheet.png`):
  near scene filled, render normal, far sky/land/sea cut at the game's frame. Reason: `0x1e3cf8` (from `0x1e3ff4`)
  re-copies `0xcf1800` into a fresh SPU buffer per render pass and updates `0xcf1884`, so the SPU jobs always see the
  render block. The SPU jobs both build the draws (transform) and cull from that one copy.
- **Remaining step:** an SPU patch that widens only the job's clip/cull comparison. Needs: the job image (descriptor
  built around `0x1e5588`..`0x1e5800`, list head `0xcf188c`), its SPU disassembly, and the frustum test on the matrix
  it DMAs. RPCS3 SPU patches are keyed by the SPU program hash.

## Fixed 2026-10-06: Wider view 2.0 (cull-only)

The SPU render job (image at `0xb54280`, 0xcfa qwords, launched from the descriptors built at `0x1e5628`) tests each
object against the frustum with six `fcgt` at job offsets 0x5730..0x5758 (`0xb599b0`..`0xb599d8`). Forcing them false
(`il rt, 0`) with the two-build camera (candidate 4.0) gives a full view: sky dome, distant land and sea, the loop
without slits, shadows alike in both eyes (`son_v5_sheet.png`, fly-by poses `pc_son5b_sheet.png`, race poses
`pc_son5_sheet.png`). Frame rate went up: 152 FPS vs 114 with 1.0 at Vblank 180, 300% (the narrow render frustum
draws less). Shipped as *Wider view (VR culling)* 2.0 (fork vr-non-working). Headset recheck: the race, the loop,
shadows near the edges of the view.

## Not ready (Matt, headset, 2026-10-06, Wider view 2.0 build)

1. **Shadows misaligned between the eyes:** they look wrong. Not investigated. To check first: the profile's shadow
   remap (`depth_remap_programs: [ed46d28a122d7235]`, `depth_remap_ray_texcoord`, `depth_remap_xyw`) was tuned on
   2026-10-04 while 1.0 widened the render camera; with 2.0 the render camera is the game's own again, so the remap
   (or its need) may have changed. A/B with the remap keys removed, per-eye RTDUMP of the shadow mask `c1d38000`.
2. **Shadows in the wrong place on the track:** some stay in the middle of the track while driving. Not investigated.
   Candidates: the shadow cascades are fitted from the camera object, and 2.0 rebuilds that object widened for culling
   after the render copy, so code reading it later for the shadow fit may see the wide camera (the 1.0 note says the
   cascade fit reads the FOV too); or blob shadows (cars, items) projected with a stale or other-eye matrix.
3. **Feels like 60 FPS inside 90 Hz** although the frame counter shows 90 locked. Not investigated. Candidates: the
   game advances its simulation at a fixed 60 Hz and the extra frames repeat positions (check object positions per
   frame with `RPCS3_VR_PEEK`, as `peekspeed.py`: distinct values per second); or frame pacing (each pair of frames
   shown unevenly). Was it there with 1.0? Ask Matt / A-B both versions.

Stopped here at Matt's request.

## 2026-10-06: "60 FPS inside 90 Hz" confirmed

`RPCS3_VR_PEEK` of the render view-projection copy `0xcf1810` (16 words) every frame while driving
(`vrtest_sonic_race`, Vblank 180): 700 frames in 5.6 s (125 FPS), 54% identical to the previous frame, so the camera
updates about 58 times a second. The unlock patch only frees the flips (the vblank handler `0x21821c` just releases
the flip label); the game thread still advances at about 60 Hz and the render thread (`0x2144a0..`, command-list
replay) re-presents its last frame on the other vblanks. Likely a fixed 1/60 simulation step taken from measured time.
Tried: poking each 1/60 float in the ELF (`0x30611c` .. `0x85c894`, 14) to 1/120 live: no clear change, but the
measure was confounded (the unattended car stops, and a still camera repeats too). Next: find the step with a counter
that increments once per simulation step (not the camera), or trace the game thread's wait on the render thread.
