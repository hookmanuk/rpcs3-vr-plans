# Dragon Age: Origins (BLUS30415) - VR notes

Disc 01.00 (`Dragon Age - Origins (USA, Asia) (En,Fr,De,Es,It).iso`), PPU hash
`PPU-750889872c0ff8cc186c61cf94e64dff190b619f`. First boot installs data (~1 min). Route: Start, New Game (intro
movie), Character Generation: X through gender/race/class/background (Human Noble), name keyboard Return, appearance
Quick Play (Triangle), difficulty X, then X through the opening dialogue (~3 min) to control in Castle Cousland's
hall. Savestate `da1_castle0`. Savestates work without Compatible Savestate Mode.

## Frame rate

The game presents every vblank (flip and vblank counters `0x15a0598` / `0x15a0594` both 60/s) and steps by measured
time: walking 3 s from `da1_castle0` ends at the same place at Vblank 60 and 120. No frame-rate patch is needed.
Flat: 200-215 FPS at Vblank 240 (RSX 4-5 ms).

## Culling: "Wider view (VR culling)"

The camera (vtable `0x14d5d48`; record at +0x120 near 0.15, +0x124 far 4000, +0x130 FOV 1.0472 rad = 60 degrees high,
+0x134 aspect) caches its projection at +0x40 and rebuilds it in `0x71b818` (vtable +0xa4) when +0x30 is set. The patch
replaces that function's `lfs f3, 0x130(r31)` (`0x71b85c`) with a call to a cave in the code segment's last page
(`0x144f980`; segment ends `0x144f960`) multiplying by Scale and clamping to 150 degrees (f1/f2 are live there).
Found: PINE scan for the projection (`findproj2.py`: `0x15a06e0`), write watch (copied in `0x71c264` from the
camera's virtual getter `0x73325c`), trace at the call for the object.
Default Scale 2.0 (120 degrees): fills the headset straight, turned 25 and pitched 25. At 2.5 the hall fireplace's
flames (`8bf4140f84758fb2`, CPU-built sprites drawn with the camera WVP only) stretch into a streak across the room.

## VR profile

Generated walking in the hall: `row_vectors` `c[256]` (rigid, `require_camera_aspect`), per-object WVP (w-row scale
41: `eye_offset baseline_per_w`), HUD `c[260]`, near 0.075 = metres. Then `max_fps 0`, `default_fps 0`.
Simulator: stereo correct, HUD boxed straight / turned / pitched (`passthrough_hud` not needed: the HUD is c[260]).

## Frame rate in VR (OpenXR Simulator, 300%, `da1_castle0` walking)

| 72 Hz | 90 Hz | 120 Hz |
|---|---|---|
| 72.0, 0% late | 90.0, 0% late | **120.0, 0.21% late** (RSX 3.5 ms) |

Sustained **120 Hz**.

## Unchecked

Combat (spell effects), outdoor areas (Ostagar), cutscenes, the generator's deferred-pass candidates
(`1c7935c330cbbbd8`, `563256d01a876018`: lighting reading depth; nothing slid in the hall).

## Head poses on the OpenXR Simulator (real head pose, 2026-10-05)

Straight, yaw +-20, pitch +-10, roll 15 (`posecheck.sh`, `vrtest_dao_castle`). **Found:** the HUD (portrait, minimap, ability bar) stayed on the face: it is Scaleform, 2D transform in `c[0..1]`, not the `c[260]` block, so the earlier rendered-pose checks (which turn the rendered pose, not the compositor) missed it. **Fixed:** `passthrough_hud` with `hud_programs` `fc6fc45502d91a9a`, `fbf8826148d91a90`, `f7f66105c0d5ebac` (from an inspector capture: the programs drawing into the output after the scene); listed programs are now boxed also untextured and with no colour target, since the game masks the minimap and portrait in depth/stencil with colour writes off (fork 0501cbdcc). Before `evidence/headpose-2026-10-05/pc_dao_sheet.png`, after `evidence/headpose-2026-10-05/pc_dao2_sheet.png`.

## Fixed 2026-10-05: conversation culling (missing legs, grey, overlay)

Matt's state `BLUS30415_1_2` is a conversation (Duncan, the arl's hall). Flat, its camera is a narrow close-up
(`evidence/dao-conversation-2026-10-05/dao_flat.png`): the legs, the man at the fireplace and the room to the right
are off-screen. The game culls each armour mesh and prop against that frustum, and *Wider view* x2 of a ~30-degree
close-up is still far narrower than the headset: legs cut at the thighs, a floating head and no fire in the
fireplace, flat grey past the right edge, and window light shafts cut off (the pale ghost beside the fireplace on
head turns: the 'overlay'). *Wider view* 1.1: the cave takes max(FOV x Scale, 60 degrees x Scale), capped at 150
(new constant 1.0472 at `0x144f9c8`), so gameplay (60 degrees) is unchanged and close-ups cull at gameplay width.
Pose check after: room, legs, guards, fire and light shafts whole at every pose. RSX thread 7.1 -> 8.6 ms here
(both 60 FPS: the simulator reports no refresh rate and Unlimited keeps the config's Vblank 60).

Was (Matt):

Matt's state `BLUS30415_1_2`:
- Looking right, the view is all grey: Wider view x2.0 is not enough here, or this scene culls with another
  camera/frustum than the one the patch widens (`0x71b85c`).
- Characters have no visible legs: likely culled, or cut by the bottom of the game's view (vertical FOV), or a
  near-plane/clip issue; check flat, then stereo at straight ahead.
- Moving the head shows a strange overlay: an eye-invariant or screen-space layer that does not follow the
  world (compare `simpose.py` yaw/pitch shots against straight ahead and find the layer's program).
Not investigated yet.

## Open (Matt, headset, 2026-10-06): trees attached to the head after the pause menu

New state `BLUS30415_1_5` (10:06; `BLUS30415_1_4` from 10:04 may be the same place): the state loads with the pause
menu open; closing it shows trees that follow the head instead of staying in the world. Not investigated. First checks:
the tree (foliage/billboard) programs' camera classification with `why=` (likely camera-facing sprites or another
camera block, as `nonrigid_camera_blocks` / `require_rigid_camera` cases in the playbook), and whether it only happens
after the pause (a stale camera block or projection cached during the menu).

## Fixed 2026-10-06: trees head-locked (fork 11323754a)

`BLUS30415_1_5` opens on the quest journal (Circle closes it). In the forest every frame had `N x332` non-camera draws:
the foliage `e2f574f69e3e346a` (1024x1024 leaves) draws with a DP4 camera `c[258..261]` (its shader reads c1-c4 with
the transform constant offset), while the profile knew only `c[256]` in the row layout. So all foliage stayed fixed to
the view (most visible on a near branch at the upper right). Found with profile `hidden_draws` (probe `hide=` did not
act in this game). Fix: `camera_blocks [256, 258]` + new key `column_vector_blocks [258]`. After: no non-camera scene
draws, the forest whole and world-fixed at yaw 25 / pitch 15 (`evidence/dao-foliage-2026-10-06/`); castle and
Bayonetta pose checks unchanged.

## 2026-10-07: outdoors and conversations (Matt's forest states)

- `BLUS30415_1_4` (forest conversation, cinematic camera with depth of field): pose sheet clean; the dark rectangles in the
  box are the dialogue's subtitle and reply panels (`fc6fc45502d91a9a`, boxed as HUD: hiding the program removes exactly
  them). The DOF composite `4dd42ea0e6add336` also grades the colour (hidden, the scene turns yellow): left as drawn.
- Frame rate in VR (simulator, 300%): `_1_4` (forest, no input) **120 Hz** (119.8, 0.21% late; 90: 0% late), RSX thread
  6.7 ms. `_1_5` opens on the quest journal, which Circle does not close (the close button is another key); `_1_3` is
  character creation. So DAO holds 120 outdoors as in the castle.
- Combat still unchecked: the forest conversation leads to a fight but the dialogue runs several minutes.
