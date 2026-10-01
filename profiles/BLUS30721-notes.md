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
