# Killzone HD (BCES01743 v01.00, Europe disc)

Added 2026-09-30. Profile `bin/vr_profiles/BCES01743.json` (generated), patch `bin/patches/BCES01743_patch.yml`
(copy: `profiles/BCES01743-patch.yml`), config `custom_configs/config_BCES01743.yml`. Evidence `evidence/killzone/`.
Desktop-verified only; not yet run in the headset.

## Config

- **Write Color Buffers and Read Color Buffers both on.** Without them the menus work but the 3D world in a
  level is black (HUD only). WCB alone is not enough (`evidence/killzone/black-world-wcb-only.png`). The game
  reads its downsampled 640x360 frame (in main memory, `0x304f1000`/`0x30410000`) back, probably for exposure.
- Vblank Rate 90, Resolution Scale 300 (88-90 FPS stereo on the headset path), VR on.

## Frame rate: patch "Frame rate 90 FPS (set Vblank Rate 90)"

The game loop (`0x21c0a8`) reads a millisecond clock (`0x1cc20`), multiplies it by the double 0.03 to get 30 Hz
ticks, spins until at least one tick has passed, and stores the tick count (clamped to object+0x74 = 4) at
+0x68. Each tick is one simulation step of object+0x54 (1/30 s) scaled by object+0x58 (1.0), both set in two
constructors (`0x2125a4`, `0x2192f8`). The community 60 FPS patch (ZEROx, illusion) sets +0x58 to 0.5 and the
loop's constant to 0.06. The fork patch sets all four copies of 0.03 (`0x2124b0`, `0x2192c8`, `0x21c0a0`,
`0x21c180`) to fps/1000 and +0x58 to 30/fps. The step factor is one `lis`, so only its upper 16 bits: 0.33398 at
90 (+0.2%). Entries for 60/72/90/120; 90 on by default.

Measured at 90 Hz: 90 FPS in gameplay, and memclock over 12 s: 147 clock-like floats at 1.00x wall time.
Known from the community patch: some cutscene animations may play too fast; not checked.

## VR profile

Generated in gameplay (Helghast Assault, walking and looking around): `row_vectors`, camera `c[256, 258]`,
`require_rigid_camera` and `require_camera_aspect` (the camera block base varies per program), HUD `c[256]`
with `hud_skips_passes`, near plane 0.1 → metres, `eye_baseline` 0.064, no camera position. 87% of
depth-tested draws covered; the uncovered programs are the HUD and full-screen passes.

Checked on the desktop at 100%: stereo (`stereo-sbs.png`: HUD at zero disparity, both eyes consistent),
yaw 25 (`audit-yaw25.png`: world, gun, smoke and sky turn together, HUD fixed), pitch 35
(`audit-pitch35.png`: the sky fills the raised view, nothing head-locked).

## Driving it unattended

Keyboard pad from the template plus right stick (A/D/R/F). Boot, Return, then X five times (GAME > Campaign >
Helghast Assault > confirm > Templar), wait ~25 s, Return to skip the intro video. Gameplay starts in a trench
with tutorial prompts.

## Headset: menus and HUD text (2026-09-30, fork 44ef18bd2)

Matt's first headset runs: main menu black (some runs), in-game HUD text empty, pause menu without text until
the head moved back. Reproduced on the headset path with the SHOT hook (`hmd-pause-before.png`). Causes:

1. **Depth test with nothing to test against.** Every menu/HUD draw has depth test on, no depth buffer
   (`zeta 0`) and compare ALWAYS. The HUD box only sets z = w/2 for draws without depth test, so these kept
   their z while the box and head position changed W: text near the far plane was clipped. The renderer now
   counts a depth test only with a depth buffer and a compare other than ALWAYS.
2. **Runs differed.** Screen-space boxing waited for the game's first camera draw (`m_vr_proj_valid`), so the
   menu was full-view on a fresh boot and boxed once any 3D had been drawn. Boxing now starts with the first
   headset frame (all titles).
3. **White outside the box on the main menu** (`hmd-mainmenu-white-glow.png`): the menu's own video background
   is boxed; its glow pass downsamples the whole display buffer and adds it back, so the never-written outside
   of the box fed on itself to white. Profile `screen_space.clear_outside_box: true`. The shown-region clear
   also looked at surface A only; Killzone draws into surface B.

After: `hmd-mainmenu-after.png`, `hmd-hud-after.png`, `hmd-pause-after.png` (fresh boot, headset path).

## Intro movie black at 90 Hz (2026-09-30, fork 5146bc4c7)

After the Guerrilla splash the intro movie (started at ~0:30) never showed; X skipped to the menu. The log
repeats "cellVdec: Video au decode has been waiting for a consumer": the movie player (libsail) stops taking
decoded frames. Bisected with game-list launches and no screenshots: flat, VR off and the 90 FPS patch off still
stall; Vblank 60 plays; Write/Read Color Buffers are fine. My earlier runs "worked" only because the SHOT hook's
screenshot (a full GPU sync) every 4 s kept the player going. Profile `video_vblank_rate: 60`: the vblank drops
to 60 Hz while a decoder is open (intro, main menu background) and returns to 90 in gameplay (measured: 90 FPS).

## Headset report 2 (2026-09-30, fork 0ab5b780c)

1. HUD box ultrawide and 2. head-locked until the character select screen: until the game's first camera draw,
   frames went to the headset as the fixed-screen quad (head-locked, stretched), with the box already inside. The
   projection layer now starts with the first frame when rendering with the headset FOV (log: "Projection layer:
   game FOV 0.0 x 0.0" during the splash screens is expected).
3. Grey panel behind the in-game HUD: the film grain (40 tiles of a 128x128 noise texture, HUD matrix, HUD vertex
   program `4948caa7790a8473`) was boxed and lightened the box. Profile `screen_space.unboxed_draws`
   (`hmd-grain-before-after.png`: top boxed, bottom full view).

## Open

1. Headset: world scale, the gun's position, cutscene speed at 90; recheck menus and HUD after 44ef18bd2.
2. Performance in busier levels.
