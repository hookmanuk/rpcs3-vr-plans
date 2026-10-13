# Prince of Persia (BLUS30214, 2008, disc v01.00)

Started 2026-10-13 (Matt: "make profiles for Nights and Prince of Persia"). Disc ISO in games.yml. Savestates work
(`bin/savestates/BLUS30214/pop_desert` = first level just before Elika's cutscene, `pop_play` = right after it, free
play in the canyon). Keyboard pad from the template (temporary). Menu path: notice (Start), intro movie (Start + X),
title (Start), Main menu > New Game, "Into the Storm" loads, a cinematic (Start opens the pause menu over it; X resumes).

## Frame rate: patch *Unlocked frame rate (follows Vblank Rate)* (`BLUS30214_patch.yml`, fork)
- Flat: 30 FPS (every second vblank). Direct GCM, no PSGL. The RSX thread busy-waits each frame (33 ms/frame in the
  frame stats): the pacing is in the command stream.
- The vblank handler (`0x1bc810`, registered with `cellGcmSetVBlankHandler` at `0x2627ac`; TOC `0x133e910`) copies GCM
  label 0x41 to 0x42 and counts label **0x43** down while above 0; each frame the GPU sets 0x43 to 2 (a semaphore
  release in the command stream; no PPU writes) and waits for 0. Patch `0x1bc86c` `subf r29,r0,r29` -> `li r29,0`: the
  label is cleared on every vblank, so frames follow the vblank rate (60 / 90 flat at Vblank 60 / 90).
- Real time: memory dumps (`rateratio.py`, 30 FPS vs ~85 FPS): 427 float clocks advance 1.00/s in both, frame counters
  x3. (A first comparison at ~49 FPS under the PPU interpreter showed 6 floats at 1.73x, gone at 85 under LLVM.)
- Avoid `RPCS3_PPU_WATCH_FILE` with this game: the game stopped flipping each time a watch was installed.

## VR profile (`bin/vr_profiles/BLUS30214.json`, generated then edited)
Generated in the first canyon: `column_vectors`, camera blocks `c[200]`, `c[206]`, rigid + camera-aspect checks,
HUD (orthographic) block `c[200]`, horizontal FOV 71 degrees (vertical 44), near 0.05 units = metres,
`eye_baseline` 0.064. Edited: `max_fps`/`default_fps` 0 (the patch), and `screen_space.hud_over_scene` (new, fork
2b7a97544): the pause menu depth-tests (LEQUAL) against the scene's depth at its own deep z; in the headset the fixed box
covered near rock, which hid all but strips of the menu as the head turned (`evidence/pop/2026-10-13-pause-poses-*`).

## Results (OpenXR Simulator, `vr1pct.sh`, 300%, walking)
- 72 Hz: avg 72.0, late 0.00%. **90 Hz: avg 89.9, late 0.28% (sustainable 90).** 120: 116.8 (fails).
- 400% at Vblank 90: ~73.5 FPS, RSX thread 13.5 ms/frame (the RSX thread is the limit, not the GPU).
- Head poses (`posecheck.sh BLUS30214 pop_play`): world moves the right way at yaw +-20, pitch +-10, roll 15; the pause
  menu box stays whole with `hud_over_scene`.

## Open
- **Culling at the edges:** geometry outside the game's frustum (71 x 44 degrees; the generator's "A 2.414" was the
  wrong axis: x scale 1.392, y 2.474) is not drawn. At yaw +20 the near rock under the overhang is missing
  (straight-edged holes showing lit walls behind). Needs a *Wider view* (culling) patch. Trail so far (2026-10-13):
  the render camera at `0x1083cca0` (heap, `pop_play` load) holds the projection at `+0x360` (`0x1083d000`), the view and
  view-projection after it, and `-tan(h/2)`, `-tan(v/2)` at `+0x1e8`/`+0x1ec` (0.7186, 0.4042). Those are copied each
  frame (`0x6b3400`, also `0x865e58`) from the logic camera at `0x10cecc20` (same offsets), which recomputes them every
  frame: poking either does not stick. Next: find the code computing `+0x1e8` in the logic camera (the FOV source) and
  whether the culling reads those tangents or the view-projection; test widening with a code poke under the PPU
  interpreter (write watches stall this game).
  The logic camera's FOV is at `+0x80` (0.76824 rad vertical; near 0.1 at `+0x84`, far 1500 at `+0x88`, aspect at
  `+0xd8`) and is rewritten every frame from a settings object at `0x10d922f0` (pointer at camera `+0x1f8`, field `+0xc0`),
  itself rewritten every frame (holding it at 1.2 changed nothing); the data-segment value at `0x1409d74` (same bits)
  sticks but has no effect live (read at camera setup?). Not solved yet.
- The generator flagged two screen passes that read depth (`f0a481c330cbbbd8`, `f7865139bce5eba2`) and a pre-projected
  program (`1c95a3b2b10bbbd8`): not yet checked for sliding effects with head turns (none seen in the pose shots).
- Not checked yet: main menu and loading screens in the headset, cutscenes, combat HUD, world scale.
