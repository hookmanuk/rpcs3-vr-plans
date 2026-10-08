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

## 2026-10-06 (later): the game simulates at a fixed 60 Hz (corrected)

New dev measure (fork): `RPCS3_VR_FRAMESTATS` now also prints **new frames/s**, the flips whose first game camera
matrix differs from the previous one. Sonic, `vrtest_sonic_race`, accelerating: **60.0 new frames/s at VR 72, 90 and
120** (flips 72 / 87 / 112-120). So the game steps at a fixed 60 Hz whatever the vblank rate, and the extra flips repeat
a frame: this is Matt's "60 FPS inside 90 Hz". (An earlier peek of the VP copy `0xcf1810` gave ~30/s at 90 Hz and led
to a wrong "CPU-bound" reading, committed briefly; that copy changes every other step.)

Where the 60 Hz comes from is not found yet:
- Not the 14 float 1/60 constants in the ELF: all patched to 1/120 (a patch, applied before LLVM compiles), still 60.
  Live pokes of code-segment constants do not reach LLVM code (same for KH), so use patches for such tests.
- Not the flip interval word `[0xc2e4d8]` (1 or 2: no change).
- `0x276cd8` (an object with double 60.0 and 3) is network retry code.
- Pipeline (code read): main thread `0x212d98` queues the frame and waits in `sys_semaphore_wait([0xcf23f0])` (55-59% of
  its time) for the renderer (`SlRenderer`, loop `0x20cdd8`), which wakes on the flip handler's event (`0x2181e4`,
  port `[0xcf2f30]`, queue `[0xcf2f34]`) and posts the semaphore in `0x214208` / `0x214d70`; renderer frame counter
  `[0xc2e428]`, mode word `[0xc2e434]` (setter `0x20cf1c` writes 2, `0x20cf2c` tests == 2: a candidate 30/60 mode).
- `RPCS3_VR_MEMDUMP` crashed RPCS3 here (14:05); PINE was blocked by a hung instance holding port 28012.
- The game's frame timer (object initialised at `0x3fef0`; update around `0x40380..0x40920`): reads `mftb`, dt =
  ticks / timebase frequency, clamps dt to `+0x170` (0.066 s) when `+0x174`; a busy-wait while dt < `+0x154` (minimum
  frame time, initialised 0 and never set: off); with `+0x184` (initialised 1) it rounds dt down to whole steps of
  1/`[r28+0x14]` (`fctidz`, count at `+0x188`, remainder carried in `+0x180`); `+0x14c` = 60.0 at init, later 1/dt.
  Patching the rounding out (`0x4080c` `beq` -> `b`): still 60.0 new frames/s at Vblank 120. So not this path either.
- Main thread stacks at Vblank 120 (`RPCS3_PPU_SAMPLE_STACK=main_thread`): loop `0x1cdc8 -> 0x1d034 -> 0x37580 ->
  0x3cc40 -> 0x3be..`; each pass calls `0x398f8` (update every module in a list: `0x39994` vcall -> `0xa7880` ->
  `0xbb518`, an entity scheduler over a bitset -> `0xbb740` -> `0xce3fc`/`0xce054` -> `0xf1948`) and `0x39b68` (render
  submit, `0x39be8 -> 0xa7cb0 -> 0x212e7c`, the renderer hand-off wait: 1517 of ~1900 samples). The VR trace shows the
  game draws a full frame on every flip (its targets alternate `c1608000` / `c19a0000` each flip) while the camera
  changes every other flip: render 120, update 60. So some module skips its update when less than 1/60 s has passed.
  Next: find which module's update returns early (break in the entity update, e.g. RPCS3_PPU_TRACE on `0xbb740` with a
  counter per frame), or watch the race clock / car position word per flip with `RPCS3_VR_PEEK` to see it step at 60.

## 2026-10-06: per-eye shadows reproduced (open)

Matt's fly-by state `BLUS30839_1_0`, first frame: the **right eye** has a large dark shadow under the roof of the
building on the right that the left eye and the flat game do not (`evidence/sonic-shadows-2026-10-06/`). Same with:
the profile's depth remap removed (`depth_remap_*` keys), eye-invariant sharing off (`RPCS3_VR_NO_INVARIANT=1`), and
two-draw (`RPCS3_VR_MULTIVIEW=0`). So none of those is the cause. Two-draw RTDUMP: shadow map `c0000000` (1024x3072,
three cascades, 450 draws) has no per-eye copies; the screen-space shadow mask `c1d38000` (pass `ed46d28a122d7235`)
does, and each eye's mask matches its own scene but the right one has shadows the left lacks. The remap matrix is
computed per eye in `apply_render_eye` and written right after it (per eye in both paths). Next ideas: the cascades are
fitted to the game camera's frustum (50 degrees) and the right eye sees past its right edge, where the mask samples
outside the fitted cascade; compare the mask with the cascade split constants per eye, and test a wider culling Scale
(the fit may follow the culling camera). **Tested:** Wider view Scale 1.0 shows the same right-eye shadow, so not the culling camera.

## 2026-10-07: the 60 Hz step, more ruled out

- The main thread's loop runs ~60 times a second; the VR trace's alternating targets per flip are the renderer
  replaying the command list. The main thread blocks in `sys_semaphore_wait([0xcf23f0])` (78% of its samples).
- `SlRenderer` stacks (Vblank 90, 60.8 new frames/s): 78% in `cellSpursEventFlagWait` (`0x219460`, via `0x218138`
  from the loop `0x20ce0c`; import slot `0xbf5b6c`), i.e. waiting for SPU work; 5% on the flip event (`0x218018`); 7%
  polling SPU job counts (`0x259738`). PPU-side `cellSpursEventFlagSet` (slot `0xbf5bcc`, stub `0xa1e384`) is called
  from job-system code at `0x8a2ce8` (bits 0x8000) and `0x8a30c0` (bit 1).
- Not the frame timer's minimum frame time (`+0x154` has no setter for that object; the setters found are other
  types, e.g. `0x1416c8`).
Still unknown where 60 comes from: it holds at 72, 90 and 120 Hz, so it is a time rule, not a vblank count. Next: find
the SPU job/taskset that sets the renderer's flag and whether it is driven by a 60 Hz timer (a `sys_timer` or
`sys_event` periodic source: list the game's timers, `sys_timer_create` / `sys_timer_connect_event_queue` usage).

## Fixed 2026-10-07: 60 Hz simulation (frame patch 2.0)

- **Clocks scale test:** at Core/Clocks scale 200% the game made 116-120 new frames/s at Vblank 120 (60 at 100%): the
  limit is guest time, not CPU or vblanks.
- Cause: a fixed-step simulation. The frame timer (`0x40150..`, object `[0xc14e84]`) splits measured time (`mftb`) into
  whole steps of 1/`[0x402d4]` (60.0, read at `0x40810` via r28 = `0x402c0`), carrying the remainder; at 90/120 Hz
  that is 0 or 1 steps a frame. The step count `+0x188` and total `+0x144` go (`0x75f70`) to a second accumulator
  (`0x1f9938` -> `0x1f9698`) whose step size is `[[[0xc14ee4]+0xdc]+8]` (0.0166667, set at run time, so the ELF's 1/60
  constants did not matter). Each step advances game clocks through commands the renderer replays (`0x28de70`).
- Changing only `[0x402d4]` to 120 gave 120 new frames/s but the second accumulator still stepped by 1/60 (some
  clocks ran 2x). Both together: real time.
- **Patch 2.0:** cave at `0x40810` reads the rate from free word `0xec7ff0` (page tail after the data segment; seeded
  with the game's 60 if zero). **Profile:** `game_refresh_rate_f32: ["0xec7ff0"]`, `game_frame_time_f32:
  ["[[0xc14ee4]+0xdc]+0x8"]`. Without the profile (flat) the word stays 60: unchanged game.
- **Measured (simulator, 300%):** 90.0 new frames/s at VR 90, 119-120 at 120. Real time at VR 90: memory dumps 2.5 s
  apart vs the unpatched 60 Hz run: game clocks 0.920 vs 0.932 per wall second, object speeds peak x1.0 (3458 positions,
  outliers within the run-to-run noise of two unpatched runs).
- Tools: `tools/re/spudis.py` (minimal SPU disassembler for job images in a PPU ELF), scratchpad `clockfind.py` (clock-like
  floats between two dumps, rate per wall second).

## 2026-10-07: per-eye shadow, narrowed (open)

- The screen-space shadow mask `c1d38000` is built per cascade: program `ed46d28a122d7235` draws a 660-vertex volume per
  cascade through `c[0..3]` (a projection times a view-space scale; near/far in row 2: 2.86, 9.03, 12.5, 34.1, 200),
  each paired with a stencil draw `2fe8ebfb47d877be`; a coarse 640x360 pass `c0dc0000` comes first and `f7863935`
  seeds the mask. The fragment program rebuilds the view position from the depth (fc4-fc6) and the view ray (tc1,
  replaced by the profile's ray remap), then projects with one view-to-light matrix fc11-fc13 into the 3-cascade map
  `c0000000` (1024x3072).
- Fly-by state, building at the right: **flat has no shadow on the tower and roof; the left eye matches flat; the right
  eye has a dark tower and roof shadows.** With `eye_baseline` and `per_eye_separation` 0 (both eyes at the head's
  centre) **both eyes show the wrong shadows**. So it does not come from the eye offset but from each eye's projection
  (the field-of-view remap); the left eye being right is probably chance
  (`evidence/sonic-shadows-2026-10-06/roof_normal_vs_zero_separation.png`, `roof_flat_reference.png`).
- Next: compare the mask pass's inputs per eye for one tower pixel (the rebuilt view position against the flat game's),
  with the remap on and off: either the remapped ray or depth (`vr_depth_remap[4]` scales, the depth linearisation
  fc4-fc6 on the eye's depth) or the cascade volume selection (`c[0]` remapped as a camera block) is off for points away
  from the game view's centre.

## Fixed 2026-10-07: per-eye shadows (fork eea6166d7)

Cause: the shadow pass's ray remap scales the view ray by 1 / the game projection, taken from the probe's cached
projection, which follows whichever camera drew last. A debug log of the refreshes showed several projections per
frame: the scene camera (about 0.47 x 0.84), the shadow-map and other cameras (0.15 x 0.27, 3x wider) and the shadow
volumes themselves (a projection times a non-uniform scale). The mask pass got a wrong scale, so its rebuilt view
positions were off in proportion to the distance from the view's centre: wrong cascades and lookups away from the
centre (the right eye's dark tower and roof; the game FOV log showed 162.9 x 150 degrees). Fix: `depth_remap_programs`
draws no longer refresh the cached projection, and the ray scale uses the last projection measured on a draw into a
view target. Fly-by: tower and roof lit in both eyes as in flat; four fly-by shots match between the eyes
(`after_fix_roof_left_right_flat.png`, `after_fix_flyby_pairs.png`). R&C 1's shadow pose check unchanged. Matt's
"shadows stuck in the middle of the track" is probably the same fault (shadows placed with the wrong ray); recheck
in the headset.

## 2026-10-07 (later): still wrong in Matt's headset; ray signs fixed (fork 861614444)

Matt (headset, new state `BLUS30839_1_2`, unpause): shadows still mismatched per eye; the pagoda is much darker in the
left eye. Per-eye mask dumps against the flat game's mask: flat has the pagoda and statues lit and the cars' own
shadows; **both** VR eyes had black blobs on the pagoda (left worse) and no car shadows. The remap's ray had the wrong
signs: it is built as (x/A, y/B, +1), but the game's view looks down -z (its pass divides by -z), so x and y must be
negated. `RPCS3_VR_REMAP_RAY_SIGN` variants: `--` matches flat (`state_1_2_ray_sign_variants.png`), now the default.
After: pagoda and statues lit in both eyes, car shadows back, at yaw +-20 and pitch 10
(`state_1_2_before_after_both_eyes.png`). The earlier "fixed" (eea6166d7, ray scale from the scene camera) was needed
but not enough; the 2026-10-04 tuning had been judged with the wrong scale.

## 2026-10-07 (third pass): the volumes' eye offset (fork 81fedb836)

Matt (headset, after the sign fix): track shadows fine, but the right eye still darker (the totem above the car, the
green lumps' shadows differ between the eyes). Per-eye mask dumps: each eye shadowed its own outer side (left eye the
hedge on the left, right eye the cliff on the right); with zero eye separation both masks matched flat. Cause: the mask
volumes `ed46d28a122d7235` and the stencil pre-pass `2fe8ebfb47d877be` draw through a projection times a non-uniform
scale; the probe sizes the eye offset by each matrix's own clip x per unit, which that scale distorts, so each eye's
volumes covered shifted pixels and the depth remap (built from the volume) shifted the rebuilt positions. A debug log
showed the stencil pass had also become the "scene" source (X with -5.2/+5.3 terms). Fix: remap passes and the new
profile key `depth_remap_volume_programs: ["2fe8ebfb47d877be"]` take the last scene camera draw's eye transform as a
clip-space map X = scene game^-1 x scene eye (their rows = game x X) and the remap is built from the scene matrices.
Result (`state_1_2_masks_after_volume_fix.png`, `..._yaw20_pitch_roll.png`): both masks match flat and each other
(shadowed 1.90% / 1.88% vs 2.89% / 3.57% before); pagoda, totems and green lumps alike in both eyes on the simulator;
fly-by tower lit in both; R&C 1 shadow unchanged.

## 2026-10-07 (open): cars cannot move; FXAA blur

**Freeze.** Matt: in his states `BLUS30839_1_1` / `_1_2` (and sometimes from a fresh boot) no car moves, neither his
nor the AI. What happens: after Continue on the fly-by the camera swoops behind the car and the race HUD appears
(10th, lap 1), but the 3-2-1-GO countdown never comes; the AI cars stay on the grid (`evidence/sonic-freeze/sq_frz_sheet.png`, 1 s shots).
Race clocks run (`0xcfd754..0xcfd778`, ten per-racer floats, all equal and rising at 1/s), audio plays.

- Matt's states stay stuck at 60 Hz, with frame patch 2.0 off, and after Restart Race from the pause menu: the bad
  state is in the saved game state, not in the running rate.
- Fresh boots (sonfresh: Cross through the menus into the first career race, hold R2): rate word at 60 (flip every
  vblank, sim at 60) OK 5/5; patch 2.0 at 90 froze 4/7; at 120 froze 2/2.
- **Not dropped steps.** The second accumulator `[[0xc14ee4]+0xdc]` (live `0x3048a200`: step `+8`, max steps a frame
  `+0x24` = 3, dropped this frame `+0x28`, dropped total `+0x2c`, code `0x1f9698`, drop branch `0x1f97f8`) had
  `+0x2c` = 2 in the frozen state and 0 in a working one, and the 0.066 s dt clamp at 90-120 Hz allows more steps than
  the cap. But a test patch that never drops (`[ be32, 0x001f97f8, 0x48000024 ]`) still froze 3/3 fresh boots at 120
  (`evidence/sonic-freeze/fs_nd.png`). Removed. The frame timer `[0xc14e84]` and accumulator objects are otherwise identical frozen vs
  working, with the same single step subscriber (vtable `0xb382c0`, update `0x43afcc`).
- Memory dumps frozen vs working (`dumps/sd_frz_*`, `sd_ok_*`: Matt's `_1_1` at 60 vs `vrtest_sonic_race`, two
  dumps 4 s apart each): too different to diff usefully (different race moments); everything above `0xed0000` is
  shifted by 0x20000 in Matt's state (patch caves allocated before it was saved). No NaN or stuck global found yet.
- **Fresh fly-by state** (mine, `bin/savestates/BLUS30839/son_fly60`, made at 60 with patch 2.0 + Wider view, at the
  fly-by Continue screen; Matt's savestate folder backed up first): Continue starts the race normally at **60 and 90**
  (countdown, AI drives off; `evidence/sonic-freeze/sq_f6090.png`, top 60, bottom 90). So the freeze is decided before the fly-by: while the race loads or
  sets up at the high rate, and is then baked into a savestate. Not yet run: `son_fly60` at 120 several times
  (confirms it), then compare a frozen and a working state at the same fly-by screen (fresh boots at 90-120 until
  one freezes, save at the fly-by both times) to find the race-start gate (the countdown's state word).
- Tools (scratchpad, this session): `sondump.sh` (two MEMDUMP dumps; gboot's trigger is `g_dump`),
  `sonseq.sh` (Continue, 1.5 s shots), `sonwalk.sh` (fresh boot, a shot per Cross), `statdiff.py`, `clk2.py`,
  `ddis.py` (disassemble a dump). Savestate hook trigger: `%TEMP%/rpcs3-vrprofile/SAVESTATE`.

**Low resolution.** Matt: the image looks low-res even at 400%. The final pass `ad9998b4d5599447` is FXAA whose tap
offsets (fragment constants 5, 7, 10, 12, 1/2560 each) are sized in guest pixels, so at a high resolution scale it
blurs across several real pixels. `fragment_constant_overrides` zeroing them is in the `vr-non-working` profile and
the bin copy; not yet compared zoomed against before (300-400%), not committed. Also still to check: other blur
(depth of field, motion blur).

## 2026-10-07 (evening): the freeze is made in the menus at the high step rate

Fresh boots (`tools/re/sonic/sonphase.sh TAG RATE MENU LOAD`: the profile's rate keys removed or restored live, so the
simulation steps at 60 or at the VR rate in each phase; 12 X presses to the first career race):

| menus | race load + fly-by + race | result (Vblank 120) |
|---|---|---|
| 60 | 60, then 120 from the grid | races 4/4 (`sonload60.sh`) |
| 60 | 120 | races 2/2 |
| 120 | 60, then 120 from the grid | **frozen 2/2** |
| 120 | 120 | frozen (2/2 before; 4/7 at 90) |

So the bad state is created while the menus (or the boot) run with the 1/120 step, and survives into the race (hence
Matt's frozen savestates stay frozen at 60). Not the race load and not the fly-by. Also seen: a block of static words
(`0xdca2bc` + 0x24k: a 256-entry registry filled by `0x8d53a8`, sound voices; `0xdae288` a voice count, written thousands
of times by `0x8d1d90`) start only at the countdown: consequences, not the gate. `0xdac624` 0 -> 1 at GO -> 2 at pause and
stays 2 after quitting; `0xdafa88` 0 -> 1 at the countdown and stays 1: neither marks "in a race".
Frozen state for study: `son_frz90` (= `BLUS30839_1_3`, mine, after the fly-by; Matt's folder backed up to
`F:\rpsc3\backup_savestates_BLUS30839_20261007` first).

More phase tests (`sonphase2.sh` / `sonphase3.sh` / `sonphase4.sh`): the VR step only until the 1st or 4th menu press, then 60:
frozen 2/2 each; 60 for the first 9 s then the VR step for the rest of the menus: frozen 2/2; only the rate word or only the
step size at the VR value early: frozen both. The game's own values in the menus are 60 and 1/60 (PINE). The frame timer
(`0x40150`) keeps its remainder in seconds, so a rate change there is clean; the bad state comes from elsewhere (not found).
Switching up during the race load and back down for the fly-by also failed (frozen or no frames, 4/4).

## Fixed 2026-10-08: the VR step only in races (fork 2112da0f3)

New profile key `frame_rate_draws`: the frame-rate words get the VR rate only while the race HUD icons are drawn
(`cca8ac02bde0a575` with a 256x256 atlas, 10 a race frame, `min_count 5`: the loading screen draws one; found by comparing
inspector captures of 11 menu screens, the loading screen, the fly-by and the grid). Menus, the load and the fly-by run at
the game's own 60 Hz step; the grid and the race at the VR rate (log `Game frame-rate words: the VR rate` at the grid).
Fresh boots at Vblank 120: races start 3/3 (`sf_h*`); at 90: first race, pause 6 s (60 Hz in the pause) and resume, quit to
the menu, second race: all fine (`st_p2`). Matt's frozen savestates stay frozen (the bad state is saved in them).

Also seen (separate): at Vblank 120 some boots stopped presenting during a race load right after the file thread's
`_sys_lwcond_signal ... CELL_EPERM` (`SlFile`, also logged without a hang): 4 of ~25 boots today, all during loads. Not
seen at 90 so far. Later: 4 more fresh boots at 120 with the fix, two races each (quit and restart between), all
fine (`st_q1`..`q4`): the hangs were in runs with the menus at the VR rate.

**FXAA override checked 2026-10-08:** `vrtest_sonic_race` at 300%, same moment: with the taps zeroed the eye image is
sharper (Laplacian mean 6.3 vs 5.3) and loses the dotted artefacts along the track lines; committed with the profile.

## Open (Matt, headset, 2026-10-08): horizontal banding still there

Matt: there is still some horizontal banding, in the distance on the track ahead. His savestate `BLUS30839_1_3`
(2026-10-08 10:38), hard-linked as `vrtest_sonic_matt_banding` so the per-game cap cannot delete it. The 2026-10-06 fix
(Wider view 2.0: culling-only widening, SPU frustum test off) removed most of the lines; what is left is far down the
track. Start from a fresh load of that state, compare against flat and both eyes, and check whether it changes with the
Wider view Scale (1.0 / 2.0 / 3.0) and with head yaw.

2026-10-08 (later): Matt's state does not run here. `vrtest_sonic_matt_banding` (= `BLUS30839_1_3`, made 10:38 with
build 4b97dc47) loads, builds its SPU cache in 7.5 s and then never presents a frame (3 tries: the test config, a retry,
and Matt's own config untouched; a Start press changes nothing). `vrtest_sonic_race` loads and runs in the same setup.
Perhaps it needs Matt's real pad connected (as GT5's states). The regression race's track ahead at full resolution
showed no banding in the frames checked (`evidence/sonic-banding/`). Needs Matt: does the state load for him, and
where exactly (track, lap position) the bands show.

Matt, headset, 2026-10-08 (where to see the banding): just start a race and look ahead. The track in front shimmers
and looks low-res with horizontal stripes, only in some places (so it is a fault, not the texture): the white and red
road surface ahead of the car in `evidence/sonic-banding/matt-track-stripes-2026-10-08.png` (Ocean View start). The
regression state `vrtest_sonic_race` (Ocean View, mid-lap 1) should show it near the start; compare against flat at the
same moment.

## 2026-10-08 (evening): the track stripes are far-distance z-fighting, also in flat RPCS3

Reproduced at the race start (`sonic_race0`, Ocean View grid): at the far bend the road and the buildings beyond show
short black/dark-grey horizontal dashes (`evidence/sonic-banding/hide_bend.png`, `flat_bend_2x.png`). Same moment, all
fresh loads:
- **Flat RPCS3 has it too**, at 300% and at **100%** (`flat100_bend.png`), with the *Wider view* patch disabled
  (`nowv.png`): not caused by VR or the fork's patches. VR makes it more visible (the headset shows the distance larger).
- Not changed by: FXAA (off, game's, taps scaled to the resolution: `fxaa_bend.png`), anisotropic 16x, Force High
  Precision Z, two-draw stereo, *Wider view* 1.0, the depth-remap keys, game camera for the 1024 target, zero stereo
  separation, Strict Rendering, Shader Precision Ultra, Accurate ZCULL off, Handle RSX Memory Tiling, Write Color
  Buffers, Disable Vertex Cache (`flat_settings*.png`). The game FOV (`RPCS3_OPENXR_FOV=game`) makes it as small as
  flat.
- The dashes are already in the scene's MRT target B (`0xc1608000`) before post-processing, and they go away when the
  far structure program `34b524f7491b7af2` is hidden (`flat_hide_sweep.png`): depth fighting between that structure and
  the surfaces drawn over it at long range (D24S8, depth func LEQUAL, no MSAA). Depth bias is applied (NVIDIA D24 path).
  Not found: whether the PS3 shows the same (compare real hardware footage), or an RPCS3 depth difference. Open.
