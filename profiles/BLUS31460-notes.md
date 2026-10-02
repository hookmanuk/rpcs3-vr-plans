# Kingdom Hearts HD 2.5 ReMIX (BLUS31460, disc 01.00)

Added 2026-10-02 (Matt's new-games list). A collection: the launcher starts `kingdom2.self` (Kingdom Hearts II
Final Mix, `PPU-f18bcdcc...`), `BBS.self` (Birth by Sleep Final Mix) or the Re:coded movie.

## Files

- Profiles (`vr-non-working/vr_profiles/`, untracked copies in `bin/`): `BLUS31460.kingdom2.json` (KH II) and
  `BLUS31460.json` (launcher; same values, so the headset session exists before the executable switch).
- Patch `bin/patches/BLUS31460_patch.yml`: the community 60 FPS patch (`li r3, 0` at `0x76850`) as "Unlocked frame
  rate (VR)", enabled by default. Community note: doubles gravity, some things move at double speed.
- Savestate `bin/savestates/BLUS31460/vrtest_kh2_twilight_30.SAVESTAT.zst` (`_1_0`): Twilight Town, first control,
  **without** the patch (30 FPS; patches are not applied when a savestate loads).
- Boot script `tools/re/kh2_boot.ps1`: disc -> collection -> KH II -> New Game (Standard, vibration on) -> opening
  movie (~6.5 min; Start pauses it) -> first scene skipped (Start > Skip Scene) -> Twilight Town. 600 ms presses with
  4.5 s gaps (a 3 s gap dropped the last confirmation). **Don't kill the script's process tree while RPCS3 runs:
  RPCS3 is its child and dies with it.**
- First boot created system data and saved the display settings (no save of Matt's existed).

## VR profile (generated in Twilight Town, hand-fixed; OpenXR Simulator checked)

- Generator: `column_vectors` `c[256]` (world) and `c[56]` (skinned characters, bones in `c[60..]`), 97% coverage,
  w-row scale 1 (no per-object palette as in KH 1: `camera_palette` not needed), HUD `c[60]`, near 2 -> 1.28.
- Fixed: the HUD "block" `c[60]` is a bone matrix (rigid transform, w row `0 0 0 1`), not the HUD: dropped. The 2D
  layer (tutorial box, portrait) is matrix-less screen-pixel draws as in KH 1 (`c[0]` = 1/640, 1/360, 640, 360):
  `passthrough_hud` + `hud_programs` [`67d8f773436e61a5`, `b4c6872a86d66c95`]: in the HUD box, world-fixed at 25
  degrees. GS-pixel-projected effects `a0ae7ea7d5ffb37f` (as KH 1's `b7585fdc`): `require_rigid_camera` +
  `preprojected_programs`. `eye_baseline` 6.4 (1 unit = 1 cm as KH 1; Roxas ~120-155 units tall on screen, rough).
- Unchecked: menus (the pause/command menu), battles, cutscenes in the headset.

## Frame rate

- Native 30 in gameplay and cutscenes. Patch `bin/patches/BLUS31460_patch.yml` (copy in `vr-non-working/patches/`):
  the community 60 FPS patch, **off by default**: with it, at Vblank 60 vs 30 from the same savestate
  (`tools/re/kh2_speed.sh vrtest_kh2_twilight OUT RATE`), Roxas runs much further in the same 1.5 s press (the
  community notes double gravity and double-speed objects). The game steps per frame; a real-time >30 needs its
  step found (as Jak 1). The VR profile keeps `max_fps 30` (reprojected).
- Savestates: `vrtest_kh2_twilight` (= `_1_2`, **patched** code, after the tutorial messages: Roxas can move; the
  first messages freeze him) and `vrtest_kh2_twilight_30` (= `_1_0`, unpatched, during the tutorial messages).
  Patches are not applied to savestates: a savestate keeps the code it was saved with.
