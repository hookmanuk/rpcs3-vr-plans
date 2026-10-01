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
