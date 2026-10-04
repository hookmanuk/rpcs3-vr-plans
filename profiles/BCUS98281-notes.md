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

## 2026-10-01 late: Jak 1 stereo depth fixed (fork 156196976, generator 03abf3550)

- New `stereo.eye_offset: baseline_per_w` (fork): the baseline eye offset per unit of the block's clip-w row, so each
  object's scale cancels and `eye_baseline` is in view units. With the plain `baseline` only objects with w-row scale
  ~1 (Jak, the eco vent) got parallax and the world (scales down to 0.016) was flat: Jak floated in front of it.
- Units: the earlier attempt used 262.144 (GOAL's 4096 per metre) and was 4096x too large (garbage matches). Jak's
  model (`8f8b007b`, draws 2024-2046) has its origin 12.28 view units away and is 2.9 units tall on screen, so a
  view unit is ~0.5 m (Jak ~1.45 m, camera ~6 m behind): `eye_baseline` 0.128.
- OpenXR Simulator, `tools/re/parallax.py` (sub-pixel): far-field offset -739.7 px (= the asymmetric frusta with the
  10-degree margin); parallax trunk 52 px, lamp post 16, Jak 11.0 (predicted 11.1 for 12.28 units), eco vent 8,
  cliff 2, far palms 1: ordered by depth.
- Also: `fc3fabcf3cb724b2` full-screen passes (glow composite 512x360, scene copy 1024x720, untextured fill) in
  `unboxed_draws`: they were boxed since `orthographic_block 0` (faint rectangles when the head turned).
- World Scale in the VR settings corrects the size if 0.5 m per unit is off.

## 2026-10-04: Jak II frame-locked too; capped at 60

- Timeline test (`vrtest_jak2_prison`, walk forward, shots 1.6 s apart from the same savestate at Vblank 60 and 120):
  at 120 Jak reaches the next room while at 60 he is still by the vats. The earlier "real-time" walk check was wrong for
  Jak II as for Jak 1. `BCUS98281.jak2.json`: `max_fps 60`, `default_fps 60` (fork 28687269a); 60.0 FPS on the
  simulator at 90 Hz (headset reprojects).
- Multiview build, 300%, simulator: Jak II renders 90 Hz sustained (89.6 FPS, 0.14% late; 72 on 2026-10-02); Jak 3
  (`vrtest_jak3_spargus`) 56.9 FPS at 72.
- Looked for the GOAL clock fields to drive the step (OpenGOAL: `clock` seconds-per-frame 1/60, frames-per-second 60,
  time-adjust-ratio 1.0; `display` time-factor 5.0 NTSC / 6.0 PAL). Jak II's memory has 1/60 at only 9 places, none
  beside 60.0 (two in a constant table at `0xc53df0`: 1.0, 1/60, 255, 5, 10, 20, then 59.925, 29.95). Not found; the
  HD port's structures differ. Next idea: write-watch a per-frame counter that advances by 5 (ticks) to find the clock
  update.

## 2026-10-04 later: Jak II real-time at the headset rate (fork 6a31f01f2)

- **Where the timing lives.** The routines use `lwbrx`/`stwbrx`: Jak HD runs the PS2 code recompiled to PPU, with the
  PS2 RAM image (little-endian) as an ELF segment at `0x20000000` (64 MB). A little-endian search for 1/60 found Jak II's
  13 GOAL `clock`s at `0x20401fc0 + n x 0x60` (OpenGOAL layout: clock-ratio +0xc, accum +0x10, frame-counter +0x18 (u64,
  +5 a frame), sparticle-data +0x40 (5, 5.0, 1, 1), seconds-per-frame +0x50, frames-per-second +0x54, time-adjust-ratio
  +0x58), and the display's time-factor 5.0 / dog-ratio 1.0 at `0x20401f7c` (after pointers to the clocks). At 120 FPS
  the clocks counted ~600 ticks/s (2x).
- **Writer.** An interpreter write watch on `0x20401f7c`: thread "GOAL", recompiled set-time-ratios around `0x317d10`
  (`r27` = the recompiler's register/constant block: 5.0 NTSC at `+0x920`, 6.0 PAL at `+0x964`; `r28` = display;
  stores with `stwbrx` to `+0x58` time-factor, `+0x5c` dog-ratio).
- **Patch** *Frame rate follows VR (Jak II)*: `0x317db0..0x317db8` become `lis r11, 0x16c; lwz r0, -0x5d00(r11); stw r0,
  0x400(r27)`, then the original `li r29, 0x58; stwbrx r0, r28, r29` (r11 is rewritten right after). The word
  `0x16ba300` (just past the bss end `0x16ba268`, same page) is seeded 5.0; the profile writes 300 / fps there
  (`"game_vblank_frames_f32": [{ "address": "0x16ba300", "scale": 5 }]`, new `scale` form). Proved live with
  `RPCS3_VR_POKE` first: time-factor 2.5, clock rate halved (515 -> 256 ticks/s), seconds-per-frame 1/120.
- **Checked:** walk timelines from `vrtest_jak2_prison` (`tools/re/jk2f_sheet.png`): patched 120 matches 60, unpatched 120
  is a room ahead. Simulator 300%: 72 Hz 71.8 FPS 0% late; 90 Hz 85-87 FPS. Profile `max_fps 0` again.
- **Jak 1, tried and reverted.** Display timing block at `0x2032fe58` (time-adjust-ratio, seconds-per-frame,
  frames-per-second, time-factor, dog-ratio); set-time-ratios `0x1ff668` (NTSC branch `0x1ff80c`) scales the first four by
  its ratio argument, time-factor is a constant. Redirecting time-factor alone left Jak running fast; redirecting the ratio
  (to 60 / fps) as well made Jak warp to a checkpoint within a second of a load and stop responding (at 90 and 120,
  `vrtest_jak1_matt_gameplay`). Jak 1 stays capped at 60. Code words for a later attempt: `0x1ff6c8 lis r11,0x113`,
  `0x1ff6cc lfs f1,-0x3a00(r11)` (ratio from `0x112c600`), `0x1ff8c4 lis r11,0x113`, `0x1ff8c8 lwz r0,-0x39fc(r11)`
  (time-factor from `0x112c604`).

