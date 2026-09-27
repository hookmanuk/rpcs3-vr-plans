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

