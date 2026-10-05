# Dynasty Warriors: GUNDAM (BLUS30058, disc 01.00)

Added 2026-10-04. Profile `bin/vr_profiles/BLUS30058.json` (generated in battle, hand-fixed), patch file
`bin/patches/BLUS30058_patch.yml`; copies in `rpcs3/vr-non-working/`. No community patches exist for this game.
Executable `PPU-9646f248a20f34e52d47a1b012cfe592ae391eba`; decrypted copy `tools/re/elf/BLUS30058.elf` (+ `.imports`).

## Boot

Logos, title (Start), main menu (a ring: Official Mode is selected), pilot select (X: Amuro), Mission 01 Odessa (X),
the briefing dialogue (X / Start), the mission menu (Start Mission: Up, X). Savestates (mine): `dwg_odessa0` and
`vrtest_dwg_odessa` (the same file: battle start, first dialogue).

## Frame rate: "Frame rate follows VR"

- The game already flips every vblank (60 at Vblank 60, 120 at Vblank 120 in battle), but steps the battle one
  1/60 s frame per frame: game clocks 1.9x at Vblank 120 (`memclock.py`, dumps 2 s apart).
- The battle update calls a step function through a vtable with f1 = the step in 60 Hz frames, loaded from a constant
  (1.0, TOC `-0x71d8` at `0x5dd3c`); the step reaches the per-object timers as `frames x 1/60` (`0x11a300`,
  `fmadds f0, f31, 1/60, obj+0x220`). The patch loads f1 from a free word at `0x45f880` (last page of the data
  segment) instead, seeded 1.0; the profile's `game_vblank_frames_f32: ["0x45f880"]` writes 60 / fps. Found from a
  2x clock (`0x117a275c`) with a PPU write watch, then the accumulator's writer.
- Checked at Vblank 120 with the word at 0.5: the main clock cluster at 1.0x (78 values), and a walk timeline from the
  same savestate matches Vblank 60, while unpatched 120 runs visibly ahead (`tools/re/dwt_sheet3.png`). `max_fps 0`.
- Flat ceiling: 120+ in battle (RSX ~2 ms).

## VR profile

Generated in battle: `row_vectors`, camera `c[256, 0]`, `require_rigid_camera`, `nonrigid_camera_blocks [256]`,
`camera_slots_read_directly`, camera position `c[1]`, HUD `c[256]`, near 32 -> 200 units/m (`eye_baseline 12.8`).
Hand fixes:
- **`require_camera_aspect`.** `c[256..259]` is the view-projection of the characters (skinned through a bone palette
  `c[34+a0]`) and static geometry; `c[0..3]` is the terrain's (a heightfield: height from the point-size attribute,
  `ec36679859c99bbf`), but the characters keep light vectors in `c[0..3]`. Taken for a camera, the mobile suits were
  drawn stretched across the whole view; without `c[0]` the ground stayed on the game camera. The aspect test rejects
  the vectors. The generator now writes this key when stray data in a camera block is off the output aspect.
- **`clip_space_scene_draws` removed, `preprojected_programs: [fb86d28e9d78d604]`.** Effects (light pillars, field
  barriers, sparks, smoke, name tags) are projected on the CPU: the program passes clip positions through (logged with
  the new `why=` vertex sample: `(1358, -2874, 12528, 12572)`, z = 1.00156 w - 62.8, the camera's own depth mapping).
  Through the camera's eye transform they stay in place when the head turns. Their fragment program `FP139` is a soft
  particle (scene depth sampled at the sprite's game-view screen UV); with Wider view 3.0 the game view nearly matches
  the headset view, so that UV is close enough (a fragment constant override that disabled the fade was not needed).
- World scale: bone heights reach ~3,000-3,150 units, ~170 units/m for an 18 m mobile suit; 12.8 is about life-size.

## Culling: "Wider view (VR culling)"

The battle camera is 30 degrees high (51 across): record at camera `+0x130..` (near 32, far 40000, fov `+0x138`
0.5236 rad, aspect 1.778; camera at `0x1038e0f0` in the savestate). The camera update copies the field of view from a
settings struct (`[toc-0x2bd0]+0x38`) every frame at `0x23ee44`; the patch branches there to a cave in the zero tail of
the code segment (`0x43a400`) storing min(fov x Scale, 120 degrees). Default 3.0 (90 degrees high, ~121 across).
Mobile suits beside the game's view now show with the head turned 40 degrees.

## Frame rate in VR (OpenXR Simulator, 300%, `vrtest_dwg_odessa` walking)

| | 90 Hz | 120 Hz |
|---|---|---|
| Wider view off | 0% late (RSX 2.7 ms) | **120.0, 0% late** (RSX 2.4 ms) |
| Wider view 3.0 | 0% late (RSX 7.2 ms) | **120.0, 0% late** (RSX 3.6 ms) |

Sustained: **120 Hz**.

## Headset checks (simulator)

- Battle: terrain, characters, shadows, effects and HUD box right, straight / turned 25 and 40 degrees / pitched.
- Main menu: starfield in the headset view, the menu boxed; the small 3D Gundam beside it is a camera-space element.
- Mission (pause) menu: the 3D map's field blocks stay in the menu with `preprojected_programs` (they spilled outside
  without it).
- **Space (2026-10-04):** Kamille Bidan's Official Mode Mission 01 ("Atmosphere": pilot ring Right, X, X through the
  briefing, Start Mission) is in space. Savestate `dwg_space0`. Simulator: stereo and HUD (gauge, minimap, Shot Down)
  right straight, turned 25 and pitched 25; the starfield fills the view. **120 Hz** (120.0 FPS, 0% late, RSX 4.8 ms).
- Not seen: cutscenes, versus/original modes.

## Head poses on the OpenXR Simulator (real head pose, 2026-10-05)

Straight, yaw +-20, pitch +-10, roll 15 (`posecheck.sh`, space mission): stereo right, gauge and minimap in the world-fixed box. Turned left, a dark wedge shows at the far left edge (likely the game's LOD/culling of the starfield beyond its own view; not investigated). Sheet `evidence/headpose-2026-10-05/pc_dwg_sheet.png`.

## Open (Matt, 2026-10-05): menus broken, talking portraits missing

Matt: the menus are all broken, and the images of whoever is talking (character portraits in dialogue) are
missing. No savestate. Not investigated yet. Menus and dialogue were never checked (only battles), so the
profile's 2D handling there is untested: check flat vs stereo, whether the menu draws take the scene path
(`row_vectors c[256, 0]`, `require_camera_aspect`) or `preprojected_programs`, and whether the portraits are
hidden or drawn off-screen/behind the menu in one or both eyes.
