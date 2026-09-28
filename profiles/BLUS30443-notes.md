# Demon's Souls (BLUS30443 v01.00) - findings

`EBOOT` PPU hash `PPU-83681f6110d33442329073b72b8dc88a2f677172`. First game whose profile came entirely from
the in-emulator generator (2026-09-25). Profile `bin/vr_profiles/BLUS30443.json` is the generator's output,
unedited. Patches: `bin/patches/BLUS30443_patch.yml`. Evidence: `plans/evidence/demonssouls/`.

## Rendering

- **Camera-relative.** Most scene programs use indexed constants (bone matrices) and read `c[0..13]`
  directly. `c[0..3]` (row_vectors) is projection x view rotation with **no translation**; the object
  matrix in `c[8..11]` is relative to the camera. A few static programs read a full view-projection in
  `c[8..11]`. Camera blocks `[0, 8]`, in that order (`c[8]` in the camera-relative programs is an object
  matrix that can look perspective).
- Projection: vertical FOV exactly 43 degrees (`B = cot(21.5 deg)` to the bit), A 1.428, near 0.1 in the
  camera block (the generator's near-plane estimate says 0.05, so `eye_baseline` 0.032; adjust World Scale
  in the headset if the world feels large).
- Camera position `c[158]`.
- **HUD** (programs `f2577d35`, `fc7a7815`) is drawn into the scene's final target with an orthographic
  pixel matrix in `c[0]`, `c[1]`, `c[3]`: no z slot, z = w = 1 (the far plane). Full-screen post passes
  (`2770ddcf` and others) use the same kind of orthographic `c[0..3]`, with the z slot, and sample colour
  render targets.
- Main camera parameter block at `0x018cefb4`: FOV (radians) 0.7505, aspect 1.7778 (the community Aspect
  Ratio patch writes `0x018cefbc`), near 0.1, far 3000. A second block at `0x01904334` (90 degrees, far 1000).
- Unlock FPS (community) runs it at 60.

## What went wrong, in order

1. First generation (vr2 generator): camera `c[8]` only, 11% of draws covered, HUD block `c[0]`. In the
   headset: copies of the screen in the HUD box (post passes boxed) and the scene torn (evidence 0).
2. `clip_space_scene_draws` (B^-1 * B_eye for uncovered draws): better but still wrong (evidence 1). The
   uncovered draws were not a transform problem: the generator skipped every indexed-constant program.
3. Hand profile `[0, 8]`: coherent scene; HUD not boxed (no z slot, rows layout needed all 4 slots).
4. Generator fixes: indexed programs sampled by their direct slots; origin eye points skipped (camera-
   relative); a flat rows HUD block accepted; `hud_skips_passes` instead of rejecting the block. The
   renderer binds the flat block and skips colour-target samplers. The HUD then vanished: z = w = 1 left
   the depth range once the fixed box changed w (evidence 2). Fixed: depth-test-off box draws get z = w/2.
5. Wider view patch (130 degrees vertical by default) for culling; `eye_offset: "baseline"` keeps the eye
   distance through the changed projection. The generator now always writes it.

Result: generated from scratch, the profile renders the tunnel and the Nexus approach correctly in both
eyes with the HUD boxed (evidence 3).

## Known issues

- ~~Depth of field blurs the near ground.~~ Fixed 2026-09-27, see below.
- A bright opening in the tutorial tunnel ceiling is visible only in VR's taller view; with the culling
  frustum at 130 degrees it persists, so it is most likely real geometry.
- Not yet checked: menus/inventory in the HUD box, cutscene FOV changes, performance at 130 degrees
  (possible lower LOD), other areas.

## Fixed: torch flame wrong in the left eye (2026-09-25, Matt's savestate `BLUS30443_1_0`; fixed 2026-09-28, see below)

In some frames (about half) the left eye draws the wall torch's flame huge and stretched (two tall orange
streaks down the tunnel) instead of small on the wall; the right eye is always right. Findings so far:
- Good and broken frames have the same draw list, the same particle textures and the same constants in
  the inspector capture (single stream). Particles are program `7f4d3587` (reads `c[0]`, `c[2]`, `c[8..11]`,
  `c[104..111]`, `c[158]`, `c[159]`); its camera is `c[8]` (the `c[0]` block cannot bind), so the camera
  classification is the same every frame.
- They sample the depth buffer `0xc0b50000` (soft particles); glow quads `24ec205b` also read `0xc5870000`.
- Removing the camera position slot (`c[158]`) does not fix it, and turns the whole view upside down.
- Left eye = the primary command buffer, right eye = the batch; the difference is per eye, so suspects are
  left-eye-only state: constant allocation reuse across consecutive draws of the same program, the depth
  texture sampled while attached (feedback copy) in the left pass, conditional rendering / queries.

## Depth of field off (2026-09-27, Matt's savestate `BLUS30443_1_1`)

Matt: translucent HUD sections blurring the image (floor below the player, leaves behind "Tutorial").
Not the HUD: with probe `hide=f2577d35...+fc7a7815...` the HUD was gone and the blur stayed. Hiding the
two 640x360 blur passes made the ground sharp. The post chain after the scene (capture draws 252-271):

| draw | vertex program | does |
|---|---|---|
| 254 | `2770ddcf` fp24 | CoC into the alpha of the scene `0xc07a0000`: depth DoF from `fc[3..9]` plus `clamp((r - fc8.x) * fc12.y) * fc13.z`, r = distance from the screen centre |
| 255-257 | `2770ddcf` fp33, `acfb9632`, `c9084654` | downsample to 640x360 `0xc4610000`, blur H and V (16 taps) |
| 258 | `73cbac9f` fp51 | composite into `0xc4260000`: `lerp(sharp, blurred, clamp(sharp.a * fc0.x))` |
| 259-270 | `2770ddcf` | bloom chain from `0xc4610000` down to 16x16 |
| 271 | `2770ddcf` fp23 | final composite into `0xc07a0000`, then the HUD |

The screen-centre term blurs the picture edges, which on a TV are the corners. In the headset the eye
image covers far more than the TV frame, so it blurred the floor and the top of the view, with doubled
edges. New profile field `fragment_constant_overrides` sets `fc[0]` of
`73cbac9f` to 0, so the composite outputs the sharp scene. Bloom still reads the blurred copy, unchanged.
Evidence `evidence/demonssouls/4-dof-off-before-after.png` (top: before, bottom: after; both eyes).

## Frame rate at the headset rate (2026-09-27)

The community Unlock FPS 2.1 (Whatcookie, Gibbed) already makes game time real: `0x25ed8` presents every
vblank, and the timestep function (`0x1b964` -> cave `0x16c7c30`) returns the timebase delta, capped at 50 ms.
Its note warns of "physics issues" above 60. Measured on savestate `BLUS30443_1_1`, headset path,
camera position `c[158]` from inspector captures before and after scripted input (`RPCS3_VR_KEYS`,
temporary keyboard pad):

| input | 60 FPS | 90 FPS |
|---|---|---|
| forward held 3 s | 10.480 (twice) | 10.525 (twice) |
| forward + roll, 150 ms | 3.115 | 3.062 |

Real-time within the input's frame rounding. The fork now carries the patch in `BLUS30443_patch.yml` as
*Unlocked frame rate (follows Vblank Rate)*, on by default (fresh boot with the community entry off: applied,
90 FPS), and the profile has `max_fps`/`default_fps` 0. Not measured: enemy AI, falling, Havok ragdolls.

## Left-eye particles (fixed 2026-09-28, fork 2dc5848f, savestate `BLUS30443_1_4`)

Matt: a light glow left of the soldier only in the right eye; "a few effects like that". Mono (`render=0`) has
the glow, so the stereo path lost it in the left eye. Steps:
- `hide=7f4d3587...` (particles) removes it: the glow is a soft particle (fragment shader fades by scene depth
  from `0xc0b50000`, the depth buffer the draw is bound to).
- `fragment_constant_overrides` on `7f4d3587` `fc[3].x` = +1e6 turns the fade off (-1e6 hides everything) and
  exposes the fault: the left eye draws particles with other draws' sprites (dark smoke where the glow is,
  orange smoke on the lantern). Reproduces in desktop stereo, not with `RPCS3_VR_BATCH=0`.
- Per-eye vertex constants logged on the CPU were right for both eyes.
- Cause: the left eye's vertex env push constant was recorded before `renderpass_op`. A draw sampling its
  bound depth changes the render pass key, ending the left pass, which runs the right-eye batch
  (`vkCmdExecuteCommands`) and leaves push constants undefined, so the left draw read another draw's vertex
  layout entry. Fix: push after the pass change and program bind (`VKDraw.cpp`).

Measured with the fade off (orange in the left/right soldier crop): before, 2 of 3 frames differed by 0.4-0.5;
after, 6 of 6 within 0.07, same as batching off. Headset path: the glow in both eyes, 90 FPS. WipEout intro
unchanged. The same fault explains the old torch flame streaks (left eye, about half the frames).

## Fog gate, HUD fragments, cutscene frame rate (2026-09-28, savestates `BLUS30443_1_5`, `_1_6`)

**Second portal moving with the head (fixed, fork dae3f7ac).** Rotation audit (`-Audit 25`) and
`hide=24ec205b...`: program `24ec205b` (fog gate distortion layer, also some glows; samples the scene copy
`0xc57d0000`) draws through a full row-vector world-view-projection in `c[4..7]` (camera position `c[22]`),
not a listed block, so it kept the game camera. `camera_blocks: [0, 8, 4]`. In the camera-relative programs
`c[4..7]` is an inverse view (column 3 = 0,0,0,1) and is rejected. The generator never saw the program (it
only draws at fog gates).

**Empty frames and icons around the HUD (fixed in the renderer, fork 2f18a88b).** Three rectangle outlines
above the health bar and heart/ring icons left of it: HUD elements the game parks just outside its screen,
clipped by the TV edge, visible once the HUD is a box inside a wider view. No HUD draw uses a partial
scissor. HUD-box draws now get the game's scissor mapped into the box, which clips to the box. The long
health/stamina fills past their frame lines are the game's own design (same in mono).

**Black opening menu: not reproduced.** With this build the title (logo fade-in) and NEW GAME / LOAD GAME
render in mono, desktop stereo and the headset path; the DoF override does not touch them (no `73cbac9f`
draw on the title).

**Cutscenes at 30 FPS (resolved 2026-09-28, fork 77382a4b): they are videos.** The story cutscenes (1_5:
the arrival at Boletaria, the dragon) are pre-rendered movies. While one plays the RSX executes **no draws**
and the game makes **no flips** (no `sys_rsx_context_attribute` 0x102/0x103); RPCS3 only re-shows the
display buffer through its UI refresh (`flip_request::native_ui`, overlay `min_refresh_duration`, about 31
per second), which is the "30 FPS". The content is 30 FPS video, so it cannot be unlocked. How it was found
(worth repeating for other games): per-second counts of game flips (`handle_emu_flip`), UI refreshes, draws
and flip syscalls, aligned with the title FPS by wall clock. Dead ends first, for the record: the PPU frame
pacer (vblank handler `0x9f7018` posts a semaphore when the counter at `0x1b50434` reaches the threshold
`0x1b50e34` = count + interval byte `+0xb` of the pacer object `0x1b50b88`, interval 1 throughout), the
`+0x6ed` frame mode (`0x2b8ec`/`0x29260` never run here), the render-thread command dispatcher `0xd1e050`,
audio buffering (no effect), and the `0x2baa4` 1/30 step (a fade state machine). The main loop runs at 60
throughout (read watch on `0x1b924`).
In VR the video filled the headset view, locked to the head: UI refreshes never ran `vr_update_view`. Now
UI refreshes more than 200 ms after the last game flip count as frames without camera draws, and the
profile sets `screen_space.frames_without_3d_as_screen`, so videos play on the fixed screen (HUD size and
position settings). Log: "frames without camera draws: shown as the fixed screen" at the video, "camera draws
again" when play resumes. Not yet seen in the headset.
New dev hooks from this: `RPCS3_VR_PEEK` (+`_EVERY`), `RPCS3_PPU_SAMPLE_STACK`, `RPCS3_PPU_WATCH_EVERY`,
`RPCS3_STATS_PERIOD_MS`.
Grey empty patches at the bottom of one cutscene shot: possibly the second camera block `0x01904334`
(90 degrees) not widened; a poke to 130 degrees was inconclusive (the shot had passed).

## Correction: in-engine cutscenes stepped at 30 Hz (2026-09-28, fork 5f274fb3)

Matt: cutscenes stay jerky and are in-engine (turning 90 degrees still shows the game). Savestate 1_5 holds
both kinds: a ~6 s pre-rendered video (castle), then an in-engine cutscene (the dragon) with game flips at
the vblank rate. In the in-engine part the camera position (`RPCS3_VR_PEEK_CONST=158`) changed on only 1 flip
in 3 at 90 Hz (1 in 2 at 60).
- Cutscene ("remo") time is continuous: `0x5fd730` advances `[obj+0x1c]` by the task dt every frame
  (write watch on `0x5fd808`: +0.0166 per frame). Duration = (frames 160 - 0) / 30 (`0x5f9ee0`).
- Tracks are keyframes at 30 per second (camera keys 60 bytes apart, e.g. `0x3277afe4`). The sampler
  `0x5f71d0` (only caller `0x614e30`, via `0x614de8` <- `0x615208`) finds the keys around t (mode 3,
  `0x5f76b8`: key frame / 30.0) and computes the factor, but every channel then takes the nearest key
  (`f10 >= 0.5`), and `0x562f8` builds the matrix. No interpolation.
- Patch "Smooth cutscenes": `calloc` at `0x614e30` (51 instructions, `tools/re/remo_lerp.py`): sample at
  floor(t*30)/30 and the next key, blend the two 4x4 output matrices by the fraction. Poked on 1_5 under
  the interpreter (cave at `0x170d4bc`, test only): the camera moves every frame; picture correct. Applies at
  a fresh boot (savestates keep old code).
- VR also: video frames (UI refreshes) were never published to the headset, so the fixed screen showed the
  last 3D frame; now published when the fixed screen is up.
Not checked: whether character animation in cutscenes is also stepped (separate from these tracks).

## Fixed: fog gate portal doubled in the headset (2026-09-28, fork d7a597e54)

Matt's mirror shots: a second picture of the scene inside the fog gate, moving with the view. The
distortion layer `24ec205b` draws and samples the scene copy through `c[4..7]`, which folds in the gate
quad's non-uniform scale: clip y and w columns nearly parallel (cos -0.99), so `require_rigid_camera`
rejected `c[4]` and the layer kept the game camera. In the headset that is the game's 150-degree
projection inside a 92-degree eye: misplaced, and sampling the wrong part of the screen. The desktop audit
could not show it (eye and game projections match there), and the hide-difference box was bounded by the
fog wall, so it followed the arch either way. `preprojected_programs` misplaces it (the shader computes its
sampling coordinates from its own clip position). Fix: new field `nonrigid_camera_blocks: [4]`. Headset
path, same pose: without it a strip of unrelated brickwork in the portal, with it a refraction of the
scene behind (the knight's outline).
