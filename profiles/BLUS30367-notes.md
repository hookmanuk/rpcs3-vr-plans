# Bayonetta (BLUS30367 v01.00) - findings

PPU hash `PPU-fdb78afab78aa27d81cb93e35e4bc73158f25d95`. Profile `bin/vr_profiles/BLUS30367.json` (hand-made
2026-09-28; the first generated one rendered a torn scene). Test snapshot: Matt's savestate `BLUS30367_1_2` (Verse 2,
timed fight on the planes, 23:07). Dev notes: the title's attract "gameplay" (Verse 4/7 fights) is a **video**; test
real 3D only from Continue / a new game.

## Rendering

- **Camera `c[8..11]`, `column_vectors`** (DP4, all four slots). Every scene program uses it: skinned programs
  (indexed constants, bones from `c[40]`) do `clip = dot(worldpos, c[8..11])`. `c[0..3]` is the view matrix, `c[4..7]`
  the projection, `c[12..14]` inverse view rotation, `c[15]` camera position, `c[20..23]` camera world matrix.
  Projection A 1.0806, B 1.921 (85.6 degrees horizontal), near 0.35 (metres: `eye_baseline` 0.064).
- **Sprites/effects `c[24..27]` in `row_vectors`** (`8079b5a9`, `c23f10eb`, `c8ba50d3`, ...): WVP per sprite, may carry
  scale, so exempt from the rigid test. New profile field `row_vector_blocks: [24]`.
- **`require_rigid_camera`**: full-screen passes (`50a5e87c`) read `c[8..11]` in ROW layout as an orthographic pixel
  matrix; read as columns it looks perspective, the pass was taken as a camera draw and sheared (a huge stretched
  wedge in the left eye on the title, menus and in cutscenes). The rigid test rejects it.
- **HUD** (`374c41b1`, `1d7c1ffd`) reads `c[8..11]` with DP4 (column layout, like the scene) as an orthographic pixel
  matrix, with `c[16..19]` the element transform: `screen_space.orthographic_block: 8` + `hud_skips_passes` (the post
  passes read `c[8]` too). A first version set `orthographic_block_layout: "row_vectors"` (taken from the post pass
  `50a5e87c`, which stores that slot in rows); read as rows the HUD matrix looks perspective and the HUD stayed
  head-locked in the headset (Matt, 2026-09-29). Removed.
- **Scene copies**: the game blits its scene (0xcf460000, 1024+256 column chunks) to 0xce618000, 0xce99c000,
  0xced20000 and redraws/composites from them. The left texture cache makes those destinations render targets; the
  right-eye store had none, so the right eye sampled the left eye's pixels. Fixed in the renderer
  (`vr_mirror_blit` creates the right-eye twin).
- The generator picked `column_vectors_xyw` for `c[8]` (xyw needs 3 slots, so it matched a superset of draws and
  read the z row as w). Fixed: xyw only counts where the 4-slot column reading is no camera; the generator also writes
  `row_vector_blocks` for a row-layout second camera.

- **Motion blur** (fixed 2026-09-29, Matt's savestate `BLUS30367_1_3`, graveyard cutscene): characters smeared in
  the headset only. The velocity pass (`bf6c93fc`, 1280x720 target 0xce110000, before the scene) skins characters
  with the current and previous bone palettes and projects with `c[8..11]` and the previous frame's view-projection
  `c[36..39]`. Only `c[8]` took the head rotation, eye offset and headset FOV. New field `linked_camera_blocks: [36]`
  gives `c[36]` the same clip-space transform. Reproduced on the desktop with `RPCS3_VR_AUDIT_FOV=1.0`, `-Audit 15`
  (evidence `evidence/bayonetta/motion-blur-linked-top-unlinked-bottom.png`).

## Known issues

- Pink magic wisps (drawn by the 2D program `1d7c1ffd`, positioned by the game in screen space) stay where the game
  camera put them: head-locked in the rotation audit; in the headset they will sit in the HUD box.
- Checked in the headset (Matt): stereo, performance "quite good". HUD box was head-locked with
  `orthographic_block_layout: "row_vectors"`; removed 2026-09-29, recheck.
- Generator: from gameplay (`1_2`) it now writes the hand profile's blocks, rigid test, position `c[15]` and HUD
  `c[8]`, plus `depth_offset_projection` (298 camera-space draws, not in the hand profile; unchecked). From the
  cutscene (`1_3`) it finds `linked_camera_blocks: [36]` but covers only 58% of scene draws (not investigated).

## Frame rate (not solved)

- **Game logic is fixed-step, one update per vblank.** Frame loop at `0xf70840`: sets byte `+0xc` of the vblank
  struct, then `sys_ppu_thread_yield` + `usleep(100)` until the vblank handler (`0xf70cb0`) clears it. No delta
  time: objects advance by velocity x a per-object speed factor (`obj+0x94` = `owner+0x1e8` (1.0) x local scale,
  `0x2891b0`/`0x2894a4`), used for Witch Time.
- Measured with the Verse countdown: 4.2 units/s at 60 Hz flat and in stereo (~40 FPS), **6.22/s at 90 Hz (1.48x)**.
  u32 counters: `0x4020112c` (driver vblank count) 90/s; game frame counter `0x302dc0b8` (graphics device `+0x98`)
  ~80/s. The static 1/60 floats (11 in .rodata) are not the step (all set to 1/90: no change).
- No game code reads `0x4020112c` directly (read watch, 0 hits).
- **Performance** (RSX thread busy ms/frame from `rsx_sample.py`, snapshot `1_2`, 100% scale, 90 Hz): flat 7.8,
  stereo 13.4 -> ~11 after the batch-slot fix, the per-frame `profile()` cache and `Multithreaded RSX: true` (game
  config). At 72 Hz stereo averaged ~61 FPS. The remaining stereo cost is mostly the NVIDIA driver starting ~140
  right-eye secondary command buffers a frame (it allocates memory in every `vkBeginCommandBuffer` with render-pass
  inheritance, whatever the pool flags); the batches break where the game samples depth (soft particles).
  Matt reports savestate `1_5` running at 90 FPS in the headset.
- The profile has `max_fps: 0` (Matt's edit): at 90 Hz the game runs 1.5x fast until a speed patch exists; 60 is
  the real-time setting.
