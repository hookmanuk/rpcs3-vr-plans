# Anarchy Reigns (BLUS30632, disc 01.00)

Added 2026-10-01. Profile `bin/vr_profiles/BLUS30632.json` (generated in Training > Practice, frame-rate fields
edited), fork patch `bin/patches/BLUS30632_patch.yml`; copies in `rpcs3/vr-non-working/`. Desktop only.

## Boot

First boot installs game data (X, then X). Intro text pages (X), title (a PSN sign-in prompt and an "Unable to sign
in" dialog appear at different moments: X), main menu (cursor on MULTIPLAYER), Down twice = TRAINING, X, PRACTICE
(X), tip (X). Menu input is laggy: screenshot between steps. `tools/re/ar_boot.sh` does most of it but needs a
check. **Savestates work**: `bin/savestates/BLUS30632/ar_practice.SAVESTAT.zst` (Practice, made at 90 FPS, so the
characters hold dt 1/90). Jack's feet position: f32 xyz at `0x1d7fc10` (static).

## Frame rate

- Native 30 FPS (flip every 2nd vblank). Community *60 FPS* (FlexBy) changes one constant: `lis r3, 0x3d08` at
  `0x43cbb8` (1/30) to 1/60, "set Vblank to 120".
- That 1/30 is stored by `0x43ca3c` into each character controller (`+0xe5c`, a heap object; constructed by
  `0xa2dd0` and `0x476c94`) and read by ~18 functions. Fork patch **Frame rate follows VR (use instead of 60 FPS)**:
  `0x43cbb8` `lis r3, 0x278` + `0x43cbc8` `lwz r3, -0x7010(r3)` load it from `0x2778ff0` (past the data segment's
  end, inside its last 64 KB page), seeded with 1/60; the profile's `game_frame_time_f32 ["0x2778ff0"]` sets
  1/fps. The value is copied when a character is created, so the profile has to be loaded before (it is: from the
  first frame). The community patch must be off (same address).
- Flat at Vblank 180: 90 FPS in Practice (steady). Desktop stereo: 90.
- **Verified** (savestate, per-frame position peek, `tools/re/ar_phys.sh`, `speedline.py`): walk / run speed
  60 FPS with 1/60: ~5.9 / ~9.5 u/s; 90 FPS with 1/90: ~6.0 / ~9.6; 90 FPS with 1/60 (= the community patch at
  90): 8.6 / 14.5 (1.5x).
- Not fixed: 778 HUD sprite timers (`0x30c9...`, 640x360 widgets) advance a fixed 1/30 per frame, so HUD
  animations run 3x native at 90 (2x with the community patch at 60). Gameplay unaffected.

## Renderer and profile

- Scene at **1024x720** (stretched to 1280 at the end): depth pre-pass, 512x512 shadow maps (`c[16..19]`),
  320x176 blur. Scene programs: model-view `c[20..23]` (row vectors), projection **`c[4..7]`** (bare, near 0.1,
  infinite far), plus view-projections `c[8]`/`c[36]` for a second output; some programs carry an object-scaled
  MVP in `c[24..27]`. HUD on the 1280x720 target with the pixel ortho **`c[54]`**.
- Generated: `row_vectors`, camera `[4, 24]`, `camera_target_aspect 1.42222`, `clip_space_scene_draws` (76% of
  scene draws covered), near 0.1 m, `eye_baseline 0.064`, HUD `c[54]` with `hud_box_after_shader`.
- Stereo, yaw-25 audit and the headset view (`-FakeHmd 100`) in Practice are right
  (`evidence/anarchy/`). Attack combos: no stray effects.

## Generic fixes made for this game (fork)

- Generator: camera test rejects A > 30 (FOV under 3.8 degrees): the HUD ortho read as x/y/w rows looked like a
  2-degree camera and won. Bare projections in the majority set the projection and near plane (40 object-scaled
  MVPs gave near 0.0017). Blocks no sampled draw binds are left out. The HUD search also covers output-aspect
  targets when the scene renders at another aspect. HUD draws that sample a small render target (a mask) write
  `hud_box_after_shader`.
- Renderer: the HUD box applies on output-aspect targets as well as camera-view targets; a HUD draw counts as a
  pass (`hud_skips_passes`) only when it samples a view-shaped target; the after-shader box works with the fake
  HMD; draw clauses are not host-instanced while VR renders (each subdraw gets its own eye constants).
- The health gauge samples a 256x256 mask the HUD draws first, at UVs derived from its clip position: boxed through
  the constants, it sampled the wrong place (teal instead of green). After the shader it is right.

## Open

- Campaign (cutscenes, open areas, vehicles), other characters, online menus.
- HUD animation timers at 3x.
- Headset run.
