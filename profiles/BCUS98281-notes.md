# Jak and Daxter Collection (BCUS98281, disc 01.00)

Added 2026-10-01. Three games under one title ID, launched from a menu (`EBOOT.BIN`) by exitspawn into `Jak1.self`,
`Jak2.self`, `Jak3.self`. Profiles: base `bin/vr_profiles/BCUS98281.json` (so OpenXR is prepared before the switch,
as for God of War Collection) plus `BCUS98281.jak1.json` and `BCUS98281.jak2.json`; copies in `rpcs3/vr-non-working/`.
Savestates: `BCUS98281_1_0` (Jak 1, Samos' hut after the intro), `BCUS98281_1_1` (Jak II, the prison/escape area).

## Jak and Daxter: The Precursor Legacy (Jak1.self)

- 60 native; **170-180 flat** at Vblank 180 (Samos' hut / Sandover). **Real-time:** float clocks 1.00x, and object
  displacements for the same 0.7 s input match at 60 and 180 (no 3x cluster). No patch; `max_fps 0`.
- Profile (generated): `column_vectors c[0]`, 100% of depth-tested draws, `camera_target_aspect 1.42222` (the scene
  renders into 1024x720), no HUD block, metres.
- Yaw-25 audit: outdoors coherent. In Samos' hut, blended sparkles (`71e17d7f15754935`, 40-vertex draws) showed as
  black pentagons fixed on screen in the rotated eye: to fix.

- 2026-10-01: the black pentagons were not the sparkles (`71e17d7f`, hiding it changed nothing) but
  `07b162cff7a683bf`: pre-projected glare quads (identity `c[0..3]`, positions already in clip space) drawn into a
  512x360 buffer with each quad killed where the scene depth (`0xc05c0000`, read as Z24) is nearer: a lens flare
  occlusion test. In a rotated eye the flat-screen quads test against other depth and show (black, through the
  modulate composite `fc3fabcf`). Profile `hidden_draws` [`07b162cff7a683bf`, texture 1024x720] hides the glare in
  VR; headset-view wobble in Samos' hut is clean (`evidence/jak/`).

## Jak II (Jak2.self)

- 60 native; **~130 flat** at Vblank 180 in the prison area. Real-time (same displacement test: no 3x cluster).
- Profile (generated): `column_vectors c[0]`, 100% coverage, `camera_target_aspect 1.42222`, HUD `c[0]` +
  `hud_skips_passes`, near 8 units -> 80 units/m (`eye_baseline` 5.12, unchecked). Yaw-25 audit coherent.

## Jak 3 (Jak3.self, `PPU-8f44cd9f...`)

- 2026-10-01: New Game (save slot 1), opening cutscene (not skippable: Start pauses it), title, Spargus.
  Savestates `jak3_spargus` (cutscene) and `jak3_play` (first control, Spargus palace) in
  `bin/savestates/BCUS98281/`.
- **Not a 90 FPS candidate in Spargus:** cutscenes 180 at Vblank 180, but gameplay **74-85 flat** (Vblank 180
  uncapped and Vblank 90 both). RSX thread 4.3 ms of 12.3 ms between flips, GPU idle; one game thread ~70%:
  the game's own work. No profile made (workflow step 1).

## Open

- HUD check in both; stereo frame rates on the headset path.
- Jak 3: below 90 flat in Spargus (above).
- The launcher's attract scenes are 3D (30 FPS) with the base profile = Jak 1's.

## 2026-10-01: first headset run, Jak 1 (Matt, 90 Hz)

- All HUD elements tied to the face (no HUD block in the profile).
- Stereo broken on lots of objects: at the wrong depth, hurts the eyes.
- Performs well, but **everything looks 1.5x speed at 90 FPS**. This contradicts the "Real-time" result above (float
  clocks 1.00x, matching walk displacement at 60 and 180): that test did not cover what runs per frame. Re-check by
  eye at 60 vs 90 (animations, effects, NPC movement) and find the per-frame step; Jak II's result is suspect too.
- Matt's gameplay savestate: `bin/savestates/BCUS98281/vrtest_jak1_matt_gameplay.SAVESTAT.zst` (hard link to
  `BCUS98281_1_5`, 18:08); also `vrtest_jak1_matt_1804` (`_1_4`, 18:04).

## 2026-10-01 evening: Jak 1 fixes (fork fa2cea1ac, plus the max_fps commit)

- **HUD:** the HUD/menu program `2f8d9792dfd8eb59` reads a pixel ortho in `c[0..3]` (2/512, -2/224: the PS2's 512x448
  screen) — the camera's own slots. `screen_space.orthographic_block: 0` boxes it: the camera match runs first and
  rejects a non-perspective block. OpenXR Simulator: the pause menu stays world-fixed while the head turns; gameplay
  unchanged.
- **Speed:** memory dumps at 60 and 90 FPS (savestate `vrtest_jak1_matt_gameplay`, `tools/re/memcount.py`): no
  frame-time value changes with the rate (no 1/90 or 90.0 anywhere; 1/60 only as literals in constant pools at
  `0x688d3c`, `0x10b57ec`, `0x753828`). The game steps a fixed 1/60 per frame, so it runs 1.5x at 90, as Matt saw.
  The earlier "real-time" result (walk displacement) was wrong. Fix for now: `max_fps 60`, `default_fps 60` (runs
  at its native 60 with the headset at 90, reprojected), verified 60.0 FPS on the simulator. A real VR-rate fix needs
  the frame step found and driven from the profile, as for R&C. Jak II uses the same engine: probably the same.

## 2026-10-01 evening: Jak 1 wrong stereo depth — cause found, fix not finished

- Measured on the OpenXR Simulator (RPCS3 SHOT of the headset session, `tools/re/parallax.py`): with the profile as
  it is, the trunk a metre away, the lamp post, Jak, the eco vent, the far cliff and palms all have the same R-L
  offset (-741 px, scores 0.87-1.0): **no parallax at all** on the headset path. (The desktop path uses the screen
  shear and is fine.)
- Cause: `eye_offset: baseline` shifts clip x by `eye_baseline * |x row|`. Jak 1's scene blocks `c[0..3]` are per-
  object matrices: in one gameplay frame the w-row length (an object's scale) is 1 (camera-space draws, `e9a3ac88`),
  0.5 (`55eb3ab7`, `8f8b007b`) and 0.0158 (`a9e7e67f`, 999 draws), while `|x row| / |w row|` is 1.6 for all (the
  projection). So each object's eye offset is scaled by its own size: small-scale objects get almost none.
- Tried and reverted: a profile option dividing by the w row (`baseline_per_w`, consistent across objects by
  construction) with `eye_baseline` 262.144 (GOAL's 4096 units per metre): the parallax measured afterwards was
  implausible (far cliff nearer than the trunk), so either the view units are not 4096/m or the template matching
  on this grassy, repetitive scene is unreliable at these offsets. Next: per-w offset with a units estimate from a
  known size (Jak's height, a door), and a parallax check on a scene with distinct objects; then Matt in the headset.
