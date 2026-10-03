# Asura's Wrath (BLUS30721, disc 01.00)

Added 2026-10-01. Profile `bin/vr_profiles/BLUS30721.json` (generated in Episode 1's space battle QTE), copy in
`rpcs3/vr-non-working/`. Desktop only. The disc installs game data at first boot and needs a save file (answer Yes).

## Frame rate

- Community patches enabled in `patch_config.yml`: **Unlock FPS** (Whatcookie: frame rate = half the vblank rate),
  **Disable Motion Blur**, **Disable Depth of Field** (both bad in VR).
- At Vblank 180: 90 FPS in Episode 1, flat and desktop stereo. **Real-time:** 643 f32 and 150 f64 clocks at 1.0x over
  12 s at 90 FPS. The patch notes warn that some button-mashing QTEs are tied to the frame rate (fine at 60, hard
  at 120+): not tested at 90.
- Profile `max_fps 0`, `default_fps 0`, `vblanks_per_frame 2` (headset 90 Hz -> vblank 180 -> 90 FPS).

## VR profile (generated)

`row_vectors c[0]` (100% of depth-tested draws), camera position `c[4]` (722 of 8272 eye points: weak), HUD
`c[200]` (`column_vectors_xyw` candidate), near 5 units -> 50 units/m (`eye_baseline` 3.2, unchecked). Desktop stereo
matches; yaw-25 audit in the opening turns coherently. Cinematic bars in QTE/cutscene sections are drawn bars (the
viewport is full 1280x720).

## Open

- QTE mashing at 90; on-foot combat sections; HUD (QTE prompts) placement in the headset; world scale.
- Savestates need `Savestate > Compatible Savestate Mode` (otherwise "failed to lock SPU threads"): set it only while saving.
  Regression state `vrtest_asura_space` (Episode 1 space battle): **120 Hz sustained** at 300% (Vblank 240: 119.6 FPS,
  no late frames; 2026-10-01, `evidence/vrtest/2026-10-01-1445`).

## 2026-10-01: first headset run (Matt, 90 Hz)

- Works well.
- To do: in-engine cutscenes show a 16:9 box with black letterbox bars. Hide the box background and the bars in VR,
  keeping the 3D world and the HUD elements (subtitles, prompts). The bars are drawn by the game (full 1280x720
  viewport); find their programs with probe `hide=` / `why=` in a cutscene, then `hidden_draws`.

## 2026-10-01 night: letterbox not started

- Tried to reach an in-engine cutscene from the disc: the title's EPISODE MENU ("Continue previous game") does not
  react to scripted Cross or Start; NEW GAME would overwrite Matt's save (`BLUS30721-BCSAVEDATA`, 18:23), so stopped.
  Next: a savestate from Matt at a cutscene with bars, then probe `hide=`/`why=` for the bar and background draws.

## 2026-10-01 late: letterbox bars and the grey 16:9 box removed

Matt's savestate `vrtest_asura_matt_letterbox` (= `BLUS30721_1_1`, the title screen with the cinematic bars). On the
OpenXR Simulator with an inspector capture (`f1860`):
- **Bars:** two untextured draws of `fc13d36fbccec49a` (vertex colour, 30 vertices, HUD block `c[200]` scale
  ±6.58e-5, translation ±(1,-1)), one per bar. Hidden with `hidden_draws` (texture `0x0`). The same program is a
  generic coloured quad, so a fade or a menu panel drawn with it would be hidden too: watch for missing fades.
- **Grey box:** not a draw of its own. The full-screen pass `5c313870ebfa5cd0` (scene `0xcaf90000` -> `0xcb6c0000`)
  is the game's world shader with `c[200..203]` as its world matrix, identity there, so it read as a HUD draw and
  was boxed (probe `why=5c313870ebfa5cd0`: `box 1`). Only the HUD box got this frame's image; outside it the target
  kept older pixels, a slightly different shade. `screen_space.hud_skips_passes: true` leaves draws that sample a
  colour render target as drawn.
- Checked: the title (bars and rectangle gone, text kept, head straight and turned) and the Episode 1 space battle
  (reticle and "Rapid Fire" text still in the HUD box). Evidence: `tools/re/asl_m1.png` (before), `asl_m5.png` (after).
- Not seen yet: an in-engine cutscene during gameplay (Matt's report); the bars there should be the same program.

## 2026-10-02: Matt's headset run, to do (not started)

- The short intro video after starting the game is tied to the head.
- Savestate `BLUS30721_1_5` (13:01): shadows on the main characters move across them when the headset turns;
  in-game TV screens show misaligned footage that turns with the head (they should be fixed 2D videos in each
  screen).
- Plan and leads: `6-wip-games.md` > Asura's Wrath.

## 2026-10-02 afternoon (fork 7858b2956)

- Intro video: `screen_frame_draws` with the movie draw `487364b5ccf9cbc2` (1280x720).
- TV screens: `game_camera_aspects: [1.7647]` (new key): the 720/408 feed cameras keep the game camera.
- Character shadows: not reproduced (audit through the `_1_5` cutscene). See `6-wip-games.md`.

## 2026-10-03: character shadows fixed (fork 9135d376d)

Matt's savestate `BLUS30721_1_6` (hard link `vrtest_asura_matt_shadows`): the space cutscene ("The Brahmastra? But
why?"). The bug shows in the first 10 seconds: Asura's red top goes dark and light again as the head turns.
- **Cause.** Per character, the game renders a 512x512 shadow map (`54e8142ea414fea1`, viewport 502x256 or 502x128
  at `0xcd6b2000`), then a screen-space shadow mask: `07d7202eb4af1d79` draws a 36-vertex box with the camera
  `c[0..3]` into `0xc0840000` / `0xc0100000`. Its fragment program reads the scene depth `0xcabf0000` as
  Z24-in-RGBA8 and maps (screen position from `tc0`, depth) into the shadow map with fragment constants fc5-fc11
  (16 PCF taps). The characters (`76c6f060eff733e8`) sample the mask at their screen position. In the headset the
  position and depth are the eye's but the constants are the game's, so the lookup slid with the head (the headset
  FOV moved it even looking straight). Rewriting constants can't fix it: with head rotation the rebuild's divisor
  would depend on x and y.
- **Fix.** New profile key `depth_remap_programs: ["07d7202eb4af1d79"]`. The fragment shader maps the eye's (NDC,
  depth) at each pixel to the game's before the program reads them (each eye's matrix follows its vertex constants).
- **Checked** on the simulator with a 40-degree yaw wobble (scratch `asura_simburst.sh`, 40 s from launch): the
  characters' shading stays constant across the sweep (before: Asura's top darkened at some yaws). Matt: "it all
  looks good to me". Evidence: `evidence/asura/2026-10-03-shadows-before.png` (Matt's sheet: bottom row),
  `-before-dense.png` and `-after-dense.png` (left eye, every 2nd capture through the sweep).
- The 2026-10-02 rotation audit of `_1_5` found no shadow map in the frames it checked; `_1_6`'s space cutscene
  renders one per character.

## 2026-10-03: missing objects and pop-in fixed: culling patch (fork 989c62599)

Matt's savestate `BLUS30721_1_8` (hard link `vrtest_asura_matt_culling`): the palace cutscene ("General Asura, the
Emperor summons you"). Loads of objects missing or popping in when the head turns; distant central objects popping in
as the camera moves closer.
- **Cause.** Unreal Engine 3 frustum culling with the game's camera, and the cutscene cameras are narrow: 22.6 to 39.6
  degrees across (Px 5.0 and 2.78; the 39.6 one is a 50 mm lens on 36 mm film, tan = 0.36). With the head turned 35
  degrees the whole palace was culled (pink sky); looking straight, distant structures above and ahead of the framed
  characters were outside the game's view and popped in as the camera tilted.
- **Found.** The renderer's cached view constants at `0x01a5a5b0` (camera-relative view-projection, then the view origin
  and its negation); a PPU write watch there gave the shader-parameter setter (`0x2216ac`, reading `View + 0x1d0`).
  `GetViewFrustumBounds` is `0x1048a0` (DELTA^2 at `0x104894`; Empty(6), near plane from column 2 if bUseNearPlane,
  then left/right/top/bottom from columns 0/1 +- column 3, far, Init `0x1042f0`), found as the call with
  `r3 = r22 + 0x380`, `r4 = r22 + 0x270`, `li r5, 0` at `0x662aec` (the scene view constructor). Other callers build
  light and shadow frustums (`0x14e678`, `0x6a17e0` ... `0x6a8224`).
- **Proved live** under the interpreter (`RPCS3_VR_POKE`): skipping the four side planes brought the palace back.
- **Patch** `bin/patches/BLUS30721_patch.yml` *Wider view culling (VR)* (`tools/re/asura_cull.py` writes the lines):
  the call at `0x662aec` goes to a cave written over the radial blur function `0x679ff8` (its only call `0x67a908`
  becomes a nop, as the community *Disable Motion Blur* does). The cave passes a copy of the view-projection with clip x
  and y scaled by min(1, T / Px), T = 1 / tan(half angle): configurable *Culling* 180 (default, T = 0: everything
  ahead), 160, 140, 120, or the game's own. Rendering, LOD and the near/far planes keep the game's matrices. On by
  default, and `Apply To Savestates: true` (new fork key) so the 1_8 savestate gets it.
- **Checked** on the simulator (LLVM, Matt's config at 450%): with a 40-degree wobble the courtyard and palace are
  complete; head straight through the hall, the throne structure, lanterns and left columns that popped in without the
  patch are there from the start. Frame rate at Vblank 180 (90 FPS target): 89-90 FPS with and without the patch,
  1% lows 80-86 against 83-86. A first version without side planes at all (everything around, behind too) cost up
  to 10% (81-89 FPS, 1% lows 67-74) and was replaced.
- **Open: a black disc.** In the hall, the large golden disc above the throne turns into a black silhouette (its light
  orb still lit) once the camera tilts up past it (`evidence/asura/2026-10-03-culling-hall-black-disc.png`). It is above
  the game camera's view at that point; without the patch it is not drawn at all then, so the game's own look there is
  unknown. Not the character shadow mask (hiding `07d7202e` leaves it). Next: inspector captures at the golden and the
  black moment, compare the disc draw's textures and constants.
- Evidence: `evidence/asura/2026-10-03-culling-before.png`, `-culling-after.png`, `-culling-hall-popin-patch-vs-none.png`.

## 2026-10-03 evening: disc black or gold with head pitch (fork 002880a97, reverted in 53125801a)

Matt, on `BLUS30721_1_8`: the golden disc above the throne is black or gold depending on the vertical HMD angle, and
the blood under a man dying on the stairs shows or hides with the horizontal angle.
- **Disc.** Its gold is the orb's point light, an additive pass (`defd351b25230540`; another light pass is
  `e121e0f142a5b6b2`). Both use the RSX depth-bounds test with the light's depth range in the game camera's window
  depth (e.g. 0.9971-0.9978). The depth buffer holds the eye's depth, which changes with the head's rotation, so the
  disc's pixels left or entered the range as the head pitched. New profile key `disable_depth_bounds: true` turned
  the test off while VR renders. Simulator: in the throne shot the disc stayed gold when looking up (pitch +0.2, +0.3),
  where it went black before. **Matt, headset: no fix; reverted (key and `VKDraw.cpp` hook removed). Disc open.**
- Ruled out on the way: occlusion queries (forcing every report visible changed nothing), texture streaming (textures
  one mip lower in some frames, but not the cause), the per-object constants, the shadow mask's `defd` pass alone.
- **Still dark, consistently:** in the carpet shot before the throne (31-33 s of the savestate) the disc is black at
  every head angle; at 31.3 s Asura's shadow mask (`7d7202eb`, blended into the scene) darkens it, after that it stays
  black with the mask hidden too. Probably the cutscene's light being off for that shot (the game camera never shows
  the disc there); not confirmed.
- **Blood:** not confirmed. The second bounded light pass (`e121e0f1`) lights the dying man's mesh, so it may be the
  same cause; the simulator window shrank (1904x61 screenshots), so the last captures were too poor to judge. Matt
  to check in the headset.
- Note for scripts: the simulator's `head_pose_command.json` takes radians (the playbook says so); earlier pose
  sweeps in this session used degrees by mistake.

## 2026-10-03 late: world scale (fork 53125801a)

Matt, headset: the world looked too big at World Scale 100%; 80% looked right. World Scale divides the eye separation
(`eye_baseline` x 100 / World Scale, for the eye offset, the camera-position slot and head translation), so 80% is
`eye_baseline` x 1.25: 3.1984 -> 3.998 (about 12.5 units per metre at a 64 mm IPD). World Scale 100% now looks like
the old 80%; Matt's per-game config (`config_BLUS30721.yml`, World Scale 80) set back to 100.

## 2026-10-04: community patches bundled (fork 9de7502a)

Matt's vr8 release test: slow, graphics wrong. Dev had the community *Unlock FPS*, *Disable Motion Blur* and *Disable
Depth of Field* on in `patch_config.yml`; the package has no community `patch.yml`, so only *Wider view culling (VR)*
applied (config otherwise the same as dev but Resolution Scale and Vblank NTSC Fixup; the online config database only
sets Anisotropic Filter Override 0). Copies of the three, byte-identical, are now in `BLUS30721_patch.yml` as
*Unlock FPS (VR)*, *Disable Motion Blur (VR)*, *Disable Depth of Field (VR)*: on by default, also for savestates.
From the extracted zip (no `patch.yml`, default config, simulator) all four VR patches apply; 30.9 FPS at Vblank 60,
59.8 at Vblank 180 (Unlock FPS: at most half the vblank; the profile's `vblanks_per_frame 2` gives 180 on a 90 Hz
headset).
