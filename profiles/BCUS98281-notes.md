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
