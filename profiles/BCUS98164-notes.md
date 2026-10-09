# Heavy Rain (BCUS98164, disc 01.00 Director's Cut, US)

Added 2026-10-07 at Matt's request (ISO in `F:/rpsc3/games`; custom config made from the global one; the game installs
itself on first boot). Savestate `BCUS98164_1_0`: first gameplay, Ethan's bedroom (right-stick prompt).
Executable `PPU-d89d00dcaa6bacbcbe5f359795c94f3d6020cc81`. Community patches exist only for a debug menu and demo mode.

## Frame rate

- Flat: follows the vblank with no patch: 60 at 60, **120 at Vblank 120** (RSX thread 7.5 ms).
- Real time: `rt_dumps.sh` at 60 and 120 (walking), `rthist.py`: peak x1.0. No frame patch needed; profile `max_fps 0`.
- **VR (simulator, 300%): 90 sustained** (89.8 average, 0.3% late, RSX thread ~9 ms, new frames = flips), with the culling
  patch at 2.5.

## Profile (generated 2026-10-07)

`column_vectors c[0]`, `require_rigid_camera`, `require_camera_aspect`, HUD `orthographic_block 12`, eye_baseline 0.064
(world units are metres). Generator notes: programs `...5d0fa8453`, `...6d2a8674f`, `...c3ef6ae0d` (1380 draws) read the
depth buffer as colour: candidates for `depth_remap_programs` if lighting or shadows slide with the head (unchecked).

## Culling: Wider view (VR culling) patch

Projection builder `0x898418(f1 = vertical FOV in radians, f2 = aspect, f3 near, f4 far, f5)`, called for every camera
(`0x5af9e0` and others); gameplay FOV 0.563 rad (32 degrees, B 3.457). Cave at `0x89842c` (`fmuls f27, f1, f0`, the
half angle): x Scale, capped at 1.3 rad (149 degrees). Scale 1.0: rooms end in black at the view's edges and on head
turns (`evidence/heavy-rain-2026-10-07/vr_poses_scale_1.0_culled.png`); 2.5 fills the room
(`vr_poses_scale_2.5.png`), some black remains past the doorway/window at yaw 20.

## Pause menu (fixed 2026-10-07)

The pause menu (Start) followed the head over a stereo background: its frames have no camera draws (a 320x180 blurred
copy of the scene plus the menu, `2f7d1784dfd94351`). `frames_without_3d_as_screen: true` puts them on the world-fixed
screen (`pause_before_headlocked.png` / `pause_after_fixed_screen.png`). Watch for short flashes onto the screen in
gameplay transitions or cutscene black frames.

## Open

**Parked (Matt, headset, 2026-10-09): full of graphics glitches and stutters.** Not worked on until the other games
are done; no specific scenes or savestate given.

- Headset check of the whole game: menus, QTE prompts (drawn in the world), cinematic camera cuts (the camera changes
  shot while the head stays: comfort), the deferred passes listed above (lighting/shadows sliding?).
- Default Scale 2.5 vs 3.0 (the black past the window at yaw 20).
