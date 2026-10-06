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

Status: **not 90 yet.** 60 FPS real time works; 72/90 needs the simulation step changed to 1/72 or 1/90 (or the flip
count kept at 2 and Vblank 144/180, which still simulates at 60).
