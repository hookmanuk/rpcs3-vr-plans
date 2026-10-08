# flOw (NPUA80001, APP_VER 02.10, from Journey Collector's Edition BCUS98377)

Added 2026-10-08 (the collection disc's games: every game gets a profile). Installed from the disc's
`PS3_EXTRA/D000/DATA000.PKG`. Profile `bin/vr_profiles/NPUA80001.json`, patch `bin/patches/NPUA80001_patch.yml` (copies in
`vr-non-working/`). Executable `PPU-c98a57283c22791786a49ffe8a58944b15b91c5e`; decrypted `tools/re/elf/NPUA80001.elf`.
Steers by SIXAXIS tilt (dev key script `motion`). The title screen is the playfield (the creature swims under the
logo). Savestate `vrtest_flow_title` (mine; loads in play).

## Frame rate: "Frame rate follows VR (real-time step)"

60 natively and already presents every vblank (120 at Vblank 120), but its game clock (`0xe960c4`, written at `0x23387c`
as clock += dt) ran 2x at 120 while the wall clock `0xe96110` stayed 1.0x. The main loop (`0x242638`) measures dt
(`0x242760`) and clamps it: below 1/60 (`0xb97f94`, read-only) it is raised to 1/60, above `[r30-0x7c20]` lowered. The
patch branches past the lower clamp (`0x242794`: `b 0x242ab0`): measured time at any rate; game clock 1.0x at 120.

## VR profile

Generated in play: `column_vectors c[256]` (rigid, `require_camera_aspect`), metres; `camera_position.slot` 467 removed
(matched 20 of 313 eye points); `max_fps 0`. Perspective camera (72 degrees wide) looking down on layered planes; no
depth buffer. Pose sheet (title playfield): world-fixed at every pose. Eyes: frusta offset -170, scene -160 (slight
depth, as the layers are near the focal plane).

## Frame rate in VR (simulator, 300%, tilting and boosting)

90: 90.0, 0% late; **120: 120.0, 0% late** (RSX thread 0.6 ms). Sustained **120**.

## Open

Later depths (the creature evolves, other creatures), headset run.
