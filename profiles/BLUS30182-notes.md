# Pure (BLUS30182 v01.00) - findings

PPU hash `PPU-87bda999eb08ef36bfb8f3abf2cd95a7e8a615d8`. The game uses PSGL (statically linked); TOC base `0xd2c984`.

## Frame rate (2026-09-22)

- PSGL paces flips in two wait loops (`0x7676c0`, `0x7677f8`, the second called from the PSGL vblank
  handler `0x762638`): wait until `cellGcmGetVBlankCount() >= display.last_vblank (+0x30) + display.interval (+0x14)`.
- Device object: `*(*(TOC+0x2a8c))` = `*(0x1050300)`; display = `device+0x98`. `device+0x9c` is the requested
  swap interval, copied to `display+0x14` by `0x7620d8`. Menus run interval 1 (60 FPS); races set 2 (30 FPS).
- Game time = vblank count / `device+0x14` (float display refresh, 60.0 or 59.94, loaded at PSGL init from
  TOC `+0x2b58` = `0xd2f4dc` and `+0x2b5c` = `0xd2f4e0`). Measured: clock rate 1.001 at interval 1 and 2 with
  60 Hz vblank; 0.500 with `device+0x14` = 120.0. This is why Vblank Rate 120 ran the game at double speed.
- Patch `BLUS30182-patch.yml` (installed as `rpcs3/bin/patches/BLUS30182_patch.yml`): `li r11,1` at `0x7676e4`
  and `li r9,1` at `0x76782c` (interval 1 in both waits), and `bef32` the two TOC refresh constants to a
  configurable Refresh Rate. With Vblank Rate 90 + Refresh Rate 90: 87-90 FPS in the tutorial ride, game clock
  rate 1.000.

Next: the refresh value could follow the headset automatically (profile writes the effective vblank rate to
`device+0x14`, which the game reads live) once Pure has a VR profile.

## VR profile (2026-09-22)

`rpcs3/bin/vr_profiles/BLUS30182.json`. Found from a flat capture in the tutorial ride (no native 3D to
fit against); evidence in `plans/evidence/pure/`.

- Camera block `c[26..29]`, **DP4 layout** (`matrix_layout: column_vectors`): slot i is the row for clip[i].
  Read by 789 of 848 draws. On world draws `c[29]` (clip w) is a unit vector, so w is view depth in world
  units (metres: the rider is ~1.6-2.6 units from the camera). The 1024x1024 shadow pass uses the same
  slots orthographically and is off-aspect.
- Second camera block `c[39..42]` (profile `camera_blocks: [26, 39]`, added 2026-09-23): programs
  `252ee9b3` and `48027980` (ground clutter: rocks/stones) read no `c[26..29]` and carry the same
  view-projection at `c[39..42]`. Without it they stayed on the game camera and hung head-locked in the
  headset (rocks in the sky when looking up). A per-eye instanced-draw path was tried first on a wrong
  diagnosis and backed out (`plans/evidence/pure/instanced-per-eye*.{patch,txt}`, untested).
- Sky (2026-09-23): vertex program `16991145` draws the sky dome with clip x = c[26], y = c[27],
  z = w = c[29] and never reads c[28]; blocks needed all four slots, so the sky stayed on the game camera
  (moved with the head; looking up showed the game's white horizon haze mid-view). DP4 blocks may now
  omit the z slot. `require_rigid_camera: true` stops `dc11dd79` (full-screen quad, junk in c[39..42])
  being taken as a camera once 39 was listed. Verified with `RPCS3_VR_AUDIT=pitch:35` (new pitch mode of
  the rotation audit): `plans/evidence/pure/sky-before-after.png`, `rocks-before-after.png`.
- Camera position `c[18]`: equals the eye point solved from `c[26..29]` on every draw that reads it.
- HUD: `c[256..259]` orthographic pixel matrix.
- Stereo values are chosen, not fitted: `eye_baseline` 0.064 (1:1 metric), headset eye offset
  `sep*conv` = A x 0.032 with A = |row0| = 1.3006 (75 deg horizontal FOV at rest) -> sep 0.016, conv 2.6.
- Probe proof (VR off, one scene): yaw/roll move the world, HUD fixed; negative control `c[400]` touches
  0 fills; `stereo=0.05` shifts far scenery +92..94 px (expected 96 at 3840 wide), HUD 0.
- Render-twice (desktop, OpenXR off): far +8 px (expected 8.5 at 533 px/eye), HUD 0, rider -5 px.
- Needed a renderer fix: Pure copies its frame to the display buffer with NV3089 blits
  (`c0000000 -> c0398000/c0730000`, 1024+256 columns). Blits were not mirrored, so the right eye missed
  the pause/tutorial blur. `VKGSRender::vr_mirror_blit` now repeats 1:1 surface-to-surface blits in the
  right-eye cache.
- `match_headset_refresh_rate` is left off: the frame-rate patch's Refresh Rate is fixed at boot, so the
  vblank must stay at the configured 90 (headset at 90 Hz). Pure's config has `Vblank Rate: 90`.

Open: headset validation (scale, comfort, HUD box); FPS 80-87 with stereo at 300% (vs 90 mono);
the camera probe renderer only arms by default when `RPCS3_VR_PROBE_FILE` is unset.

## VR frame rate at 300% (2026-10-01)

Regression state `vrtest_pure_race` (Alto Vista race from the start line, holding R2 = W): **90 Hz sustained**
(90 Hz: 89.7 FPS, 0.28% late; 120 Hz: 117.6 FPS, below the 99% mark). Savestates need `Compatible Savestate Mode`
(set only while saving). R2 accelerates, not Cross. `evidence/vrtest/2026-10-01-1406`.
