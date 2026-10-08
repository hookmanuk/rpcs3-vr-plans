# Need for Speed: Hot Pursuit (BLUS30566, disc 01.00, US)

Added 2026-10-07 at Matt's request (ISO in `F:/rpsc3/games`; custom config made from the global one). Savestate
`BLUS30566_1_0` (first career event, Roadsters Reborn, Grand Ocean Road, race intro fly-by; Cross skips it).
Executable `PPU-edd75fcdb84e1c33c0c4d05a93143832e374b5d1`. No community patch exists for this ID.

## Frame rate (flat, simulator off, 300%)

- Races run at 30 FPS; menus at 60. Not vblank-bound: Vblank 120 still gives 30.
- **Frame limiter:** `0x4acb34` busy-waits on `mftb` until `period x frames` have passed (limiter object at
  `this+0x700fb0`, live `0x3a90feb0`: period `+0x20` = 1,333,333 ticks = 1/60 s at 80 MHz; byte `+0x36` = off flag).
  The frame count comes from `this+0x700ff2` (2), read at `0xe9bf4`. It returns the number of 1/60 s steps to simulate
  (at least that count, catching up to 5), stored at `this+0x700ff8` and consumed by the step loop at `0xec3fc`.
- **Vblank handler** `0x738e9c` (handler pointer at TOC-0x2e58, TOC `0xc8d708`) counts down and releases the flip label;
  the count is reloaded from `[base+0x670]` (base = `[TOC-0x2ed0]` = `0xdee070`, so `0xdee6e0`) = **2 vblanks per flip**.
- Patch (`vr-non-working`, *Unlocked frame rate (VR)* 0.1, test): `0xe9bf4` `li r4, 1` and `0x4acb78` `b 0x4acbd4` (skip
  the wait). With 2 vblanks per flip at Vblank 120: **60 FPS, real time** (race clock 13.49 s over 13.52 s).
- With 1 vblank per flip (poke `0xdee6e0` = 1): 110 FPS at Vblank 120 (RSX thread 8.9 ms: headroom), but the game runs
  **1.8x fast**: the simulation takes whole 1/60 s steps (each 0.016666 s), at least one per frame. At VR 90: 1.5x fast.
- Not the step size (tested, no change in speed): every float 1/60 in the code (156, by patch), the limiter period
  (888,889), ten u32 16666 in the heap (`0x3a26d244`..). dt is copied `0x2d6578` (`stfs f1, 0x240(r22)`, f1 from the
  step loop at `0xea014..`) -> `0x4147f4`; values are 0.016666 x steps, so the step is probably 16,666 us / 1e6 built in
  code. Next: trace f1 back from `0x2a1d1c` (the per-step call) to the multiply.
- Flat image: the player's car is blown out (almost white) in the garage and in races: an emulation lighting issue,
  separate from VR.

## 2026-10-07 (later): 90 FPS real time flat; VR profile generated

- The simulation step: per-step code `0x2a1d1c` makes dt = (clock delta in us) / 1e6 from a game clock object
  `[[0xd3bcec]+4]+0x38` (getter `0x3e5834`), advanced in `0x4ac950` by `+0x10 x +0x18 x 1e6` per step; `+0x18`
  (`[[0xd3bcec]+4]+0x48`) is the step, 1/60. `game_frame_time_f32: ["[[0xd3bcec]+0x4]+0x48"]` (new nested-pointer
  address form, fork 13d7ad184) sets it to 1/fps.
- Patch 1.0 (`vr-non-working`): `0xe9bf4` `li r4, 1`; `0x4acb78` skip the limiter wait; the vblank handler's countdown
  reload `0x742c60`, the per-frame label `0x738e78` and the RSX label command `0x7410b0` all 1: a flip every vblank.
  Flat: 110 FPS at Vblank 120 (RSX thread 8.9 ms). **Race clock real time at VR 90** (10.99 s over 11.01 s).
- Found on the way (fixed in the fork, generic): the measured-rate fallback wrote 0.14 s during a load stall and never
  replaced it: the race ran 12x fast. Rates under 40% of the VR rate are now ignored.
- Generated profile: `column_vectors_xyw c[212]`, camera slots read directly, `depth_offset_projection`, frame step
  key added by hand, `max_fps 0`.
- **VR frame rate (simulator, 300%, `vrtest_boot/BLUS30566_1_0.walk`):** 72.9 FPS at Vblank 90 (RSX thread 13.6 ms), 70.2
  at 72: RSX-bound, **below 90 and just below 72** (DWM was using ~3.7 cores; remeasure on a clean boot).
- **Simulator pose check** (`evidence/nfs-hp-2026-10-07/`): the car's shadow differs between the eyes (left of the car
  in the left eye, right in the right: a screen-space shadow pass, as Sonic/R&C); the 2D HUD (speedometer, mirror,
  bounty, position) is drawn in the scene in stereo, no HUD box (`HUD none`: needs `hud_programs`/`passthrough_hud`);
  stripes at the sky's edge on yaw/roll; the player's car is near-white (flat too: emulation).

Status: **not 90 yet.** 60 FPS real time works; 72/90 needs the simulation step changed to 1/72 or 1/90 (or the flip
count kept at 2 and Vblank 144/180, which still simulates at 60).

## 2026-10-07: per-eye car shadow (open)

The car's shadow sits left of the car in the left eye and right of it in the right eye, at every pose: the parallax of
something at the wrong depth, or a shadow lookup built for the game camera. Not a depth-reading pass (the generator
lists none), not `depth_offset_projection` (off: unchanged, and a rectangle outline appeared, so kept on). HUD check:
the speedometer, mirror and bounty stay in the HUD box (they turn with it at yaw and roll), so the 2D HUD is fine.
Next: find the program that draws the car shadow (inspector, `prog=` RTDUMP before/after) and how its shadow matrix
is built (likely world -> light from the camera inverse in vertex constants: `game_camera_programs` for it, or a
depth-remap variant).

## Open (Matt, headset, 2026-10-08): menu lights move with the head; double vision in races

Matt's states (hard-linked so the per-game cap cannot delete them):
1. `BLUS30566_1_1` = `vrtest_nfshp_matt_menu` (15:56, the menu): moving the HMD makes lights move on the screen.
2. `BLUS30566_1_2` = `vrtest_nfshp_matt_race_paused` (15:57, a race, paused): the car ahead shows double vision, and
   the whole race looks low resolution, probably from that misalignment (two images not lining up read as blur).
To fix (not started): check the menu on the fixed screen with `simpose.py` (which layer the lights are in), and in the
race compare the eyes (`eyesame.py`, full-resolution crops of the car ahead) for a per-eye offset on scene or post passes.
