# FEZ (NPUB31448, PSN 01.00 / VERSION 01.02)

Added 2026-10-07 (Matt: new game, at 90 FPS). Installed PSN copy (`dev_hdd0/game/NPUB31448`, licence
`UP4427-NPUB31448_00-FEZKEY0000000000`). Profile `bin/vr_profiles/NPUB31448.json` (copy in `vr-non-working/`). No patch.
BlitWorks port (XNA content: `Content_PS3/*.xnb`).

## Boot

PSN "not connected" notice (X), title "Press X to start" (X), save slots (slot 1), Continue / Start New Game, then
Gomez's room. Out of the door (Right ~0.45 s, Up) to the village. **Savestates do not load**: saving works, but loading
any Fez state (with or without Compatible Savestate Mode) stops with an RSX access violation (unmapped main memory)
within seconds. Every test boots the game and drives it: `tools/re/fez_vr.sh OUT [SCALE]` (VR on the simulator,
village, the six head poses). Scripted presses: hold X 400 ms; five spaced X presses are safe (extra ones jump).

## Frame rate

60 FPS native, already presents every vblank: **120 at Vblank 120 flat** and real time (memory clocks at 1.0x;
`posratio` of a 1.2 s walk at 60 vs 120: positions 1.0x). Profile `max_fps 0`.

## VR: a diorama on the fixed screen (new profile key `orthographic_stereo`)

Fez draws real 3D geometry (cubes, instanced) through an **orthographic** camera: `row_vectors c[0..3]`, w = 1,
16 x 9 world units on screen (x scale 0.125 clip/unit), depth along the view axis at 0.002 clip z per unit; the view
turns in 90-degree steps. There is no eye position to move and no perspective to rotate with the head (turning the
view would also show geometry the game hides for its puzzles). So the game goes on the world-fixed screen (the HUD-box
quad), in stereo, and each eye's view is turned by a small angle about a convergence plane: clip x += tan(angle) x
(depth - convergence). Renderer (fork): `camera_probe::apply_orthographic_eye` (depth-tested view draws through an
orthographic camera block; passes and the HUD as drawn), `vr_update_view` puts orthographic profiles on the fixed
screen, not mono. The VR menu's Screen Depth scales the angle.

- Convergence: the world origin's clip depth varies between scenes (room 0.5195, village 0.5525), but the front of the
  playfield sits near clip z 0.507 in both (room objects ~0.505; village crates 0.508). `convergence_z 0.507`.
- Angle 1.5 degrees. Measured on a simulator shot (`parallax.py`, relative to the screen's own edge): village crates
  -7 px, house -4, tower +1, the far tree +10 (952-px eye): the playfield straddles the screen plane, ~+-1 degree.
  With the world origin as convergence (first try) the whole scene floated ~340 px in front of the screen.
- Head poses (straight, yaw +-20, pitch +-10, roll 15): the screen and everything on it world-fixed; nothing follows
  the head. Menus (title, save slots) are drawn on the same screen.
- Generator: when an orthographic camera covers most depth-tested draws (and more than twice any perspective-looking
  block: Fez's instance data `c[4]` looked like a column_vectors_xyw camera), it writes this profile with
  `convergence_z` = the median world-origin depth (0.5525 here: needs the hand value).

## Frame rate in VR (simulator, 300%, village)

120 Hz: **120.0 FPS, 0% late** (RSX thread 2.1 ms/frame). Sustained **120**.

## Open

- Other scenes (inside buildings, the rotations, night, the black-hole levels) unchecked; whether 0.507 holds there.
- Fez's camera rotation key not found with the keyboard pad (L1/Q did nothing in the village).
- Headset run: screen size (HUD Scale), depth strength (Screen Depth).
