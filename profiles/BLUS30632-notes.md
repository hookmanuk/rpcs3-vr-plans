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
  HMD. (Disabling host instancing in VR was tried for the gauge, did not fix it, and was reverted.)
- The health gauge samples a 256x256 mask the HUD draws first, at UVs derived from its clip position: boxed through
  the constants, it sampled the wrong place (teal instead of green). After the shader it is right.

## Open

- Campaign (cutscenes, open areas, vehicles), other characters, online menus.
- HUD animation timers at 3x.
- Headset run.

## 2026-10-01: first headset run (Matt, 90 Hz): parked

- Splash screens and the intro are tied to the head, with HUD elements culled by depth. The intro is very long and
  cannot be skipped.
- In gameplay: bad performance and lots of graphics issues. The desktop checks covered Training > Practice only.
- Savestate at the start of gameplay: `bin/savestates/BLUS30632/vrtest_anarchy_matt_gameplay.SAVESTAT.zst` (hard
  link to `BLUS30632_1_2`, 18:36); also `vrtest_anarchy_matt_1834` (`_1_1`, 18:34).
- **Parked** by Matt.

## 2026-10-03: Matt's gameplay save measured (simulator, multiview build `d6acea81e`)

The save opens on the Street Brawl tutorial popup (scene paused and blurred behind it): six Cross presses page
through it. `tools/re/vrtest_boot/vrtest_anarchy_matt_gameplay.walk` waits 10 s for the load, pages through and walks;
`vr1pct.sh BLUS30632 vrtest_anarchy_matt_gameplay 144 script` with `SETTLE=32` (Vblank 144 = 72 FPS, two vblanks
a frame). Matt's config, 300%:

| | popup (paused) | gameplay |
|---|---|---|
| flat (render=0) | 71.9 FPS, RSX 13.8 ms | **60.2 FPS**, RSX 16.4 ms, 0.6% late |
| multiview | 57.6 FPS, RSX 17.2 ms | **51.8 FPS**, RSX 19.1 ms |
| two-draw | 49.8 FPS, RSX 19.8 ms | 46.7 FPS, RSX 21.2 ms |
| multiview + Force CPU Blit | 71.8 FPS | 42.6 FPS |

- **Blocked before stereo:** gameplay at 300% does not hold 72 even flat. In gameplay the RSX thread idles ~35%
  waiting for the game (RSX sample with walking): the game's own CPU work holds it near 60.
- Popup state (multiview): 42% of the RSX thread inside `prefetch_fragment_program` -> access violation -> texture
  cache flush -> `wait_for_event`. The ucode (`0xce3d8180`, `0xced46600`) shares 4 KiB pages with render targets
  (1280x720 at `0xce3d8a00`, 16x8 ones at `0xced46000`-`0xced465ff`) but lies outside them: false sharing. The GPU
  profile puts ~8.6 ms/frame of idle on the 8x8 target `0xca250000` (flat as well).
- **Tried and reverted:** reading the ucode through the unprotected mapping when no flushable section's own bytes
  cover it. The ucode faults went, but the same flush and wait moved to the vertex data upload
  (`write_vertex_data_to_memory`): once a frame some RSX-thread read touches those pages first. No gain (55 vs 58).
- **Force CPU Blit** removes the readbacks on the popup (57.6 -> 71.8) but costs more in gameplay (51.8 -> 42.6): not a fix.
- **Headset picture in gameplay is wrong** (`evidence/anarchy/2026-10-03-gameplay-flat-vs-headset.jpg`): large flat
  dark-grey wedges cover the ground and parts of the scene where flat shows the street; the HUD box is right. The
  popup's blurred background lands in the HUD box over the world (`2026-10-03-popup-flat-vs-headset.jpg`). Not
  investigated further: the game stays parked on performance.
