# Dynasty Warriors 6 Empires (BLUS30306, disc 01.00)

Added 2026-10-01. Profile `bin/vr_profiles/BLUS30306.json` (generated in a battle), copy in `rpcs3/vr-non-working/`.
No patch. Desktop only. Savestate `bin/savestates/BLUS30306/BLUS30306_1_0.SAVESTAT.zst`: start of the first
mercenary battle (Empire Mode > New > Normal > Yellow Turban Rebellion > Ahui Nan > Battle > Mercenary > Shao Hua
Bandits).

## Frame rate

- The intro movie stalls at a raised Vblank (`cellVdec ... waiting for a consumer`); boot at 60 (or use the savestate).
- In battle: 60 at Vblank 60; **180** at Vblank 180 (RSX thread ~29%, main PPU thread busy): lots of headroom.
- **Frame-locked:** the player walks 307.9 units in a 0.6 s hold at 60 and 1036.8 at 180 (3.4x). No dt: the 1/60 and
  1/30 floats in data (`0x7e1884`, `0x7e8d70`, `0x7e9160`, `0x7f1b68`, `0x7f24f0`, `0x7df6c8`, `0x7e16a8`) poked
  to 1/180 changed nothing. The game imports `cellGcmSetVBlankHandler`, `cellGcmSetVBlankFrequency`,
  `cellGcmGetLastFlipTime` and `sys_time_get_system_time`. Player position (copy) at `0x8407d0`, written by a copy
  at `0x44c9e8` from the physics solver around `0x32614`. Profile runs it at **60** (`max_fps 60`); the headset
  reprojects. A 90 FPS fix needs the RR7 method (counter caves) or the logic step found from the vblank handler.

- 2026-10-01: no vblank handler is registered (the `cellGcmSetVBlankHandler` calls at `0x4d94b0`/`0x4d94e8` pass
  0; the conditional ones at `0x4e18a0`/`0x4e196c` never ran in a boot: no log line). Float values that advance
  ~1.0/s at 60 (`0xa0c35c`, `0xa0a684`) are animation values, not clocks (they oscillate at 180). Only an integer
  frame counter (`0x92d8e8`, +1 per frame) found. The logic is one fixed step per frame with no time variable:
  90 FPS would need patching movement and animation integrators one by one. Left at 60 (headset reprojects).
  Executable dumped to `tools/re/elf/BLUS30306.elf`; import stubs resolved by hand (the FNID table of `cellGcmSys`
  at `0x624058`, stub table `0x7d0260`).

## VR profile (generated)

`row_vectors`, camera `c[0, 264, 262, 263, 16, 256, 261]` (overlapping bases: `require_camera_aspect`),
`require_rigid_camera`, `nonrigid_camera_blocks [256]`, `camera_slots_read_directly`, camera position `c[104]` (2004 of
4696 eye points), HUD `c[256]` + `hud_skips_passes`, near 32 units -> 200 units/m (`eye_baseline` 12.8, unchecked).
96% of depth-tested draws covered. Desktop stereo and yaw-25 audit: world turns coherently, HUD and minimap stay
(`evidence/dw6e/stereo-and-audit-yaw25.png`).

## Open

- 90 FPS (frame lock); world scale; menus (2D, full-screen) and the strategy map in the headset.

## 2026-10-04: DW Gundam's step fix does not carry over (yet)

Dynasty Warriors: GUNDAM (BLUS30058, same developer) was fixed by redirecting a step constant (1.0 frames) passed to its
battle update. Here, memory clocks at Vblank 120 run 1.3-1.8x (vs 0.9-1.0 at 60); the one traced under the interpreter
(`0x30d1abb0`, 51.8 and rising, 0.95x at 60 / 1.77x at 120, many copies) is written as a vector (29.6, 0.5, 0.5, 0) at
`0x2ae068` (caller `0x2afab8`): an effect parameter, not the logic step. Not pursued further this time.

