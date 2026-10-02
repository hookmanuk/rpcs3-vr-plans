# Dante's Inferno (BLUS30405, disc 01.00)

Added 2026-10-01. Profile `bin/vr_profiles/BLUS30405.json` (generated in Acre, the first level; frame-rate field
added), copy in `rpcs3/vr-non-working/`. No patch. Desktop only. The community *Unlock FPS* exists only for update
01.04 (not installed: we use the disc version); its *Aspect Ratio* patch covers 01.00.

## Boot

Logos (X/Start), a PSN notice (X), main menu: Start Game, video calibration (X), difficulty (X), an unskippable
intro movie (~90 s), then Acre with enemies. Savestate `bin/savestates/BLUS30405/di_acre.SAVESTAT.zst` (first
fight). Executable `PPU-46bf3c2b...`; decrypted copy `tools/re/elf/BLUS30405.elf` (`RPCS3_DUMP_ELF`).

## Frame rate

- Native 60 (flips every vblank). Flat at Vblank 180: 180 FPS in Acre, CPU ~30%. Desktop stereo at Vblank 90: 90.
- **Frame-locked above 60:** the frame function `0x9408c8` (TOC `0xf65600`) counts whole frames of the interval
  `[0x119ecb4]` (float ms, 16.6834 = 59.94 Hz) in the measured elapsed time, at least one and at most 5 a frame,
  and steps the game clock (`0x11c3d88`, int64 microseconds; per-frame step `0x11c3d30` = frames x interval, times
  the time scale `0x11c3d64`). At 180 FPS game time ran 2.86x. Poking `0x11c3d30` does nothing (rewritten every
  frame); setting the interval does: 1000/180 ms gave 0.96x at 180.
- New profile key **`game_frame_ms_f32`** (fork): `["0x119ecb4"]` gets 1000/fps. At 90 FPS game time runs 0.99x
  real time over 10 s (native 60: 0.98x). `max_fps 0`.
- The 01.04 patch also gates UI animation to 60 Hz because menus lost their text at high frame rates; at 90 the
  pause menu (Upgrade tab) renders correctly. Not checked: UI animation speed, other menus, QTEs.

## VR profile (generated)

`row_vectors`, camera `[256, 260, 4, 0, 8]` (most scene programs: world `c[256]` + view-projection `c[260]`;
others a VP in `c[256]` or `c[8]`), `camera_slots_read_directly`, camera position `c[466]` (614 of 7773 eye
points: weak; removing it changed nothing visible), HUD `c[0]`, near 0.35 (taken as metres, `eye_baseline`
0.064, unchecked), `require_rigid_camera` with `nonrigid_camera_blocks [256, 260]`.

- **HUD missing in stereo** (both eyes, also with VR on the desktop): the HUD program `ef40b68dd8b117df` keeps UV
  and colour parameters in `c[4..7]`, which `c[4]`, a camera block for other programs, read as a sheared
  perspective block; the eye transform wrecked them. `require_rigid_camera` fixes it; the generator now writes it
  (a depth-less draw whose first matching block has |cos| > 0.5 counts as stray data).
- Stereo in combat, the yaw-25 audit and the pause menu are right (`evidence/dante/`).
- Headset view (`-FakeHmd 100`): HUD boxed; the sky is a screen-space card drawn as a quad, so it shows as a
  floating rectangle in the wide view and leaves black sky when turning. Geometry beyond the game camera's
  frustum is culled (black areas when turning), as in other games.

## 2026-10-01: sky in the headset view (not fixed)

The sky ends at the edge of the game's frustum (a bounded "card", `evidence/dante/fakehmd100-sky-card.png`). Not the
full-screen composite `f7863935bce5eba2` (hidden: no change) and not `2a5dce5dcdcf3e11` (a small sky/environment
render into a 320x320 target; kept on the game camera: no change). The sky is probably world geometry the main
shader draws, sized to the game's view. Next: hide the scene programs one by one (`hide=`) to find the sky mesh.

## Open

- Headset run; world scale; sky card; UI animation speed at 90; later levels.

## 2026-10-01: first headset run (Matt, 90 Hz)

- Gameplay performs really well.
- Splash screen, menus and the intro movie are tied to the head.
- Needs culling/FOV improvements: objects that the wider headset view should show are culled (the game culls to its
  own frustum). Lead: find the culling frustum or FOV the game uses and widen it with a patch (as ICO's "Wider view
  (VR culling)").

## 2026-10-02: intro movie after Start Game still head-locked: fixed

The ~90 s intro movie (after Start Game, calibration, difficulty) is drawn over the first level, which the game
already renders behind it (Acre's camera draws every frame), so the frame counted as 3D and the full-view movie quad
(`2f7541c34fd0c5d7`, Y plane 1280x736 and chroma 768x384 in main memory) followed the head. Profile:
`"screen_frame_draws": [ { "program": "2f7541c34fd0c5d7", "texture": "1280x736" } ]`: any frame with the movie draw
goes on the fixed screen. Checked on the OpenXR Simulator from the disc (head straight and turned 25 degrees: the
movie moves as a world-fixed screen; after the movie gameplay returns to the headset view, HUD boxed). Other FMVs
use the same player and should follow. No save data created.

## 2026-10-02: culling at the headset's wide view: "Wider view (VR culling)" patch

- The game projection is 61.9 x 37.3 degrees (tan 0.6 horizontal); the headset view is ~100 x 89, so objects at the
  edges were culled even looking straight ahead.
- Found live (pine + PPU write watch on the interpreter): the projection matrix (`-1.667, 2.963`, near 0.70, far 4096)
  at `0x135fb50`, built each frame from a camera record (`+0x1a4..0x1b8`: near, far, **fov 1.0808 rad
  horizontal**, aspect; copies at `0x11a1ad0`/`0x11a1cb0`) written by the perspective setter `0x420490`
  (`stfs f1, 0x1ac(r31)`), called from the camera update `0x452da0` (fov in f31, from a camera struct `+0x30`, through
  the vertical/horizontal FOV conversion `0x449738`); the matrix by `0x413b70` -> `0x609a60` (generic perspective).
- Patch (`vr-non-working/patches/BLUS30405_patch.yml`, copy in `bin/patches/`, enabled by default): `0x452f1c`
  `fmr f1,f31` -> `fadds f1,f31,f31` (FOV x2: 124 x 93 degrees). Camera position unchanged with and without (read
  live while toggling the code under the interpreter). Flat play would show a wide-angle view.
- OpenXR Simulator from the disc (`tools/re/dante_boot.ps1 -Headset`): straight ahead complete; yaw 40 degrees mostly
  filled (beyond 90 degrees off the game camera's axis stays black: no frustum covers it); looking up 20 degrees still
  black at the top (vertical 93 degrees is the narrow axis). A larger factor needs a code cave (a constant multiply).
- Cost: stereo at 300% (`vr1pct.sh`), 120 Hz sustained with and without (0% late); RSX thread 3.75 -> 4.09 ms at 90.
- Savestate with the patch: `vrtest_dante_acre_wide` (= `_1_1`; the regression entry now uses it).

## 2026-10-02: Matt's headset run, to do (not started)

- Savestate `BLUS30405_1_2` (13:09): attacking with Square and hitting enemies shakes the whole screen; very
  off-putting in VR. Disable the shake.
- Savestate `BLUS30405_1_3` (13:14): right at the start a tooltip banner shows at the bottom for ~2 s with no text.
  All text everywhere must be visible.
- Plan: `6-wip-games.md` > Dante's Inferno.

## 2026-10-02 afternoon: shake, tooltip, wider view 2.0 (fork e0a6d501e, 2aaf72b50, f4b730b01)

- Shake: patch "Disable camera shake (VR)": the camera modifier apply at `0x663d8` returns at once (Matt: shake gone).
- Tooltip text: `screen_space.hud_block_programs: [{ "program": "2f7541c34fd0c5d7", "block": 256 }]`.
- Wider view 2.0: the field of view at the setter call (`0x452f1c`, radians, 1.0808 = 61.9 degrees across in play)
  is multiplied by the dropdown scale and clamped to 170 degrees by code at `0x663e0` (`bl` from `0x452f1c`; r9, f0,
  f13 are dead there; the function restores LR from its stack frame). Default 2.75. Matt's savestate
  `BLUS30405_1_4` has it. Plan in `6-wip-games.md`.
