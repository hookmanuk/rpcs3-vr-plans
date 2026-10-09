# Flower (NPUA80083, PSN 01.00)

**Parked (Matt, 2026-10-09): it needs a tilting joypad** (steering is SIXAXIS motion only).

Added 2026-10-07 (Matt: new game, at 90 FPS). Installed PSN copy (`dev_hdd0/game/NPUA80083`, licence
`UP9000-NPUA80083_00-FLOWERPS3PRIVATE.rap`). Profile `bin/vr_profiles/NPUA80083.json` (generated in level 1,
hand-fixed), patch file `bin/patches/NPUA80083_patch.yml`. No community patches exist for this game.
Executable `PPU-af4a1fb672a15f2be335a8b2c47595241eb758d6`; decrypted copy `tools/re/elf/NPUA80083.elf` (+ `.imports`).
PhyreEngine (thatgamecompany). Journey Collector's Edition (BCUS98377) carries another copy of Flower.

## Boot and input

thatgamecompany splash, then the apartment hub. **Flower steers by SIXAXIS tilt**, which the keyboard pad cannot send:
the dev key script (`RPCS3_VR_KEYS`) gained a `motion X Y Z G` line (fork `keyboard_pad_handler_vr.cpp`, values
0-1023, 512 level). Hub: `motion 300 512 512 -` (tilt sideways) zooms to the pot ("Hold Any Button"), then hold X ~8 s:
an intro movie, then the level-1 field. Savestate `vrtest_flower_l1` (= `NPUA80083_1_0`, mine, made on arrival in the
field; loads with the "Hold Any Button" prompt).

## Frame rate: "Unlocked frame rate (follows Vblank Rate)"

- Native 30: the GCM vblank handler (`0x5de110`, OPD at TOC-0x654, registered at `0x5de730`) sets the flip flag every
  `[[TOC-0x684]]` vblanks (2; setter `0x5de178`). The patch loads 1 (`0x5de114`: `li r10, 1`). `Apply To Savestates`.
- Game time is measured: memory dumps at Vblank 120 (`memclock.py`, 4 dumps) show the game clocks (f32 at
  `0xa252f4`.., f64 at `0x9f6f70`, `0xe51dd0`) at 1.0x wall time. Profile `max_fps 0`.
- Flat: 60 at Vblank 60; ~105 at Vblank 120 (RSX thread ~9.3 ms/frame, the game's own ceiling).

## VR profile

Generated in level 1 at Vblank 60 (`column_vectors c[256]`, linked `c[260]` = previous frame's matrix for motion
vectors, camera position `c[467]`, near 0.1 = metres). Hand fixes:
- `camera_blocks [256, 260]`: the sky (`915c1585d5d23d9f`) draws through `c[260..263]` (its `c[256..258]` hold a world
  rotation, and it reads no `c[259]`), so with `[256]` alone the sky stayed on the game camera. Renderer fix with it:
  a linked block that is the bound camera block itself is not transformed twice (row layout; column layout was already
  safe because the camera block writes back last).
- `view_y_down` removed: the generator saw a y-down viewport (the scene renders into a 1440x810 target that the
  composite flips), but with it head pitch and roll turned the world the wrong way on the simulator. Without it,
  yaw +20 moves the world right, pitch +10 down, roll 15 clockwise.
- `passthrough_hud` + `hud_programs ["1a1439daf3ea57eb"]`: the "Hold Any Button" prompt (512x128 text, blended into the
  display buffer, reads `c[464..467]`) was drawn over the whole view; now in the HUD box, world-fixed at yaw -20.
- `max_fps 0` (real time).

Scene renders at 1440x810 (1.125x of 720p) then composites to 1280x720. Game FOV ~45 degrees wide (zooms to ~25).

## Frame rate in VR (OpenXR Simulator, 300%, `vrtest_flower_l1`, flying with X held)

| Vblank | Result |
|---|---|
| 90 | **90.0 FPS, 0% late**, 1% low 83.6, RSX thread 9.6 ms/frame, 90 new frames/s |
| 120 | 104 FPS (the flat ceiling) |

Sustained: **90 Hz**.

## Open

- Only level 1 seen. Later levels (night, city with power lines) and the hub in VR unchecked.
- Culling at the headset FOV not looked at past yaw 20.
- Headset run.
