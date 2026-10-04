# X-Men Origins: Wolverine – Uncaged Edition (BLUS30268, disc 01.00)

Added 2026-10-04. Profile `bin/vr_profiles/BLUS30268.json` (generated in the first jungle area, hand-fixed), patch
file `bin/patches/BLUS30268_patch.yml`; copies in `rpcs3/vr-non-working/`. No community patches exist for this game.
Unreal Engine 3. Executable `PPU-1967a332fcb03f5c7b1540671268da920155a352`; decrypted copy `tools/re/elf/BLUS30268.elf`
(+ `.imports`). Runtime TOCs: `0x2181938` is the one most game code uses (the entry descriptor's `0x2154680` is not).

## Boot

`tools/re/xmen_boot.sh` (logos, title Start, New Game, Normal, then the unskippable ~2.5 min intro movie and in-engine
opening) reaches the first control in the jungle; a "Health and Vitals" tip (X). Savestates need **Compatible Savestate
Mode** ("failed to lock SPU threads execution" otherwise): `xmen_jungle0` = `vrtest_xmen_jungle` (first control).
Standing still, the soldiers kill Wolverine within a few minutes ("Mission Failed").

## Frame rate: "Unlocked frame rate (VR)" (+ "Present every vblank (flat 60 FPS)", off by default)

- Native 30: the game's vblank handler (`0x18a0cf0`, registered at `0x18bd108`) flips the pending buffer when its
  vblank count since the last flip exceeds 1 (`cmplwi cr6, r9, 1` at `0x18a0d2c`), with V-sync on (`settings+0x18c`).
- A second limiter: the main loop (`0x670678`) waits for `1 / target FPS`, the target from a virtual call
  (`0xeb9900`: 0.0 = no limit, or `obj+0x4e0` = **62** with V-sync on). Patching only the flip gave 60 at Vblank 60
  but 62 at any higher rate.
- With both: 120 FPS at Vblank 120, 180 at Vblank 180; game time real-time at 60/120/180 (memory clocks 1.0x;
  `tools/re/xmt_sheet.png`: walking from the same savestate reaches the same spot at the same wall time).
- **In VR the flip patch is wrong:** a stereo frame takes 14-22 ms, so at a 90 Hz vblank frames alternate between one
  and two vblanks and settle at 45-50 FPS. The game's own every-second-vblank pacing at twice the rate is steady, so the
  VR patch only removes the 62 cap and the profile sets `vblanks_per_frame: 2` (72 Hz = Vblank 144). The flip patch is
  kept as a separate entry, off by default, for flat 60 FPS.
- Not the GPU: 46 FPS at 100% as at 300%; the RSX thread waits ~53% in `nv406e::semaphore_acquire` on the game's
  render thread, which polls a fence (`0x18a8cc0`, `sys_timer_usleep(200)`) in lockstep.

## VR profile

Generated in the jungle: `row_vectors c[0]` (camera-relative: translation only the near plane), 100% of scene draws
covered, camera position `c[4]`, near 5 -> ~50 units/m (`eye_baseline 3.2`, UE3's usual scale), `hud_skips_passes`.
Hand fixes:
- **HUD block `c[200]`** (was `c[204]`): the HUD draws (`8dc5cbd5eb2c59ec`, masks `14d3eb14e609e1b1`) keep the pixel
  ortho in `c[200..203]` and a second (UV) matrix in `c[204..207]`; with `c[204]` the pause menu's blood splat and icons
  were missing and the menu sat full-size. With `c[200]` the pause menu is boxed and complete.
- `max_fps 72`, `default_fps 72`, `vblanks_per_frame 2` (above).
- Tried and dropped: `depth_remap_programs: [07d7202eb4af1d79]` (the same UE3 shadow-mask program as Asura's Wrath; no
  visible change here), `zcull_approximate` (no frame-rate change), removing the camera position slot.

## Frame rate in VR (OpenXR Simulator, `vrtest_xmen_jungle` walking)

| Resolution | 72 Hz (Vblank 144) | 90 Hz (Vblank 180) |
|---|---|---|
| 300% | **71.6 FPS, 0.17% late** | 79.0 FPS |

Sustained: **72 Hz** (no margin; busier fights unmeasured).

## Headset checks (simulator)

- Jungle: world, Wolverine, enemies coherent straight / turned 25 / pitched 25; HUD (health) boxed; pause menu boxed.
- **Open: shading differs between the eyes** on some surfaces (the wooden gate is darker and lower-contrast in the
  left eye than in the right and than flat). Present in desktop stereo too, and on both multiview and two-draw. Bisected
  to the base-pass program `991df40b5c30d3b5` (it draws the gate; the eyes already differ right after it); not its
  camera transform (also with `gamecam=`), not texture LOD, not the shadow, light or post passes (hidden one by one).
  Next: compare the program's fragment constants and the textures it binds per eye (`RTDUMP prog=` of its inputs).
- **Open: culling.** The game culls to its 91 x 60 degree view; the sky dome's edge shows at the top-left of the headset
  view even looking straight. The live view-projection copies (`0x158xxxxx`, translated VP at view +0x180, VP at
  +0x210, projection at +0x90) are not written by PPU code while it runs (write watches over the game and PRX code
  saw nothing), so the scene view seems to be built elsewhere (SPU?). Asura's Wrath's UE3 route (`GetViewFrustumBounds`
  by its DELTA^2 constant) did not match this build's code. Not fixed.
- Not seen: menus beyond pause, cutscenes, later levels.
