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

- Depth of field blurs the near ground (the game's own look, also flat). No patch yet.
- A bright opening in the tutorial tunnel ceiling is visible only in VR's taller view; with the culling
  frustum at 130 degrees it persists, so it is most likely real geometry.
- Not yet checked: menus/inventory in the HUD box, cutscene FOV changes, performance at 130 degrees
  (possible lower LOD), other areas.
