# God of War Collection (BCES00800 v01.00, UK disc)

Added 2026-09-30. Profiles `bin/vr_profiles/BCES00800.json` (game selector), `BCES00800.gow1.json`,
`BCES00800.gow2.json`. No game patch. Config `custom_configs/config_BCES00800.yml`. Evidence `evidence/gow/`.
Desktop and headset-path (SteamVR running, SHOT hook) verified only; **not yet played in the headset.**

## Collection layout

`EBOOT.BIN` plays the Sony logo video and exitspawns `GAMESEL.self` (the game selector), which exitspawns
`GOW1.self` or `GOW2.self`. Executable hashes (v01.00): EBOOT `b7dc5a0b`, GAMESEL `6e8a6902`, GOW1 `62bdceaf`,
GOW2 `13f84cac`. The community patches in `patch.yml` are for v01.01 (US/EU) and do not apply to this disc.

The base profile `BCES00800.json` is needed even though the selector is 2D: the renderer for an exitspawned
executable is built while the title ID is still empty (`BootGame ... title_id=''`), so no profile resolves and
OpenXR would never be prepared. With a base profile the first boot prepares OpenXR and the instance survives
the switches (the ICO/SotC pattern). The base caps at 60 FPS (it has no speed fix).

## Performance (9800X3D + RTX 5090)

| | flat, vblank 60 | flat, vblank 90 | stereo, headset path, 100% |
|---|---|---|---|
| GoW1 (boat) | 60; RSX thread 24%, PPU 17% | 90; RSX 10-36% | 90 |
| GoW2 (Rhodes fight) | - | 90; RSX 45%, PPU main 100% | 90; RSX 58-70%, GPU 22% |

Both run at 90 in stereo with room to spare; GoW2's PPU main thread is the one to watch in busy fights.

## Frame rate: profile `game_fps_u32` (no patch)

The engine steps game logic by a fixed `dt = 1.0 / rate` per frame, `rate` an int in a timing struct (`[P+0]`,
initial 60, in the writable data segment): at vblank 90 the game ran 1.5x fast (game-time float `0x552290`:
0.98/s at 60, 1.45/s at 90; Kratos died within seconds of the boat fight). The dt site is the `fdivs` that the
community "Native PS3 Timing" patch hooks in v01.01:

- GOW1: `0x1c3ea0` `fdivs f0,f31,f0`; rate getter `0x1c3d68` reads `[toc-0x201c]` = `0x531dd0`.
- GOW2: `0x2b7528` `fdivs f0,f31,f0`; rate getter `0x2b7420` reads `0x5720f4`.

The profile lists that word in `game_fps_u32`, so the renderer writes round(fps) into it every frame and the
game follows any headset rate (`max_fps 0`). Log: `Game frame rate at 0x531dd0: 60 -> 90 FPS`.
Measured (memory dumps, `tools/re/rateratio.py`): GoW1 game time 0.98/s at 60 and 0.98/s at 90 with the fix;
GoW2 38 game-time floats 1.45/s -> 0.99/s. Frame counters keep counting frames (1.49x), as they should.
Why dt is enough: the community patch caps logic by feeding a near-zero dt on extra frames, which only works if
dt drives all game logic. Still to check in the headset: animation and combat feel at 90.

## VR profile

Generated in gameplay, then edited. The engine transforms vertices into view space itself (the PS2 design):
`c[256..259]` is a **bare projection** in every draw and `c[260..263]` the object-to-view matrix, so the
projection block is the camera (`row_vectors`, `[256]`, 100% of depth-tested draws covered). No camera position.
Near plane 5.0 units, 50 units per metre: `eye_baseline` 3.2. Projection A: GoW1 1.9445, GoW2 1.4846 (stereo
separations 0.0243 and 0.0186).

**HUD: `screen_space.offaspect_projection` (new, fork).** The HUD uses the same slots with a 4:3 bare projection
(A 1.763, B 2.351; B/A 1.33 vs the scene's 1.78) and a view matrix at a fixed depth (z = -1128), no depth buffer
(programs `de0e2cc9`, `db938d0d`). Neither `bare_projection` (the scene is bare too) nor `depth_offset_projection`
(the offset is in the object matrix) separates it. The new flag boxes a bare projection whose square-pixel aspect
is not the output's; it does not refresh the FOV cache. Headset path only, like Blur's 3D HUD: on the desktop and
in the rotation audit the HUD still takes stereo and rotation (desktop SBS: HUD 26 px disparity). The generator now
writes the flag when every camera draw is a bare projection and 2+ draws without depth test are off-aspect bare
projections, and then no longer picks an orthographic block (it had picked `c[260]`, the HUD sprites' object
matrix, which would also box axis-aligned scene sprites).

`frames_without_3d_as_screen`: the intro videos and 2D menus go on the fixed screen (log "frames without camera
draws: shown as the fixed screen").

Checked: desktop stereo (both games, eyes consistent), yaw-25 audit on GoW1 (boat, enemies, rain and fog turn
together, nothing head-locked), headset path SBS captures (HUD in the box, 90 FPS). Not checked: pitch audit,
pause menu, in-game cutscenes.

## Known issues

- **5% black border.** The scene renders into 1216x684 and the final pass (`3421a0ec`, positions from vertex
  data) insets it in the 1280x720 display, so each eye has black edges and the world is about 5% smaller than the
  head rotation (expected k about 1.05). Lead: a per-video-mode layout table at GOW1 `0x157918` (`li 0x4c0`,
  `li 0x2ac`, alongside 1080/576/480 entries). Measure k with the audit FOV route before patching.
- **The collection switch crashed once** (1 of ~8 boots): `vkCreateSwapchainKHR` jumped into an unloaded module
  while the renderer was rebuilt for GOW1 (`vk::swapchain_WSI::init`, VKGSRender constructor). Not reproduced.
- **Savestates**: restoring one and restarting from a checkpoint killed the RSX thread (Dead FIFO). Boot fresh.

## Driving it unattended

`tools/re/gow_boot.ps1 [-Game2] [-Headset] [-Probe render=1] [-Audit 25] [-TitleOnly]`: boots, waits for the
selector and the executable switch in the log, starts a new game. The intro video (~90 s GoW1, ~2.5 min GoW2)
cannot be skipped. GoW1's boat enemies kill an idle Kratos in under a minute: restart with X (the checkpoint load
takes ~10 s before the screen changes). Keyboard pad: template plus right stick; temporary, deleted after the session.

## 2026-10-01: first headset run, GoW 1 (Matt, 90 Hz)

- Performance good.
- Main menu looks wrong: 2D and 3D elements combined at the wrong depth.
- In gameplay the main character has blurred edges. Savestate: `bin/savestates/BCES00800/vrtest_gow1_matt_blur.SAVESTAT.zst`
  (hard link to `BCES00800_1_2`, 18:14). Reproduce on the OpenXR Simulator with a head sweep from it.

## 2026-10-01 evening: Kratos's blurred edges fixed

- The MSAA resolve (vertex program `c4882b95379447a8`, draw 322: scene copy from the 2432x684 double-width buffer)
  averages two samples one pixel apart; the offsets are texture-coordinate fractions in `c[466..467]`, so at 300% they
  spanned ~3 pixels and left a light halo along every silhouette. `resolution_scaled_constants` [`c4882b95379447a8`,
  466, 467] in `BCES00800.gow1.json` (as Ridge Racer 7): halo gone on Matt's savestate (desktop stereo, 300%).
- Main menu fixed (fork, new key `screen_frame_draws`): the menu is Kratos in 3D in front of a 2D fire background
  with the logo; the headset view pulled them apart. A frame with the logo draw (`a3b1455d9ebdd381`, 1024x256) goes
  whole on the fixed screen. Simulator: menu world-fixed, gameplay headset view. Open: GoW 2 (same resolve and menu?).

## 2026-10-02: Matt's second headset run, fixed on the OpenXR Simulator (fork 116138201)

- **Game selector intro "not visible or at a very weird angle":** the collection's intro (Kratos's blades sweeping
  across the logo, before `GAMESEL.self`) is a real-time 3D animation through a camera (`c[256]`), not a movie, so
  the headset view turned it with the head. The selector profile lists its four programs as `screen_frame_draws`
  (`c760d3b1` 1920x1200 background, `b08e6382` 512x512 blades, `a35ef6b2` 256x256, `195bc177` 1920x1080): it now
  plays as a screen in front (checked straight and turned 25 degrees).
- **GoW 1 Power Up screen flickering between the fixed HUD and the face:** the menu frames switched between "no
  camera draws" (fixed screen) and "camera draws" (headset view) every ~3 frames at 90 Hz, ~180 switches in 6 s;
  the four captured menu frames had identical draw lists, so the camera classification of some menu draw changes
  frame to frame. Fixed with `screen_frame_draws` `{a3b1455d9ebdd381, 512x512}` (a menu-art draw not seen in
  gameplay, where `a3b1455d` only draws 4x4 and 128x16): 7 switches in 6 s (the opening animation and the close), a
  steady world-fixed screen in between. A generic exit hysteresis (3 frames with 3D to leave the screen) did not fix
  it (the pattern is 3 on / 3 off) and was reverted. Risk: if gameplay ever draws `a3b1455d` with a 512x512 texture
  (a boss bar?), that frame goes on the screen.
- **Characters very small:** `eye_baseline` 3.20128 came from the generator's near-plane rule (near 5 units = 0.1 m,
  50 units/m). Measured on Kratos in `vrtest_gow1_matt_blur` from RPCS3's own eye images (RTDUMP of `0xc0400000`,
  3840x2160 per eye): with `eye_baseline` ~0 every region sits at R-L -615.1 px (the frusta's offset), with 3.2 Kratos
  is 56.9 px nearer, so at ~1489 px per tangent unit he is 84 units away; his head (42 px) and shoulder-to-belt
  (80 px) give 13-14 units per metre. **`eye_baseline` 0.864** (0.064 m x 13.5): Kratos's disparity became 15.2 px
  (predicted 15.4). The world in the headset should be ~3.7x larger than before. GoW 2 (same engine, also 3.20128)
  not measured yet.

## 2026-10-02: God of War II checked (OpenXR Simulator)

- Booted with `tools/re/gow_boot.ps1 -Game2` (new game, intro cutscene, Rhodes). Savestate
  `bin/savestates/BCES00800/vrtest_gow2_rhodes.SAVESTAT.zst` (= `_1_3`; the first three Ctrl+S attempts failed with
  "failed to lock SPU threads execution" mid-fight, the fourth worked). Loaded unattended, Kratos dies in the fight
  after ~30 s: "Restart from last checkpoint" (the death menu is on the fixed screen).
- 90 FPS flat at Vblank 90 in the fight.
- **Power Up screen flickered as GoW 1's** (260 view switches in 6 s): same fix, `screen_frame_draws`
  `{a3b1455d9ebdd381, 512x512}` (not drawn in three gameplay frames) -> 7 switches, world-fixed, gameplay returns to
  the headset view with the HUD boxed.
- **World scale:** `eye_baseline` 3.20128 -> 0.864 as GoW 1. With 3.2, Kratos's disparity against the frusta's
  offset was 57.6 px (GoW 1: 56.9 px), assuming the same zero-separation offset (-615 px, same headset FOV): the same
  camera distance, so GoW 1's measured 13.5 units/m is taken for GoW 2 (not measured on his height).
