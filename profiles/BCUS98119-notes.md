# inFamous (BCUS98119, disc 02.00 / APP_VER 01.00) - findings

PPU hash `PPU-412a9bf323b4743de21658a286f71dbe82cad807`. Evidence: `plans/evidence/infamous/`.

## Running it

- The disc has a `PKGDIR` (bonus content). RPCS3 asks in a Qt dialog whether to install it, which blocks
  an unattended boot. `dev_hdd0/game/.locks/BCUS98119` (empty file) marks it as done.
- Boot: autosave notice (`X`), title (`Return`), then it continues straight into the save/prologue.
  Nav script: `plans/tools` style, `X` then `Return` ~15 s apart; gameplay ~60 s after boot.

## Frame rate (2026-09-23)

No patch needed. The game is not vsync-locked on RPCS3: 60 FPS at Vblank 60, 83 FPS on the title scene
at Vblank 90 (gameplay here is load-bound at ~55-57 FPS mono). Its clock is real time: the static game-time
float `0x008eb2c4` advanced 0.95-0.96 s per wall second at both Vblank 60 and 90 (memory dumps diffed with
the new `RPCS3_VR_MEMDUMP` hook, `memclock.py`), so `match_headset_refresh_rate: true` and
`config_BCUS98119.yml` has `Vblank Rate: 90`. (The community "Disable speed limit" patch refers to the
0.06 s delta clamp, which only matters below ~17 FPS.)

## VR profile (2026-09-23)

`bin/vr_profiles/BCUS98119.json`, from the generator (`generated-in-emulator-BCUS98119.json`) then edited.

- `row_vectors`. The camera sits after a variable number of object-matrix slots: view-projection at
  `c[263]` (after a 4x4 world matrix at 256 and a 3x3 at 260), `c[256]` (no object matrix), `c[260]` or
  `c[259]`. The generator only kept non-overlapping blocks `[263, 256]` (missed 245 of ~2100 camera draws
  per frame in the tutorial). Profile: `[263, 256, 260, 259]` with the new `require_camera_aspect: true`,
  which also requires the output-aspect projection so a neighbouring window is not mistaken for a camera
  (a HUD reticle passed the perspective + rigid tests at 259). Offline simulation of the renderer rule on a
  capture: 0 mismatches against a reference that tests every base (`simblocks.py`).
- Near plane is 10 units (the world is in centimetres): generated `eye_baseline` 1.28 was the generator's
  20x clamp. Set to 6.4 (clamp raised to 200x in the generator), convergence 256.
- No camera position slot found. HUD: orthographic `c[263]`.
- Stereo (desktop, cutscene): far +14-16 px (expected 16.5), near car +6. Yaw audit: world, sky and HUD
  behave (`audit-yaw25.png`). Stereo costs a lot here (13,500 draws/frame in the tutorial: ~25 FPS).

Open: headset run; world scale not checked against a known size.
