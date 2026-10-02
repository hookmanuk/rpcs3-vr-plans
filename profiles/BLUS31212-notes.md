# Kingdom Hearts HD 1.5 ReMIX (BLUS31212, disc 01.00)

Added 2026-10-02 (Matt's new-games list). A collection: the launcher (`EBOOT.BIN`, game selector) starts
`kingdom.self` (Kingdom Hearts Final Mix), `recom.self` (Re:Chain of Memories) or the 358/2 Days movie.
Executable hashes: launcher `PPU-83f4a1c6...`, `kingdom.self` `PPU-d626d983...`.

## Files

- Profiles (`vr-non-working/vr_profiles/`, untracked copies in `bin/`): `BLUS31212.kingdom.json` (KH Final Mix)
  and `BLUS31212.json` (the launcher, so the headset session is prepared before the executable switch; same values).
- Patch `vr-non-working/patches/BLUS31212_patch.yml` (copy in `bin/patches/`): the community 60 FPS patch
  (`li r3, 0` at `0x36870`) as "Unlocked frame rate (VR)", enabled by default.
- Savestate `bin/savestates/BLUS31212/vrtest_kh1_dive.SAVESTAT.zst` (`_1_1`): Dive to the Heart, first control,
  patch applied (`_1_0` is the same place without the patch, 30 FPS).
- Boot script `tools/re/kh1_boot.ps1` (disc -> collection -> KH Final Mix -> New Game -> opening movie -> Dive).
  Input needs **600 ms presses** (150 ms ones are dropped). The title's cursor can start on Load on later boots.
  The opening movie (~3.5 min) can't be skipped on a new game; Start pauses it, Select is RPCS3's home menu.
- New Game choices made: Final Mix difficulty, **Manual camera** (auto-rotating camera is bad in VR), vibration on.
  System data and trophies were created on first boot (no save of Matt's existed).

## Frame rate

- Native 30 (cutscenes and movie 30). With the patch: 60 at Vblank 60, **120 flat at Vblank 120**.
- **Frame-locked above 60:** at Vblank 120 Sora walks ~2x as far for the same key press
  (`tools/re/kh_speed.sh 60|120`). Profile `max_fps 60` / `default_fps 60` (reprojected in the headset) until the
  game's step is found (memory-dump method as Jak 1: `memcount.py`).

## VR profile (generated in the Dive, then hand-fixed)

- Generator: `column_vectors` `c[256]`, 98% scene coverage, w-row scale 0.33-3.1 -> `baseline_per_w`, near plane
  2 -> eye_baseline 1.28 (20 units/m), HUD none.
- **Skinned characters head-locked, limbs stretched:** KH skins rigidly with a palette of full clip matrices
  `c[256 + 4k]` (k = vertex attribute 7 .w x `c[465].x`), so only bone 0 (`c[256]`) got the eye transform. New
  profile key **`camera_palette: [260, 444]`** (fork e872940a2): every block in the range with the camera's
  projection (z = w - 4 here) gets the camera's clip-space eye transform; the palette is looked up in the whole
  bank (`camera_slots_read_directly` hides indexed slots). Checked on the OpenXR Simulator: Sora stands on the
  platform at 0 and 25 degrees.
- **World scale:** Sora ~150 units tall (390 px of 720 at w = 299, projection y 2.246) -> ~100 units/m:
  **eye_baseline 6.4**. (In the simulator he looks small: the headset renders 120 x 109 degrees with the 60 FPS
  reprojection margin against the game's 77 x 48.)
- **GS-projected effects:** `b7585fdcc1fb5ad9` (light beams, sparkles) projects with a PS2 GS-style pixel
  projection in `c[256..259]` and converts to NDC with `c[0..2]` (`c[0]` = 1/640, 1/360, 640, 360). Taken as a
  camera draw it vanished; `require_rigid_camera: true` rejects its block and `preprojected_programs` draws it
  through the camera's eye transform: the Dive's light beam turns with the world.
- **HUD (unverified):** the 2D layer is matrix-less screen-pixel draws (`c[0]` scaling): font `b49181469f73967f`
  (256x128), text box `16ac04cbcbe66dac` (1024x1024): `passthrough_hud` + `hud_programs`. Captions in the Dive
  ("Power sleeps within you.") were full-view before; not yet seen with the rule. `e44e6d596e281ee5` (opaque,
  1024x1024 texture, into the scene) is not identified; kept out of the list.

## Open

- **Need a gameplay savestate with the HUD on screen** (command menu, HP): scripted input did not get Sora past
  the first pedestal (X / Triangle / Circle did nothing there).
- The step for >60 FPS; Re:Chain of Memories (`recom.self`, community 60 FPS patch exists) and the launcher's
  menus in the headset.
