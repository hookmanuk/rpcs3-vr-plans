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

## Frame rate: unlocked, real time at any rate (2026-10-02, fork 1b068732b)

- **Correction:** last night's "not real-time at 60" was a bad test: I compared Vblank 30 and 60 with the patch, but at
  Vblank 30 each vblank still counts as 1/60 s, so the game ran at half speed there. At 60 Hz the community patch is
  right; above 60 it runs fast.
- The limiter `0x767b8` has two modes (flag `[0x66a3c8]`, set by `0x76a70`): variable (flag 1, used throughout boot,
  movie and gameplay so far): step `0x887c94` = vblanks elapsed x `[0x887c90]` (a factor with several writers); fixed
  (flag 0, set at three call sites, not seen yet): step 2.0. It then waits `[0x887ca0] + 1` vblanks; the community
  patch (`li r3, 0` at `0x76850`) removes that in the variable mode.
- **Patch "Unlocked frame rate (VR)" v2.0** (`bin/patches/BLUS31460_patch.yml`, copy in `vr-non-working/patches/`),
  enabled by default: variable mode: step = vblanks elapsed x `[0x887ca4]` (`0x7684c`-`0x7686c`, no wait); fixed
  mode: step = 2 x `[0x887ca4]` (`0x767e4`-`0x767fc`, still waits for the interval); `0x887ca4` = 1.0 at load. The
  word is padding between the interval and an 8-byte table; the profile keeps it at 60 / vblank rate
  (`game_vblank_frames_f32: ["0x887ca4"]`).
- **Verified:** first with the code poked into the community-patch savestate on the interpreter (x1.0 at 120 with the
  patch, x2.0 without), then from a savestate made on the patched disc boot, recompiler: world positions x1.0 their
  60 Hz speed at 72, 90 and 120 (~900-1200 positions). **Jump (gravity):** Roxas's apex / airtime: original game at
  30 FPS 152 / 0.70 s, patched 60 165 / 0.77 s, 90 157 / 0.73 s, 120 159 / 0.75 s (`tools/re/kh2_jump.sh`; his
  position is `0x25e4080`, up is negative y): no "double gravity". The movie stalls at 90 Hz: `video_vblank_rate: 60`.
- Profile `max_fps 0`, `default_fps 0`, `vblanks_per_frame` dropped. **VR at 300%: 72 Hz sustained** (Twilight Town;
  90 averages 88.7 FPS, 0.4% late).
- Savestates: `vrtest_kh2_twilight` (= `_1_3`, made on the patched disc boot, after the tutorial messages: the
  regression state), `vrtest_kh2_twilight_30` (= `_1_0`, the original 30 FPS game).
- Fixed mode unchecked: when the flag is 0 the game runs at half the vblank rate with the scaled step.
