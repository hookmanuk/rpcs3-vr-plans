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
