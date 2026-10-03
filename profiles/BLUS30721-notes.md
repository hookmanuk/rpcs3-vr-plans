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

## 2026-10-02: Matt's headset run, to do (not started)

- The short intro video after starting the game is tied to the head.
- Savestate `BLUS30721_1_5` (13:01): shadows on the main characters move across them when the headset turns;
  in-game TV screens show misaligned footage that turns with the head (they should be fixed 2D videos in each
  screen).
- Plan and leads: `6-wip-games.md` > Asura's Wrath.

## 2026-10-02 afternoon (fork 7858b2956)

- Intro video: `screen_frame_draws` with the movie draw `487364b5ccf9cbc2` (1280x720).
- TV screens: `game_camera_aspects: [1.7647]` (new key): the 720/408 feed cameras keep the game camera.
- Character shadows: not reproduced (audit through the `_1_5` cutscene). See `6-wip-games.md`.

## 2026-10-03: character shadows fixed (fork 9135d376d)

Matt's savestate `BLUS30721_1_6` (hard link `vrtest_asura_matt_shadows`): the space cutscene ("The Brahmastra? But
why?"). The bug shows in the first 10 seconds: Asura's red top goes dark and light again as the head turns.
- **Cause.** Per character, the game renders a 512x512 shadow map (`54e8142ea414fea1`, viewport 502x256 or 502x128
  at `0xcd6b2000`), then a screen-space shadow mask: `07d7202eb4af1d79` draws a 36-vertex box with the camera
  `c[0..3]` into `0xc0840000` / `0xc0100000`. Its fragment program reads the scene depth `0xcabf0000` as
  Z24-in-RGBA8 and maps (screen position from `tc0`, depth) into the shadow map with fragment constants fc5-fc11
  (16 PCF taps). The characters (`76c6f060eff733e8`) sample the mask at their screen position. In the headset the
  position and depth are the eye's but the constants are the game's, so the lookup slid with the head (the headset
  FOV moved it even looking straight). Rewriting constants can't fix it: with head rotation the rebuild's divisor
  would depend on x and y.
- **Fix.** New profile key `depth_remap_programs: ["07d7202eb4af1d79"]`. The fragment shader maps the eye's (NDC,
  depth) at each pixel to the game's before the program reads them (each eye's matrix follows its vertex constants).
- **Checked** on the simulator with a 40-degree yaw wobble (scratch `asura_simburst.sh`, 40 s from launch): the
  characters' shading stays constant across the sweep (before: Asura's top darkened at some yaws). Matt: "it all
  looks good to me". Evidence: `evidence/asura/2026-10-03-shadows-before.png` (Matt's sheet: bottom row),
  `-before-dense.png` and `-after-dense.png` (left eye, every 2nd capture through the sweep).
- The 2026-10-02 rotation audit of `_1_5` found no shadow map in the frames it checked; `_1_6`'s space cutscene
  renders one per character.
