# Asura's Wrath (BLUS30721, disc 01.00)

Added 2026-10-01. Profile `bin/vr_profiles/BLUS30721.json` (generated in Episode 1's space battle QTE), copy in
`rpcs3/vr-non-working/`. Desktop only. The disc installs game data at first boot and needs a save file (answer Yes).

## Frame rate

- Community patches enabled in `patch_config.yml`: **Unlock FPS** (Whatcookie: frame rate = half the vblank rate),
  **Disable Motion Blur**, **Disable Depth of Field** (both bad in VR).
- At Vblank 180: 90 FPS in Episode 1, flat and desktop stereo. **Real-time:** 643 f32 and 150 f64 clocks at 1.0x over
  12 s at 90 FPS. The patch notes warn that some button-mashing QTEs are tied to the frame rate (fine at 60, hard
  at 120+): not tested at 90.
- Profile `max_fps 0`, `default_fps 0`, `vblanks_per_frame 2` (headset 90 Hz -> vblank 180 -> 90 FPS).

## VR profile (generated)

`row_vectors c[0]` (100% of depth-tested draws), camera position `c[4]` (722 of 8272 eye points: weak), HUD
`c[200]` (`column_vectors_xyw` candidate), near 5 units -> 50 units/m (`eye_baseline` 3.2, unchecked). Desktop stereo
matches; yaw-25 audit in the opening turns coherently. Cinematic bars in QTE/cutscene sections are drawn bars (the
viewport is full 1280x720).

## Open

- QTE mashing at 90; on-foot combat sections; HUD (QTE prompts) placement in the headset; world scale.
- Savestates need `Savestate > Compatible Savestate Mode` (otherwise "failed to lock SPU threads"): set it only while saving.
  Regression state `vrtest_asura_space` (Episode 1 space battle): **120 Hz sustained** at 300% (Vblank 240: 119.6 FPS,
  no late frames; 2026-10-01, `evidence/vrtest/2026-10-01-1445`).

## 2026-10-01: first headset run (Matt, 90 Hz)

- Works well.
- To do: in-engine cutscenes show a 16:9 box with black letterbox bars. Hide the box background and the bars in VR,
  keeping the 3D world and the HUD elements (subtitles, prompts). The bars are drawn by the game (full 1280x720
  viewport); find their programs with probe `hide=` / `why=` in a cutscene, then `hidden_draws`.

## 2026-10-01 night: letterbox not started

- Tried to reach an in-engine cutscene from the disc: the title's EPISODE MENU ("Continue previous game") does not
  react to scripted Cross or Start; NEW GAME would overwrite Matt's save (`BLUS30721-BCSAVEDATA`, 18:23), so stopped.
  Next: a savestate from Matt at a cutscene with bars, then probe `hide=`/`why=` for the bar and background draws.

## 2026-10-01 late: letterbox bars and the grey 16:9 box removed

Matt's savestate `vrtest_asura_matt_letterbox` (= `BLUS30721_1_1`, the title screen with the cinematic bars). On the
OpenXR Simulator with an inspector capture (`f1860`):
- **Bars:** two untextured draws of `fc13d36fbccec49a` (vertex colour, 30 vertices, HUD block `c[200]` scale
  ±6.58e-5, translation ±(1,-1)), one per bar. Hidden with `hidden_draws` (texture `0x0`). The same program is a
  generic coloured quad, so a fade or a menu panel drawn with it would be hidden too: watch for missing fades.
- **Grey box:** not a draw of its own. The full-screen pass `5c313870ebfa5cd0` (scene `0xcaf90000` -> `0xcb6c0000`)
  is the game's world shader with `c[200..203]` as its world matrix, identity there, so it read as a HUD draw and
  was boxed (probe `why=5c313870ebfa5cd0`: `box 1`). Only the HUD box got this frame's image; outside it the target
  kept older pixels, a slightly different shade. `screen_space.hud_skips_passes: true` leaves draws that sample a
  colour render target as drawn.
- Checked: the title (bars and rectangle gone, text kept, head straight and turned) and the Episode 1 space battle
  (reticle and "Rapid Fire" text still in the HUD box). Evidence: `tools/re/asl_m1.png` (before), `asl_m5.png` (after).
- Not seen yet: an in-engine cutscene during gameplay (Matt's report); the bars there should be the same program.
