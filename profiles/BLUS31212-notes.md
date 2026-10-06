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

## Frame rate: unlocked, real time at any rate (2026-10-02, fork 1b068732b)

- The frame limiter `0x36830` (called every frame) stores the step `0x20d100c` = vblanks since the last frame x
  `[0x20d1004]` (set once to 1.0 by `0x36038`), i.e. each vblank counts as 1/60 s, then waits for
  `[0x20d1014] + 1` vblanks (1 = 30 FPS). The step is read in ~330 places. The community 60 FPS patch
  (`li r3, 0` at `0x36870`) removes the wait: right at 60 Hz, 1.5x / 2x fast at 90 / 120 (measured 5x on one object).
- **Patch "Unlocked frame rate (VR)" v2.0** (`bin/patches/BLUS31212_patch.yml`, copy in `vr-non-working/patches/`):
  the community `li r3, 0`, plus `0x3686c` `lfs f2, 0x102c(r3)` (the factor now comes from `0x20d102c`) and the
  word `0x20d102c` = 1.0 at load. `0x20d102c` is padding: no code builds its address (`tools/re/absrange.py`), and
  PPU read/write watches over a minute of play saw no access. The profile's new key
  `game_vblank_frames_f32: ["0x20d102c"]` keeps it at 60 / vblank rate every frame (fork 0e59c7967). Without the
  profile it stays 1.0: the community patch.
- **Verified** from a savestate made on the patched disc boot, recompiler, Vblank 60/72/90/120
  (`tools/re/kh_rt.sh kh1 RATE TAG native`, `tools/re/rthist.py`): ~2000-2300 world positions move at x1.0 their
  60 Hz speed at each rate. The opening movie stalls at 90 Hz ("waiting for a consumer"), as Killzone HD's:
  `video_vblank_rate: 60` in the profile (the step word follows: 1.0 while the movie plays).
- Profile `max_fps 0`, `default_fps 0` (headset rate). **VR at 300%: 120 Hz sustained** (Dive, 0% late, RSX thread
  1.3 ms).
- Savestate `vrtest_kh1_dive` (= `_1_2`): made on the patched disc boot, so it has the v2 code (patches are not
  re-applied to savestates).
- The title's cursor starts on New Game (it was on Load once, after backing out of the Load menu).

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

## Headset pass, 2026-10-03 (OpenXR Simulator, multiview build)

- **HUD rule checked on the Dive's 2D layer:** the captions ("If you give it form...", "Is this the power you
  seek?") and the pedestal's Yes/No box are in the HUD box in both eyes, beside Sora as in flat
  (`evidence/kh/2026-10-03/kh1_*`).
- Cutscene close-ups use a telephoto game camera: at the headset's FOV the same shot shows Sora small and far away.
- **Getting to the gameplay HUD (for a savestate):** from `vrtest_kh1_dive` with `tools/re/drive.sh`, 600 ms presses:
  `I 2500` (walk; the pedestals rise), four `X`, `I 2100` (up to the sword's pedestal), `I+C 900` (jump onto it:
  "The power of the warrior..."), `X` x3 (Yes: Sora stands on it facing the centre, the staff ahead-left, the
  shield ahead-right). The second pedestal defeated blind steering: the manual camera swings after each jump
  (`I+J 1500` then a split jump `I+J+C 450` / `I+C 500` ends beside the staff's pedestal; `J+C`, `L+C`, `I+L+C`
  from there missed). Next try: small steps with a screenshot each, or read Sora's position from memory.

## Open

- **Need a gameplay savestate with the HUD on screen** (command menu, HP): the second pedestal (above).
- The step for >60 FPS; Re:Chain of Memories (`recom.self`, community 60 FPS patch exists) and the launcher's
  menus in the headset.

## Fixed 2026-10-05: opening video head-locked, stray 3D background (fork e3b302013)

From `BLUS31212_1_3` (difficulty select): Cross x4 (Final Mix, Auto camera, vibration On, Proceed Yes). The logos
and the opening movie are drawn by `16ac04cbcbe66dac` (a `hud_programs` entry, so boxed) from the movie frame
copied into a 1280x720 target, after 9 camera draws of the Dive platform the game renders behind it (inspector,
draws 1-9 `c2a35ae334af037a`). New `screen_frame_draws: [{16ac04cbcbe66dac, 1280x720}]`: the movie frames go whole
on the fixed screen (no platform behind; world-fixed at pitch 15 / roll 10); the Dive gameplay after it is 3D
(3 minutes of shots). Evidence `evidence/kh-movie-2026-10-05/`. Seen, not raised: a thin grey line above the
fixed screen on the new-game menus.

Was (Matt):

Matt's state `BLUS31212_1_3` is at the main menu. Starting the game plays a video that follows the head instead
of staying fixed in place, and behind it a 3D background is drawn that should not be visible (flat shows only
the video). Not investigated yet. Likely the same shape as Dante's Inferno's intro movie: a scene rendered
behind a full-screen movie draw makes the frame count as 3D; first try `screen_frame_draws` with the movie
draw's program, and find what the background is (hidden in flat by the opaque video, or a pass flat never shows).

## Fixed 2026-10-05: world moved with head pitch and roll (fork 57a6069d0)

Cause: KH's scene viewport has a positive y scale (log `VR viewport: scale 1.0000 x 1.0000`; SEGA Rally's is
`1 x -1`), so its NDC +Y is screen-down and the head pose went into the clip basis with y unflipped: pitch and roll
inverted, yaw right. Measured on the simulator against the compositor-fixed pause image (Matt's state loads
paused; Start unpauses): at pitch +15 the pause screen moved down 72 px and the world up 60 px; roll turned them
opposite ways. `RPCS3_OPENXR_FLIP_Y=1` fixed it; new profile key `view_y_down: true` does the same for this game
(`BLUS31212.kingdom.json`, and KH 2.5's `BLUS31460.kingdom2.json`: same fault, same fix). Pose checks after:
`BLUS31212_1_4` and `vrtest_kh1_dive` (Sora, platform and pillar move together and the right way), KH 2.5
`vrtest_kh2_twilight`. The generator writes the key (KH 2.5: 12040 of 12040 scene draws y-down).

Was (Matt):

Matt's state `BLUS31212_1_4`: everywhere in that scene, looking up or down or tilting the head moves the world;
turning left or right is fine. Not investigated yet. Yaw-only correctness suggests the head rotation is
applied with the wrong axis convention or an extra/missing camera rotation about the view's horizontal axis
(e.g. the game camera is pitched and the head pose is composed in world rather than view space, or the
`camera_palette` bone matrices get only part of the rotation). First check on the simulator with
`simpose.py 0 10 0` and `simpose.py 0 0 15` against straight ahead, and compare the world with the HUD box.

## 2026-10-06 (Matt: the whole world moves as if the camera stick were used, looking up or down)

Rechecked on the simulator from `BLUS31212_1_4`, with head position as well as rotation:
- **Live play:** with `view_y_down` the world stays put at pitch +-15/20, yaw 20 and roll; 2 cm head moves up, forward
  and sideways shift it only slightly (right). Before the fix, looking up 15 degrees moved the world up in view instead
  of down, so it swung twice the head angle, which looks like the camera being steered. The flat game camera also sits
  low after unpausing this state (`khs_sheet.png`).
- **Pause (in play):** the game stops drawing 3D and re-shows the last frame plus the PAUSE text. That frame was shown in
  the headset view with the current pose, so the world followed the head on every axis (`khy_sheet.png`). Fixed with
  `frames_without_3d_as_screen: true` (fork 6c2b50308, also KH 2.5, which had the same: `kh2p` before, `kh2q` after):
  the paused frame goes on the world-fixed screen; play is unchanged (`khw_sheet.png`). Evidence
  `evidence/kh-pause-2026-10-06/`.
