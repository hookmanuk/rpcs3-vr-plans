# Super Stardust HD (NPUA80068, PSN, APP_VER 06.00, VERSION 07.00)

Added 2026-10-01 (Matt's new-games list); licence (.rap) added by Matt 2026-10-02. Installed at
`dev_hdd0/game/NPUA80068` (boot `USRDIR/EBOOT.BIN`). Executable hash `PPU-6229c31ae65cc306d1dad0b4ed10b3300d0ad870`.

## Files

- Profile `vr-non-working/vr_profiles/NPUA80068.json` (untracked copy in `bin/vr_profiles/`). No patch.
- Savestate `bin/savestates/NPUA80068/vrtest_ssd_lave.SAVESTAT.zst` (= `NPUA80068_1_1`): Arcade, Easy, Lave, the
  first second of the level (3 ships, 3 bombs). Reached by: title Return; Single Player X; Arcade X; Up (Easy) X;
  Lave X; the controls screen X; the tips screen X. Made with the `RPCS3_VR_SAVESTATE` hook.
- Regression: `vrtest_states.txt` WALK `script` = `tools/re/vrtest_boot/vrtest_ssd_lave.walk` (fires in circles
  from the boot; with no input, or holding one direction, the game is over in about 30 s), SETTLE 5 so both
  measured windows are play (game over comes at ~30 s even so).
- Controls (keyboard pad): left stick moves, **right stick shoots** (the pad template now maps it to T/F/G/H), L1 boost,
  R1 bomb, L2/R2 weapon. Evidence: `evidence/sshd/`.

## Frame rate: real time, no patch (2026-10-02)

- Native 60 FPS, presents every vblank (72/90/120 FPS at Vblank 72/90/120).
- The game measures its own frame time (perf block `0x8478b8` FPS, `0x8478dc` ms: 15.9 at 60, 7.6 at 120).
- Memory dumps 2 s apart (`tools/re/rt_dumps.sh`, `rthist.py`) from the level-start savestate: world positions move
  at **x1.0** their 60 Hz speed at 72 (256k positions) and 90 (116k); positions on the planet's surface also x1.0.
  An earlier state taken during the ship's death gave x0.9 at 72/90: the game slows time when the ship dies, so that
  state was not a fair test.
- Profile `max_fps 0`, `default_fps 0` (headset rate).
- **VR at 300%: 120 Hz sustained** (0% late at 72 and 120, 0.14% at 90; RSX thread 1.1-1.5 ms;
  `evidence/vrtest/2026-10-02-1122`).

## VR profile

Generated in the emulator from gameplay (`evidence/sshd/generated-in-emulator-NPUA80068.json`), then one hand fix:

- `row_vectors` camera block `c[32]` (a full model-view-projection per draw), 100% of depth-tested scene draws
  covered, no camera position (none needed: `eye_offset: baseline`). Projection A 1.117 (the camera rolls with the
  ship: rows 0-1 rotate in x/y). Near plane 5.005 units: `eye_baseline` 3.2 (50 units/m). The planet's centre is
  34.2 units ahead, i.e. **a ~0.7 m tabletop diorama** in the headset; World Scale in the VR menu changes it.
- **Hand fix: no `screen_space.depth_offset_projection`.** The generator wrote it (1048-1064 of 2848 sampled draws
  are `w = z + d`: geometry in the camera's own space at a fixed depth, which it takes as a 3D HUD, as in Blur).
  Here the whole game is drawn in camera space around the planet, 34.2 units ahead: the planet's surface particles
  (program `7df9b4fc`, depth-tested; hiding it removes the green dots, `evidence/sshd/hidden-draws-test.png`),
  small depth-tested quads (`2f651d81`, 1024x1024 texture) and the 3D message and menu text (`12a76a61`, no depth
  test; up to ~48 draws per frame). The same programs also draw at that depth with tilted or rolled
  matrices, which the rule does not catch. With the rule on (headset only), the caught draws went into the HUD box
  while the rest stayed in the diorama. With it off, everything stays together in the world when the head turns
  (`sim-gameplay-y0.png` / `-yaw25.png`).
- Generator: no reliable signal separates this from Blur's HUD. Blur's HUD draws have no depth test, but most of
  SSHD's caught draws per frame are the no-depth-test message text too. A depth-test split was tried and reverted
  (same output). Added to the playbook's symptom table instead.

## Checked (OpenXR Simulator, Dream Air, 2026-10-02; desktop stereo)

- Desktop stereo: matches the flat game (planet, asteroids, nebula, HUD).
- Head straight / turned 25 degrees: gameplay, HUD, pause menu, title screen and attract mode all stay fixed in the
  world. The chrome title logo changes colour with the head turn (environment-mapped reflection: expected).
- **Open: the boot loading screen** (comet and "This game saves data automatically" text, ~2-8 s after boot): with
  the head turned, some frames show it where it would be with the head straight (`sim-loading-yaw25-ghost.png`).
  Only on that screen. Probably loading-time frames composited with a stale pose. Check in the headset.
- Not checked in the headset (the simulator is not headset testing).
