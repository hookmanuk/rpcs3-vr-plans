# Dante's Inferno (BLUS30405, disc 01.00)

Added 2026-10-01. Profile `bin/vr_profiles/BLUS30405.json` (generated in Acre, the first level; frame-rate field
added), copy in `rpcs3/vr-non-working/`. No patch. Desktop only. The community *Unlock FPS* exists only for update
01.04 (not installed: we use the disc version); its *Aspect Ratio* patch covers 01.00.

## Boot

Logos (X/Start), a PSN notice (X), main menu: Start Game, video calibration (X), difficulty (X), an unskippable
intro movie (~90 s), then Acre with enemies. Savestate `bin/savestates/BLUS30405/di_acre.SAVESTAT.zst` (first
fight). Executable `PPU-46bf3c2b...`; decrypted copy `tools/re/elf/BLUS30405.elf` (`RPCS3_DUMP_ELF`).

## Frame rate

- Native 60 (flips every vblank). Flat at Vblank 180: 180 FPS in Acre, CPU ~30%. Desktop stereo at Vblank 90: 90.
- **Frame-locked above 60:** the frame function `0x9408c8` (TOC `0xf65600`) counts whole frames of the interval
  `[0x119ecb4]` (float ms, 16.6834 = 59.94 Hz) in the measured elapsed time, at least one and at most 5 a frame,
  and steps the game clock (`0x11c3d88`, int64 microseconds; per-frame step `0x11c3d30` = frames x interval, times
  the time scale `0x11c3d64`). At 180 FPS game time ran 2.86x. Poking `0x11c3d30` does nothing (rewritten every
  frame); setting the interval does: 1000/180 ms gave 0.96x at 180.
- New profile key **`game_frame_ms_f32`** (fork): `["0x119ecb4"]` gets 1000/fps. At 90 FPS game time runs 0.99x
  real time over 10 s (native 60: 0.98x). `max_fps 0`.
- The 01.04 patch also gates UI animation to 60 Hz because menus lost their text at high frame rates; at 90 the
  pause menu (Upgrade tab) renders correctly. Not checked: UI animation speed, other menus, QTEs.

## VR profile (generated)

`row_vectors`, camera `[256, 260, 4, 0, 8]` (most scene programs: world `c[256]` + view-projection `c[260]`;
others a VP in `c[256]` or `c[8]`), `camera_slots_read_directly`, camera position `c[466]` (614 of 7773 eye
points: weak; removing it changed nothing visible), HUD `c[0]`, near 0.35 (taken as metres, `eye_baseline`
0.064, unchecked), `require_rigid_camera` with `nonrigid_camera_blocks [256, 260]`.

- **HUD missing in stereo** (both eyes, also with VR on the desktop): the HUD program `ef40b68dd8b117df` keeps UV
  and colour parameters in `c[4..7]`, which `c[4]`, a camera block for other programs, read as a sheared
  perspective block; the eye transform wrecked them. `require_rigid_camera` fixes it; the generator now writes it
  (a depth-less draw whose first matching block has |cos| > 0.5 counts as stray data).
- Stereo in combat, the yaw-25 audit and the pause menu are right (`evidence/dante/`).
- Headset view (`-FakeHmd 100`): HUD boxed; the sky is a screen-space card drawn as a quad, so it shows as a
  floating rectangle in the wide view and leaves black sky when turning. Geometry beyond the game camera's
  frustum is culled (black areas when turning), as in other games.

## 2026-10-01: sky in the headset view (not fixed)

The sky ends at the edge of the game's frustum (a bounded "card", `evidence/dante/fakehmd100-sky-card.png`). Not the
full-screen composite `f7863935bce5eba2` (hidden: no change) and not `2a5dce5dcdcf3e11` (a small sky/environment
render into a 320x320 target; kept on the game camera: no change). The sky is probably world geometry the main
shader draws, sized to the game's view. Next: hide the scene programs one by one (`hide=`) to find the sky mesh.

## Open

- Headset run; world scale; sky card; UI animation speed at 90; later levels.

## 2026-10-01: first headset run (Matt, 90 Hz)

- Gameplay performs really well.
- Splash screen, menus and the intro movie are tied to the head.
- Needs culling/FOV improvements: objects that the wider headset view should show are culled (the game culls to its
  own frustum). Lead: find the culling frustum or FOV the game uses and widen it with a patch (as ICO's "Wider view
  (VR culling)").

## 2026-10-02: intro movie after Start Game still head-locked: fixed

The ~90 s intro movie (after Start Game, calibration, difficulty) is drawn over the first level, which the game
already renders behind it (Acre's camera draws every frame), so the frame counted as 3D and the full-view movie quad
(`2f7541c34fd0c5d7`, Y plane 1280x736 and chroma 768x384 in main memory) followed the head. Profile:
`"screen_frame_draws": [ { "program": "2f7541c34fd0c5d7", "texture": "1280x736" } ]`: any frame with the movie draw
goes on the fixed screen. Checked on the OpenXR Simulator from the disc (head straight and turned 25 degrees: the
movie moves as a world-fixed screen; after the movie gameplay returns to the headset view, HUD boxed). Other FMVs
use the same player and should follow. No save data created.

## 2026-10-02: culling at the headset's wide view: "Wider view (VR culling)" patch

- The game projection is 61.9 x 37.3 degrees (tan 0.6 horizontal); the headset view is ~100 x 89, so objects at the
  edges were culled even looking straight ahead.
- Found live (pine + PPU write watch on the interpreter): the projection matrix (`-1.667, 2.963`, near 0.70, far 4096)
  at `0x135fb50`, built each frame from a camera record (`+0x1a4..0x1b8`: near, far, **fov 1.0808 rad
  horizontal**, aspect; copies at `0x11a1ad0`/`0x11a1cb0`) written by the perspective setter `0x420490`
  (`stfs f1, 0x1ac(r31)`), called from the camera update `0x452da0` (fov in f31, from a camera struct `+0x30`, through
  the vertical/horizontal FOV conversion `0x449738`); the matrix by `0x413b70` -> `0x609a60` (generic perspective).
- Patch (`vr-non-working/patches/BLUS30405_patch.yml`, copy in `bin/patches/`, enabled by default): `0x452f1c`
  `fmr f1,f31` -> `fadds f1,f31,f31` (FOV x2: 124 x 93 degrees). Camera position unchanged with and without (read
  live while toggling the code under the interpreter). Flat play would show a wide-angle view.
- OpenXR Simulator from the disc (`tools/re/dante_boot.ps1 -Headset`): straight ahead complete; yaw 40 degrees mostly
  filled (beyond 90 degrees off the game camera's axis stays black: no frustum covers it); looking up 20 degrees still
  black at the top (vertical 93 degrees is the narrow axis). A larger factor needs a code cave (a constant multiply).
- Cost: stereo at 300% (`vr1pct.sh`), 120 Hz sustained with and without (0% late); RSX thread 3.75 -> 4.09 ms at 90.
- Savestate with the patch: `vrtest_dante_acre_wide` (= `_1_1`; the regression entry now uses it).

## 2026-10-02: Matt's headset run, to do (not started)

- Savestate `BLUS30405_1_2` (13:09): attacking with Square and hitting enemies shakes the whole screen; very
  off-putting in VR. Disable the shake.
- Savestate `BLUS30405_1_3` (13:14): right at the start a tooltip banner shows at the bottom for ~2 s with no text.
  All text everywhere must be visible.
- Plan: `6-wip-games.md` > Dante's Inferno.

## 2026-10-02 afternoon: shake, tooltip, wider view 2.0 (fork e0a6d501e, 2aaf72b50, f4b730b01)

- Shake: patch "Disable camera shake (VR)": the camera modifier apply at `0x663d8` returns at once (Matt: shake gone).
- Tooltip text: `screen_space.hud_block_programs: [{ "program": "2f7541c34fd0c5d7", "block": 256 }]`.
- Wider view 2.0: the field of view at the setter call (`0x452f1c`, radians, 1.0808 = 61.9 degrees across in play)
  is multiplied by the dropdown scale and clamped to 170 degrees by code at `0x663e0` (`bl` from `0x452f1c`; r9, f0,
  f13 are dead there; the function restores LR from its stack frame). Default 2.75. Matt's savestate
  `BLUS30405_1_4` has it. Plan in `6-wip-games.md`.

## 2026-10-02 evening: Wider view 3.0, full detail at 170 degrees (simulator)

Matt (headset, Wider view 2.0 at 2.75): "the gfx are all corrupted, especially the people". Measured on the simulator
(inspector, character program `c015ac8e`, 10 draws): vertices ~13k at 1.0, 10.9k at 2.0, 6.9k at 2.5, ~2.2k at
2.75. Draws unchanged, so not a model LOD switch: triangles were being removed.

- **Cause: EDGE geometry culling (SPU).** The PPU fills an `EdgeGeomViewportInfo` template at `0x1342e00` (+0 scissor
  u16 x, y, w, h; +8 depth range; +0x10 the transposed view-projection; +0x50 viewport scales; +0x60 offsets; +0x70
  sample flavour) and copies it into each job (`0x5f6e10`..`0x5f6fac`, a ring at `[r27+0x125480]`). EDGE culls
  triangles that cover no pixel of that viewport. With the widened projection everything is 19x smaller on it (at
  2.75: tan(85)/tan(30.95)), so most character triangles covered no pixel: holes in the headset, where the image is
  shown at the normal scale. Setters: viewport `0x5ef390` (f1, f2 depth; r5 scales, r6 offsets), scissor `0x5ef250`
  (r3..r6), each a few instructions. (`0x1342e00` was the "render VP" in earlier notes: it is EDGE's culling VP.)
- **Fix:** both setters branch to code that multiplies the scales, offsets and scissor by 20 (the screen grows
  20x about the origin: the frustum and scissor tests are unchanged; the no-pixel test runs at the normal view's
  pixel size or finer). Scissor 1280 x 20 = 25600 fits its u16.
- **Effects (fire, torches):** a separate size metric `0x65e6c8` (from the scene walk `0x65eb24` and `0x65f1f8`):
  radius / (tan(cam+0x1ac / 2) x 1.5 x distance + c), clamped at 1024, compared with a per-type threshold (and stored
  at object +0x90). It reads the camera's stored (widened) FOV, so effects were culled as too small (`30e80c75`
  0-7 draws of 17-30). `0x65e8f0` now calls code that loads the FOV and divides it by the Scale.
- Dead ends, for the record: the view record ring (`0x696a50`: camera +0x40 view, +0 world, projection from
  +0x1ac) and the flare/billboard focal (`0x66a2d8`, `+0x78` of its object) do not drive detail; restoring +0x1ac
  after the setter's last rebuild (poke `0x452f44`) brought the effects back but not the characters; the plane
  builder's multipliers (`0x4202dc`) kept detail but barely widened culling.
- **Patch "Wider view (VR culling)" 3.0** (`bin/patches/BLUS30405_patch.yml`, copy in `vr-non-working/`): code in the
  dead shake-modifier body: FOV `0x663e0`, data `0x66400` Scale, `0x66404` 170 degrees, `0x66408`/`0x6640c` 20.0/20,
  viewport `0x66410`, scissor `0x6647c`, size metric `0x664b0`; branches at `0x5ef390`, `0x5ef250`, `0x65e8f0`,
  `0x452f1c`. Default Scale 2.75 (170 degrees); the dropdown no longer warns about detail.
- **Results (simulator, Acre):** at 2.75, `c015ac8e` 11.7-14.2k vertices (base 11.9-13.9k), `30e80c75` 15-37 draws
  (base 24-32), `2a5dce5d` 17 (base 14-17); more scene geometry than base (the wider frustum). Same from a disc boot
  on the recompiler. Head turned 45 degrees either way: characters whole, the view filled except a small wedge
  beyond ~85 degrees off the game camera's axis. Evidence `evidence/dante/wide3_*`.
- **Cost:** desktop stereo at 300% (`vr1pct.sh`): 120 FPS sustained, 0.00% late (old 2x patch: 120, 0.00%); 90:
  0.14% late. RSX thread 5.1 ms/frame at 120 (old: 4.7).
- New regression state `vrtest_dante_acre_v3` (disc boot with 3.0 at 2.75, Acre first fight); it replaces
  `vrtest_dante_acre_wide`.
- **Open:** the sun's lens flare shows at the normal FOV and not with the wide view (seen before 3.0 too; probably
  its visibility test, which uses the widened focal, `0x66a2d8`). Not checked in the headset by Matt yet.

## 2026-10-02 evening: torch glows followed the head (simulator)

Matt (headset, Wider view 3.0): orange lights that move when he turns his head, offset from the three wall torches.
They are the torch glow sprites, program `54fba8b442f9fa7f` (64/128/256 px textures, ~24 draws a frame, blended,
**depth test off**, into the scene target between camera draws). They came back with 3.0 (the size metric had culled
them at the wide FOV). The shader reads no camera block: position = vertex xy x `c[1].w`, z = `c[1].z`, w = `c[1].w`
(the light's clip z and w, set per draw), so the game projects each glow itself and the renderer drew it where the game
put it in its own view: fixed to the head. `preprojected_programs` re-projects such draws per eye (B^-1 x B_eye), but
only depth-tested ones (ICO's flame program also draws its pause menu). New entry form `{ "program": ..., "without_depth_test":
true }` (fork, opt-in per program); Dante's profile lists `54fba8b442f9fa7f` so. Simulator: glows on their torches at
yaw -0.25, 0 and 0.25 rad; Matt checked the captures ("looks fine"). ICO's profile still loads (its string entry is
unchanged). The sun's lens flare (`575b73ec`, its own screen sprite, sized by the widened focal 55.99) is still open.

Generator: it has no rule for game-projected sprites (ICO's entry was written by hand). A first rule (draws with no
camera block into the scene target with more camera draws after them, no colour-target sampling) did not find
`54fba8b4` and flagged two depth-tested programs (`811d6b04`, `de5634f5`, 20 draws each) instead; reverted. Notes for
a second try: the glows read `c[0..2]`, which `matrix_less()` takes for a 3-row block; 54fba8b4 also draws into
`0xc1d40000` (the 320x320 effect target, reused as the 1280x720 HUD target), which may have counted against it; check
what it samples (a depth texture would read as a colour target).

## 2026-10-03: pause menu text in the headset (simulator, multiview build)

From `vrtest_dante_acre_v3` with Matt's config (`tools/re/drive.sh` KEEPCFG): Start, then R1 through the tabs
Upgrade, Relics, Dante's Journal, Collectibles and Magic. Every tab is whole in the HUD box with all its text
legible: tab names, level/EXP boxes, "Equip relics to modify stats...", the Journal's categories, "30 Pieces of
Silver" and "Beatrice Stones" descriptions, "You do not have any magic spells yet", button prompts
(`evidence/dante/2026-10-03-pause-*`). Still unchecked: loading-screen hints, in-game pickup popups, subtitles.
