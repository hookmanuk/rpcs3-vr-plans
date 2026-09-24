# Split/Second (BLUS30300) notes

Disc 01.00, PPU hash `PPU-a87309d1889eafae04bd1e78986b1065ac471858`. VR profile `bin/vr_profiles/BLUS30300.json`
was made with the in-emulator generator (2026-09-22).

## Frame rate (2026-09-23)

Split/Second statically links the same PSGL library as Pure. libgcm_sys runs LLE.

- **Flip pacing.** PSGL's vblank handlers flip when `vblank >= display+0x30 (last) + display+0x14 (swap interval)`:
  `lwz r9,0x14(r31)` at `0x813cb4` and `0x81a668`. The game sets interval 2, so it runs 30 FPS. The same
  byte pattern as Pure's patch.
- **Game clock.** Each frame, `0x118c04` reads PSGL's vblank tick counter (`device+0x5ac`, incremented by the
  vblank handler; getter `0x8070e8`) and runs that many ticks since the last frame (capped by a config value).
  `0x509a4` turns ticks into the frame dt: `dt = ticks * 1/60` (`lfs f29` at `0x50ad0` from `0x1157f18`, a
  constant nothing else reads; `fmuls` at `0x50af4`). The dt feeds the game-time total at `this+0x1a724` and
  is passed on (Havok etc.). Other code divides ticks by PSGL's refresh at `device+0x30` (e.g. the countdown at
  `0x1c364`); the refresh comes from the 30/50/60/59.94 table at `0x11726e0` (60.0 at `0x11726e8`, 59.94 at
  `0x11726ec`). There is also a PAL fix-up (`0x118ca0`): refresh 49-51 Hz adds one tick every 5.
  This is why a higher Vblank Rate speeds the game up: more ticks per second, each still worth 1/60 s.
- **Patch** `BLUS30300-patch.yml` (installed as `rpcs3/bin/patches/BLUS30300_patch.yml`): interval 1 at both
  sites; refresh 60.0/59.94 -> Refresh Rate; `0x1157f18` -> Refresh Rate with `fmuls` -> `fdivs f30,f0,f29`,
  so `dt = ticks / Refresh Rate`. Refresh Rate must equal the Vblank Rate.

Measured with a temporary probe (removed) that found the frame counter / game-time pair (`this+0x1a71c` /
`this+0x1a724`) by memory diff and logged game time against wall time, in a Season race (Airport Terminal):

| Vblank Rate | Refresh Rate | game time / wall time |
|---|---|---|
| 90 | 90 | 0.994-1.005 (two runs) |
| 90 | 60 | 1.497-1.504 (control: unpatched dt) |

With the patch at 60 Hz the menus run 60 FPS. The race frame currently costs about 17-25 ms here (desktop,
`RPCS3_OPENXR=0`, VR stereo on, Write Color Buffers on, 100% resolution), so flips land on the next vblank
after the frame is ready: 30 FPS at 60 Hz, 40 at 120 Hz, 30 at 90 Hz. That is emulator load, not a game limit.

- `match_headset_refresh_rate` stays off (as for Pure): Refresh Rate is fixed at boot, so the vblank stays at
  the configured 90. `config_BLUS30300.yml` has `Vblank Rate: 90`, patch Refresh Rate 90.

Open: headset run; race FPS at 90 Hz is load-bound (see above).
