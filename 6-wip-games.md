# Unreleased games: work in progress

State of every game that has VR work but is not in a release. One section per game: where its files are,
how far it got, and what is open. Detail and history belong in `plans/profiles/<TITLE_ID>-notes.md`, with
evidence in `plans/evidence/<game>/`.

**Rules.**
- Game-specific progress goes here and in the game's notes file, **not** in `4-next-steps.md`. That file
  keeps the gates, generic renderer and profile-format work, and releases.
- When a game ships, add it to `rpcs3/vr-games.md`, move its profile and patch into `rpcs3/bin/`, and delete
  its section here. Its notes file keeps the history.
- Keep the "Not yet playable" table in `rpcs3/vr-games.md` in step with this file. That table is what users
  see.

**Where the files are.** `package_release.py` ships only **git-tracked** `bin/` content, so a WIP profile can sit
untracked in `bin/` for testing without being released. Unreleased profiles and patches are committed in
`rpcs3/vr-non-working/` (see its README). God of War Collection and Killzone 2, once tracked in `bin/`, moved to
`vr-non-working/` for vr7 (untracked copies stay in `bin/`).

## Release list: approved for the next release

Games Matt has signed off in the headset. At packaging time: move the profile and patch from
`rpcs3/vr-non-working/` into `rpcs3/bin/` (git-tracked), add the game to `rpcs3/vr-games.md` (and out of its
"Not yet playable" table and the `vr-non-working/README.md` table), smoke-test it from the zip, then delete its section
here (its notes file keeps the history).

| Game | ID | Approved | Files | Notes for vr-games.md |
|---|---|---|---|---|

**Shipped in vr7 (2026-10-02): Tales of Xillia and Super Stardust HD** (sections removed; history in their notes files).
**Shipped in vr8 (2026-10-03): God of War and God of War II (God of War Collection), Dante's Inferno, Asura's Wrath**
(sections removed; history in `profiles/BCES00800-notes.md`, `BLUS30405-notes.md`, `BLUS30721-notes.md`).
**Shipped in vr9 (2026-10-12, fork 9fcf9ddbf, tag v0.0.43-vr9): Dragon Age: Origins, Ratchet & Clank 1, 2 and 3,
Sonic & All-Stars Racing Transformed, SEGA Rally Revo, MotorStorm: Pacific Rift** (release-list rows removed; history in
their notes files). Gran Turismo 5 was approved but pulled before release (see its section).

**New games 2026-10-04 (Matt): Sonic & All-Stars Racing Transformed, Dynasty Warriors: GUNDAM, X-Men Origins:
Wolverine.** All three were 30 FPS games with no community patches: each got a fork frame-rate patch (real time
verified at several rates), a generated and hand-fixed profile, and checks on the OpenXR Simulator; Sonic and DW Gundam
also got a *Wider view (VR culling)* patch. Files in `rpcs3/vr-non-working/` (+ untracked `bin/` copies); regression
states `vrtest_sonic_race`, `vrtest_dwg_odessa`, `vrtest_xmen_jungle`. Sections below; detail in the notes files.

**Matt, while you were out (2026-10-06):** fixed and pushed: R&C 1/2/3 character shadow (`depth_remap_uv`); SEGA
Rally title screen flat, and the right-eye dust smear on the car (generic: depth buffers count as 3D; probably your
"bird shadows"). Found, not fixed: KH floor wedges are the game's own triangle drop (flat has them too); Sonic simulates
at a fixed 60 Hz at any rate (new frame-stats "new frames/s" shows it); Sonic's right eye has an extra shadow (not the
remap, sharing or multiview); X-Men is ~55 at 72 since 10-04 (multiview path ~2 ms slower than two-draw). Needs your
headset: R&C shadows, SEGA Rally title and dust, KH pause (uncommitted pose-hold build in `bin/`, KH `bin/` profiles
without `frames_without_3d_as_screen`). Needs you: a hung `rpcs3.exe` (PID 54120) and `dwm.exe` on 4 cores, see below
(end that dwm.exe or reboot; `bin/rpcs3.zombie.exe`, `bin/RPCS3.buf.zombie` and `log/RPCS3.zombie.log` can go after).

**Matt, overnight 2026-10-15 (God of War III, Dragon Age II, Uncharted; simulator-checked, headset recheck):**
- **God of War III: from a white screen to a working stereo picture, 29.5 -> 52-59 FPS** (300%, 2880x2880 eyes, VR 90).
  New profile and a head-driven *Wider view* patch (fork 0f0757681..), MB/DOF off (community), HUD boxed, pause menu
  on the fixed screen. Generic fork changes: one-layer copies of eye-invariant surfaces (fd5631db8), `tangent_y` culling
  mode, profile `image_pool_mb` (7b798af7c). Below 72: the game's SPU job list fills with the wider view. Your GoW3
  custom config has **HUD Fixed In Front: false** (HUD and menus follow the head): set it on. Check the view's edges
  (culling capped at 50/48 degrees to stop a crash in the opening). Details: `profiles/BCUS98111-notes.md`.
- **Dragon Age II: 86-88 FPS at VR 90** (2-4% late; game thread waits on an SPU job, no setting helps). Found, not
  fixed: after a **fresh boot** the sky is black in stereo and Bethany's hair floats beside her (a savestate made there
  and reloaded is fine): probably your "corrupted graphics"; conversation close-ups put faces huge and near.
- **Uncharted: 46 FPS uncapped** in your combat state (dips 43-44.5): 45 + frame generation gives ~90 shown, with dips.
  Game-bound; settings gave nothing (Accurate SPU Reservations off freezes it).

**Matt, overnight 2026-10-13 (simulator-checked; headset recheck):**
- **God of War Power Up / pause black, tutorial messages invisible: fixed** (fork 5ce006eba, pushed). The renderer's
  "game runs below the VR rate" adaptation rewrote GoW's rate word during hitches (90 -> 38 -> 45 -> 90 after a load or
  a loading hitch), and the game's menus and messages broke for the rest of the session. New profile key
  `game_rate_measured: false` on both GoW profiles. Power Up and pause checked on the simulator; a tutorial message in
  play not (your 22:56 state was saved already broken). Details: `profiles/BCES00800-notes.md`.
- **"Savestates don't work" for GoW on my side** was an OpenXR Simulator bug (fixed in the simulator); your headset
  runtime is not affected by it. Your two states: 22:51 is the title screen, 22:56 is the broken-message state.
- **Prince of Persia: works, 90 Hz at 300%** with a new fork patch *Unlocked frame rate* (game clocks real time). Pause
  menu fixed with a new key `hud_over_scene`. (Edge culling I reported was real scenery; nothing culled to yaw 60.)
- **NiGHTS: stopped.** Its logic is frame-locked at 30 (unlocked, it runs ~2x fast), and RPCS3 draws its trees and orbs
  on green squares (flat too). A hand profile renders in stereo, but it cannot reach 72.

**Matt, 2026-10-09 evening (simulator-checked; headset recheck):**
- **SEGA Rally:** the hang before a race is fixed (fork f2c09242b, a write into the read-only patch cave).
- **R&C 2 and 3:** cutscene detection now uses each game's scene flag (forks 844d4933c, bc568bef8); the second New
  Game stays at 60 through the ship flight. In-level cutscenes: untested here, Matt checks.
- **MotorStorm:** pause-menu bars and the grey box / sliding shadow under the car fixed (fork 800c13c3a). Tree-shadow
  aliasing is the game's shadow-map resolution (no change).
- **Sonic ghosting:** not reproduced clearly. A turned eye shows stray shadow pieces on the road; is that what you see,
  or trails behind bright areas?
- **Sorry:** my R&C 2 test (Quit Game from a test savestate) saved over **in-game slot 4** at 18:37 before I had a
  backup; if slot 4 was yours, that progress is gone. **F: was full** (my test screenshots and old dumps): moved to
  `C:
pcs3-scratch` (nothing deleted; delete it or move it back as you like). Sonic's config had been left at 300% /
  Null audio by an earlier test run at 17:50: restored to 450% / Cubeb.

**Matt, 2026-10-08 afternoon (your headset notes; simulator-checked, needs your headset):**
- **Dragon Age: Origins:** sky and window light shafts now stay in the world, and the black box when looking up after a
  load is gone (new profile key `either_layout_blocks`, fork 2e6f8d7c5). The sun rays are hidden in VR: made
  world-fixed they showed hard edges on head turns. Party portraits and the equipment figure fixed (Wider view 1.2).
- **Journey:** the traveller looked different in each eye because the world scale was 3x off: fixed (eye baseline,
  fork 650d17969). The sand edge on big head turns (past ~35 degrees) is still open: FOV patches cannot cover it, and
  widening the sand grid changes the traveller's ground (tested, rejected).
- **SEGA Rally bird shadows:** ~~investigated, not fixed~~ fixed later on 2026-10-08 (fork 9d39f9c93); Matt marked done 2026-10-11.
- **Sonic banding:** your state `BLUS30839_1_3` never presents a frame here (hangs after load; the regression state
  runs). Does it load for you? Where on the track are the bands?
- **R&C 1:** marked working. Ship it with R&C 2 and 3 once you have played those.

**Matt, 2026-10-08 (new games and fixes; all on the OpenXR Simulator, needs your headset):**
- **FEZ** 120 Hz: an orthographic game, shown as a 3D diorama on the world-fixed screen (new profile key). Savestates do not load.
- **Flower** 90 Hz (unlock patch; level 1). **flOw** 120 Hz (real-time step patch). Both steer by SIXAXIS tilt.
- **Journey** 72 Hz (SPU-bound: ~75 max in VR); install it from the collection disc's PKG (see `vr-games.md`).
- **Dragon Age II**: both eyes had shown the same picture; fixed; 72 Hz just passes. **Dragon Age: Origins**: forest
  gameplay 120 Hz, poses clean. **Inquisition**: still an emulation blocker (and too slow for VR even if fixed).
- **Sonic**: the "no car moves" freeze fixed (your frozen savestates stay frozen: make new ones); FXAA blur fixed.
- **R&C**: 2 and 3 poses clean; R&C 1 holds 72 (not 90).
- **Killzone 2** both eyes the same (diagnosed, not fixed). A new `dwm.exe` spins on ~4 cores again (since 10-07
  10:59): CPU-bound frame rates read low until it is ended or the PC restarts. Restored `Audio Renderer: Cubeb` in the
  Heavy Rain and NFS Hot Pursuit configs (left at Null by an earlier test run).

**DWM fixed 2026-10-07 (Matt asked; the spinning `dwm.exe` was ended, CPU idle 2%). Clean re-measurements:** R&C 1 on
`BCUS98282_1_5` (Wider view 1.25): **72.0 at VR 72** (RSX thread 10.8 ms; was 60 / 16.3 under DWM), 88.7-89.3 at 90.
Need for Speed: Hot Pursuit: **71.6 at 72, 83.4 at 90**. X-Men: 69.3 at 72 (was 55). Everything measured on 2026-10-06
after 12:49 and on 2026-10-07 before this note was under the DWM load.
Clean regression subset (`evidence/vrtest/2026-10-07-0856-clean/`, simulator, 300%; sustainable rate, new frames/s):
R&C 1 Veldin **90** (101 at 120), R&C 2 Aranos **120**, R&C 3 Veldin battle **90** (118 at 120), KH 1.5 Dive **120**,
MotorStorm **72** (87 at 90), Gundam **120**, SEGA Rally **72** (87 at 90), Dragon Age: Origins **120**. All make a new
frame on every flip **except Sonic**: it passes 90 Hz on flips but makes **60 new frames/s at every rate**.
**Sonic fixed 2026-10-07 (fork d54c9982b, frame patch 2.0 + profile):** the 60 Hz fixed simulation step now follows the
VR rate: **90.0 new frames/s at 90**, 120 at 120, real time (checked). Needs Matt's headset check (feel, shadows).
**Sonic per-eye shadows: third fix 2026-10-07 (fork 81fedb836): the shadow volumes take the scene camera's eye transform; per-eye masks match flat and each other at several head poses (simulator). Headset recheck.** Second fix (861614444): the remap's ray signs. Earlier step (fork eea6166d7): the shadow pass rebuilt its rays with another camera's
projection; both eyes now match flat in the fly-by. Probably also the shadows stuck mid-track. Headset recheck.
**Sonic, Matt headset 2026-10-08: still some horizontal banding in the distance on the track ahead** (state `BLUS30839_1_3` = `vrtest_sonic_matt_banding`; see the notes; **the state never presents a frame in my runs (hangs after load; the regression state runs): needs Matt**). Matt 2026-10-08: seen just after a race starts, looking ahead: the track in front shimmers, low-res with horizontal stripes, only in places (`evidence/sonic-banding/matt-track-stripes-2026-10-08.png`). ~~Investigated 2026-10-08: far-distance z-fighting~~ **Corrected 2026-10-08 (night): VR under-samples vertically. The 16:9 frame covers the headset's 89 degrees high, so VR 300% has the vertical detail of flat ~140%. Flat 150% shows the same stripes and flat 300% is clean. Not depth, motion blur or the VR camera (z/w bit-identical). Set Sonic's Resolution Scale to 450% (90 Hz, 0% late; 500% is the limit, 550% drops to 84). Better but not as clean as flat 300%. The full fix is per-eye rendering at the headset's aspect (a vertical resolution scale, many upstream files). Headset recheck at 450%.** **2026-10-09: road gaps (sky through the road at the far end) fixed: EDGE mesh trimming, patch *Disable mesh trimming (VR)* (on). Patch *Disable camera shake (VR)* (on by default): speed/boost and impact shake. See notes.** **Sonic 2026-10-08: the no-car-moves freeze fixed** (the VR step rate anywhere in the menus broke the next race start; new profile key `frame_rate_draws` applies the VR rate only in races: fresh boots 3/3, pause, second race OK). FXAA override verified and committed. Matt's frozen states stay frozen (the bad state is in them): make new ones. The race-load hangs seen at 120 were in runs with the menus at the VR rate; with the fix 4 more fresh boots (two races each) at 120 were all fine. See the Sonic section.

**Measurement caveat again (2026-10-08 00:30):** a new `dwm.exe` (PID 34824, started 2026-10-07 10:59) uses ~3.9 cores
continuously, so CPU-bound frame rates measured since then read low (R&C 1 `_1_5`: 66.5 FPS at VR 72, RSX thread 13.2 ms;
72.0 / 10.8 ms on the clean morning run). Same-session A/B comparisons hold. Not ended (needs Matt). Affected: the
Journey, Dragon Age II, Flower and DAO numbers of 2026-10-07/08 (they may be higher on a clean desktop).

**2026-10-08 08:00: the spinning `dwm.exe` was malware** (an XMRig miner injected into a fake `dwm.exe`, started at logon; removed, Matt informed). Clean subset (`evidence/vrtest/2026-10-08-0803-clean-nominer/`): R&C 1 **72** (88.5 at 90), Flower **90**, Journey **72** (86-87 at 90; was 75 under the miner), Killzone 2 64 at 72, X-Men 62.6 at 72, Dragon Age II 67.5-68.9 at 72 with 4.5-6.7% late (it passed with the miner running).
**Power-plan sensitivity (A/B, settings restored afterwards):** this PC's plan has Minimum processor state 0% (autonomous frequency control) and idle states on. Dragon Age II is bound by thread wake-up latency: 4 idle-priority busy threads or *Processor idle disable* bring it to 71.2-71.4 / 0.9-1.05% late (passes 72); Minimum processor state 100% alone does not. X-Men is RSX-thread-bound: Minimum processor state 100% raises it 62.6 -> **68.7** (RSX thread 15.5 -> 14.3 ms), while busy threads or idle disable drop it to 55-56 (less boost for the busy core). So headroom figures depend on the plan; Matt's own play uses the same plan. Suggest to Matt: Minimum processor state 100% (the High performance default), no downside seen.

**Measurement caveat (2026-10-06 afternoon):** an RPCS3 run hung at 12:49 (an R&C savestate run that used Cubeb audio
with the desktop locked; the process cannot be ended) and the Desktop Window Manager (`dwm.exe`, PID 34288) has used 4
CPU cores continuously since. Frame rates measured after 12:49 today may be low on CPU-bound games. Ending that
`dwm.exe` (Windows restarts it) or a reboot clears it; I was not allowed to do that unattended. The A/B comparisons
(same conditions both sides) still hold.

## Ratchet & Clank Collection: approved for the next release (R&C 1 Matt 2026-10-08, R&C 2 and 3 2026-10-10)

**Matt, headset, 2026-10-08: R&C 2 new game: (1) the opening video is stretched vertically; (2) after Start skips it, the in-engine spaceship cutscene's audio and video are out of sync (likely the 90 Hz rate: cutscene on frame count). Shots in `evidence/ratchet/rc2-newgame-2026-10-08/`; see notes. R&C 3 likewise: the opening in-engine cutscene of a new game runs about 1.5x fast (same suspected cause).** **2026-10-08: cutscene speed fixed in R&C 2 and 3 (fork 6017df830, `native_rate_when`: 60 Hz during cutscenes); headset recheck. R&C 2 new-game movie stretch fixed too (fork 03b8d29ec: the movie goes on the fixed screen). Headset recheck of both.**

**Fixed 2026-10-09 (fork 844d4933c): R&C 2 cutscene detection** (Matt: a second New Game and later in-engine cutscenes ran
at 90). `0x146c804` was the index of a five-buffer string ring, not a cutscene flag; it read 1 in the first opening by
chance. The profile now drops to 60 while `0x1477a24` = 1 (set by the cutscene object as it starts playing, cleared as it
ends) or `0x1329e20` = 0 (outside a level: the ship flights between planets, menus). Simulator: the ship cutscene at 90
matches the 60 Hz run frame for frame; after Quit Game and a second New Game it stays at 60 through the flight and
returns to 90 when Aranos loads; gameplay (walk, jump, shoot, pause) stays at 90. Headset recheck, including a later
in-level cutscene. **R&C 3 fixed too (fork bc568bef8):** 60 while `0xd79cb4` = 1 (its scene flag, set and cleared
by the scene code exactly like R&C 2's) or `0xc1eba8` = 0 (the level has not started: the new-game opening, which R&C 3
does not play as a scene). Opening at 90 matches 60 at 4/8/12/16 s; battle with movement and pause stays at 90.
In-level cutscenes in both games are untested (no save at one): Matt to check in the headset. See notes.

**Matt, headset, 2026-10-08: R&C 1 is working.** Ready to move from `vr-non-working/` to the shipped profiles in the next
release (with R&C 2 and 3 once Matt has played them in the headset).

State `BCUS98282_1_4` (map menu open). Open items, in order:
1. ~~Menus rendered in 3D (boxes not lined up between the eyes)~~ **fixed 2026-10-06 (fork 234cadcf6):** frames on the
   fixed screen as menus/pauses are flat (both eyes see the left eye's image); Matt checked it in the headset. Generic.
2. ~~Ratchet's shadow appears and disappears as the head pitches~~ **fixed 2026-10-06 in R&C 1, 2 and 3:** new
   profile key `depth_remap_uv` with `depth_remap_programs ["1459aa3afca2e172"]` (the shadow projector, the same
   program in all three games). On the simulator the shadow now sits where the flat game puts it (beside Ratchet's
   feet, on the side away from the light) at pitch 0, +8, +16, -12 and yaw +-20, in both eyes; before, it drew
   front-left and was gone at +16. Evidence `evidence/ratchet/shadow-2026-10-06/`. Needs Matt's headset check.
3. ~~Culling: the background draws in too late~~ **patch 2026-10-06 (fork 0402d6b9f, 2/3 in the next commit):**
   *Wider view (VR culling)* for R&C 1, 2 and 3 (hook where each game passes the field of view to its projection
   builder). Default Scale 1.25: R&C 1 is RSX-bound and pays for every extra object (VR 72: 72 -> 69.5 FPS at 1.25;
   uncapped 109 / 92 / 72 / 58 FPS at 1.0 / 1.25 / 1.5 / 2.0). R&C 2 (168 uncapped) and R&C 3 (119) have headroom.
4. Menus flat in R&C 2 and 3 too (generic). Shadow fix applied to 2 and 3 (same projector, checked on the simulator).
5. **Matt, headset, 2026-10-07: R&C 1 looks good now (menus, shadow, culling); performance is the remaining issue.**
   New state `BCUS98282_1_5` (2026-10-06 22:14, loads with the Start menu open) runs at about 70 FPS. **2026-10-07
   measurements** (simulator, 300%, VR 72, standing after closing the menu; this PC's `dwm.exe` was using ~3.7 cores
   throughout, so absolute numbers read low): Wider view 1.25 (default) 60 FPS, RSX thread 16.3 ms/frame; Scale 1.0
   70 FPS, 13.4 ms; flat (render=0) at 1.25 72 FPS, 11.0 ms. So the scene is RSX-thread-bound: ~4,650 camera draws a
   frame, the culling widening adds ~3 ms here and the VR per-draw work ~5 ms (~1 us/draw, spread thinly: eye
   constants pair ~18%, probe apply/bind ~7%, no single hot spot; `RPCS3_RSX_SAMPLE=3`).
   Tried: Multithreaded RSX on: +1.5 FPS (61.7 vs 60.0). Horizontal-only widening (aspect constant `0x52cd44`
   16/9 -> 2.222 with Scale 1.0): 66 FPS, but the image is squeezed horizontally in the headset (the eye remap does not
   follow the changed aspect): not usable as is. Options left: per-draw VR path optimisation (measured A/B), or a lower
   default Scale. **Matt: `dwm.exe` using ~3.7 cores with nothing running is likely costing your own runs too.**
6. **Open:** R&C 1 at VR 72 (`rc1_veldin`, simulator, 300%) by Wider view Scale: 1.0 72.0 FPS, 1.1 71.7, 1.15 71.2,
   1.25 69.5-70.0 (four runs). 1.1 brings the late scenery back (gate arch at yaw -40, plants ahead and at +40:
   `evidence/ratchet/culling-scale-2026-10-06/`), so 1.25 stays the default. Not resolution-bound (200%: 69.7). At
   vblank 120 the same scene runs 94 FPS (RSX thread 10.5 ms/frame, 12.2 at vblank 72), so the shortfall at 72 is in
   how the game paces to the vblank, not raw speed. Next: why a 10.5 ms frame cannot hold 13.9 ms vblanks.

## Second headset test (Matt, 90 Hz, 2026-10-01 late): continue here

Matt's recheck after the evening fixes (fork up to 03abf3550). New savestates (hard links):
`BCUS98282/vrtest_rc1_matt_shear` (= `_1_3`, 23:03), `BLUS31006/vrtest_tox_matt_puddles` (= `_1_1`, 23:09),
`BLUS30721/vrtest_asura_matt_letterbox` (= `_1_1`, 23:19).

| Game | What Matt saw |
|---|---|
| God of War Collection (game selector) | The intro movie is not visible, or at a very odd angle. |
| God of War 1 | The pause Power Up screen flickers between the fixed HUD and stuck to the face. All the characters look very small: change the scale so they seem human-sized. |
| R&C 1 | On the start menu a flat 2D plane is sheared off depending on the headset angle (right of the title, the tower is cut along a rectangle). The same happens in game (sky/planet region): `vrtest_rc1_matt_shear`. |
| Tales of Xillia | In the intro in-engine scene the blue floor lights render differently in each eye (bright bloom in the right eye only). In `vrtest_tox_matt_puddles`, walking makes circular puddles that render at the wrong depth, in front of everything else. |
| Dante's Inferno | The intro movie after New Game is still stuck to the head. |
| Asura's Wrath | `vrtest_asura_matt_letterbox`: the letterbox bars and a subtle grey 16:9 background box are visible. |

**Fixed overnight 2026-10-01/02 (fork local commits b16362394..cd9505230, not pushed; `bin/rpcs3.exe` built with them; checked on the OpenXR Simulator, Pimax Dream Air profile, 90 Hz). Recheck in the headset:**

Headset recheck list, in order of what changed most:
1. R&C 1: title, gameplay (was the flat window), pause menu. Also faster: 90 Hz sustained at 300% in the regression
   run (was 72), probably because the level's draws no longer took the HUD-box path.
2. God of War 1 and II: characters human-sized now? Power Up screen steady? The collection's intro animation.
3. Dante's Inferno: the intro movie after New Game; edges of the view while fighting (new Wider view patch).
4. Asura's Wrath: `vrtest_asura_matt_letterbox`, and an in-gameplay cutscene.
5. Tales of Xillia: walking ripples at floor depth; the blue floor lights in Milla's intro.
6. Puppeteer: trails gone? Try the VR menu's Camera Depth Offset (+1 to +3 m) to bring the stage closer.
7. Kingdom Hearts 1.5 (Final Mix, 60) and 2.5 (KH II, 30): first look; scale, HUD box, effects (sparkles, beams).

| Game | Fix | Still open |
|---|---|---|
| R&C 1 | **"Fixed 2D window" and the sheared plane found:** `boxed_camera_programs` named R&C 1's two world programs, so in the headset path most of the level went into the HUD box. New key `boxed_cameras` matches the pause-menu camera by its clip-w row instead. Title (from the disc), gameplay at the shear state and the pause menu checked. **Pause menus of R&C 1, 2 and 3** now go whole on the fixed screen (the frozen background followed the head; R&C 1's also flickered). | |
| Asura's Wrath | letterbox bars hidden (`fc13d36f`, untextured); grey 16:9 box = a full-screen pass boxed as HUD: `hud_skips_passes` | in-gameplay cutscenes not seen (same program expected); fades drawn with the same program would be hidden too |
| Tales of Xillia | walking ripples at the wrong depth: per-object scale in the eye offset (rings scaled up to 11x): `eye_offset: baseline_per_w`; measured on the simulator: the ring now has the floor's disparity (-165.6 vs -166 px) | blue floor lights in one eye: Matt saw it right on the simulator, rechecks in the headset |
| Dante's Inferno | intro movie after New Game: drawn over the first level, which renders behind it, so the frame counted as 3D: `screen_frame_draws` with the movie draw. **Culling: new patch "Wider view (VR culling)"** (`bin/patches/BLUS30405_patch.yml`, enabled by default): the game camera's FOV x2 (124 x 93 degrees); straight ahead complete, 40-degree turns mostly filled; still 120 Hz sustained at 300% | looking up/down past ~45 degrees still culls (vertical is the narrow axis); a larger factor needs a code cave |
| God of War selector | the intro is a real-time 3D logo animation through a camera: its four programs are `screen_frame_draws` | ~~still skewed and misaligned in the headset (Matt, 2026-10-03)~~ **fixed 2026-10-03 (fork 113c145eb):** the eight launcher/selector programs on the game camera, a new renderer starts on the fixed screen |
| God of War 1 | Power Up screen flicker (camera classification changed every ~3 frames): its menu-art draw pins the frame to the screen (180 -> 7 switches in 6 s); **world scale measured: 13.5 units/m, `eye_baseline` 3.2 -> 0.864** (characters ~3.7x bigger) | ~~QTEs not passable at 90 FPS~~ **fixed 2026-10-03:** patch *QTE button mashing at any frame rate (VR)* (`BCES00800_patch.yml`, on by default): the mash meter drains per second as at 60 FPS; Matt's Hydra QTE won at 90 in the test. GoW II's QTEs use other code, already real time (code read) |
| God of War II | same Power Up flicker (260 -> 7), same scale (0.864); savestate `vrtest_gow2_rhodes` | **Pause and Power Up flicker fixed at the cause 2026-10-03 (fork 113c145eb), both games:** off-aspect HUD draws counted as camera draws on the fixed screen; 0 switches with a menu open. **5% border fixed:** `display_rect` |
| Puppeteer | **dark/small explained:** the lit stage is as bright as flat but covers 13% of the view (game FOV 45 x 26, stage 27 m away): `eye_baseline` 0.064 -> 0.64 (diorama ~2.7 m away); try **Camera Depth Offset +2 m** in the VR menu to enlarge it. Velocity buffer fixed (`linked_camera_blocks [264]`), a likely cause of the trails | trails (recheck), deferred lights rebuild rays with the game's projection (shapes unchecked) |
| KH 1.5 (KH Final Mix) | **new profile** (generated + hand-fixed): new key `camera_palette` (characters were head-locked: rigid skinning with full clip matrices per bone), GS-projected effects, scale 6.4. **Unlocked frame rate patch v2 (2026-10-02): real time at 72/90/120 (measured); VR 120 Hz sustained at 300%**. **Headset pass 2026-10-03 (simulator, multiview):** the Dive's 2D layer (captions, the pedestal's Yes/No box) sits in the HUD box in both eyes where flat has it | gameplay HUD (command menu, HP) still unseen: scripted input reaches the sword but not the second pedestal; cutscene close-ups (telephoto camera) look distant at the headset's FOV; ~~opening video head-locked over a stray 3D background (state `BLUS31212_1_3`)~~ **fixed 2026-10-05 (fork e3b302013):** the game renders the Dive behind the movie; the movie quad's frames go on the fixed screen (`screen_frame_draws`); ~~world moves with head pitch and roll (state `BLUS31212_1_4`)~~ **fixed 2026-10-05 (fork 57a6069d0):** KH draws its scene with a y-down viewport, so pitch and roll were inverted; new profile key `view_y_down` (KH 1.5 and 2.5, generated); **not ready for release (Matt, headset, 2026-10-06, state `BLUS31212_1_5`): pause squashed vertically (caused by the `frames_without_3d_as_screen` fix); black wedges in the floor in and out of pause (**not view culling** (2026-10-06): a wider game FOV does not change them and flat has one too; the game drops floor triangles near its view's edge, see notes); character textures (arms, head) blink differently. See notes** |
| KH 2.5 (KH II Final Mix) | **new profile** (generated + hand-fixed): HUD box (tutorial box, portrait) world-fixed, GS-projected effects, scale 6.4. **Unlocked frame rate patch v2 (2026-10-02): real time at 72/90/120, jump unchanged (measured); VR 72 Hz sustained at 300%**. **Headset pass 2026-10-03 (simulator, multiview):** Twilight Town, walking, the pause box match flat; **right-eye flicker fixed** (Roxas's hair missing in ~1 frame in 25: multiview atlas textures, fork `d6acea81e` on `multiview`) | the game's fixed-step mode (never seen yet); main menu, battles and cutscenes unchecked (Triangle's menu not available yet at the first control) |
| Resogun | | **needs the .rap licence** |

**New games to profile (Matt, 2026-10-01/02):** full VR profiles for
- **Super Stardust HD**: **shipped in vr7** (`profiles/NPUA80068-notes.md`).
- **Resogun** (PSN, installed: `dev_hdd0/game/NPUA80900`): **blocked, no license** (`UP9000-NPUA80900_00-RESOGUN000000002.rap`).
- **Kingdom Hearts HD 1.5 ReMIX** (`F:/rpsc3/source/backup_saves/gow3_*`) into gameplay, with his config: Frame Rate Default, Vblank 36 and again at 90,
HUD Fixed In Front on, wider view applied. Every run showed gameplay as the full headset view (log "camera draws again:
headset view"), 36.0 FPS at Vblank 36 (1% low 34), 39.8 at 90 Hz. The profile's view checks use the PS3 output size
(his 1280x720), not the headset's eye shape, so his MeganeX shouldn't change them. Seen along the way: (a) idle at the
load point Kratos dies; the death screen shows as a yellow full view with a black box on the HUD box (frames count as
camera frames); (b) "BATCHJOB: AddJob: waiting for room in job list 3" hundreds of times after each load (546 in one
run), and in one run (key script went another way, probably a movie) the game froze with cellVdec "waiting for a
consumer": a frozen game shows the last frame as a box with black around it when the head turns, which matches his
description. Next: ask Matt for a savestate where it happens, or whether it still happens on this build.

Notes: `profiles/BCUS98111-notes.md`. **2026-10-15 (overnight): from a white screen to a clean stereo picture.** New
profile from the generator plus hand fixes: `camera_blocks [256, 260]` (the colour pass draws with depth test EQUAL
through `c[260]`, the same matrix as the depth prepass's `c[256]`; as a linked block it failed the test and the ground
vanished), `require_camera_aspect` (the final full-screen pass has a square w = z matrix in `c[256]`: bands and diagonal
cuts at the eye edges), HUD box (`orthographic_block 256` + the 3D health emblem `a87982423fedbeb4` in `hud_programs`).
Community *Disable Motion Blur* and *Disable Depth of Field* on (their screen-space passes smeared the view). Fork patch
*Wider view (VR culling)* (`BCUS98111_patch.yml`): the camera's tangents raised to what the headset needs, per axis
(x ~1.51, y ~1.56 straight ahead against the game's 0.51 / 0.29). State `vrtest_gow3_gaia2` (Gaia fight, MB/DOF off).
Frame rate (stereo, 300%, 90 Hz, simulator): 29.5 at the start of the night -> **42-52** (fork fd5631db8: one-layer
copies of the shadow map; separate x/y culling: 34 -> 47; tangent floors instead of a fixed-FOV ratio: 47 -> 52 in
`vrtest_gow3_gaia`, 42.5 in the busier `gaia2` fight). Without the wider view it runs 74-80 (black edges).
**Open:** (1) uncapped, the wider view crashed the opening (a 4.4 MB frame heap overflows; enlarging it breaks the
boot); with the tangents capped at 50/48 degrees the opening ran 5:44 without a crash and `gaia2` runs 55 FPS: check
the view's edges in the headset.
(2) The SPU job list fills ("BATCHJOB: AddJob: waiting for room") with the wider view: the SPUs are the limit there.
(3) World scale unmeasured (generator's 0.064). (4) Frame rate vs real time unchecked. (5) Headset run.

## Sonic & All-Stars Racing Transformed (BLUS30839, disc 01.00)

**Shipped in vr9 (2026-10-12).** Open items below are its known issues.

Notes: `profiles/BLUS30839-notes.md`. Profile and patch file in `vr-non-working/` (copies untracked in `bin/`).

- **Green stripes on head turns (Matt, headset, 2026-10-10).** His report: Career > World Tour > Sunshine Coast, go Right
  to Canyon Carnage (not Coastal Cruise), hold R2 until the tunnel (the blue-lit cave); turning the head left or right puts
  a green stripes overlay across the whole screen. State `BLUS30839_1_7`, screenshots `evidence/sonic-green-stripes/`.
  **Fixed 2026-10-11 (fork 9585700b9, simulator), headset recheck:** the cave's tiled lights were drawn in the game's screen space, so the
  teal light slid over walls and floor as the head turned and the right eye had unlit blocks. New profile key
  `depth_remap_screen` (tile quads turn with the head, each eye pixel lit by its own tile's lights at its real position,
  the light-culling depth pyramid read in the game's view); plus the night's `min_scalable_dimension: 20` (the readback grid
  at 450%). Yaw 0/+-30 in the overhang and the blue cave: clean, eyes alike, 90 Hz at 450%. See the notes. Matt's `_1_7`
  still never runs here (saved with the home menu open; see the notes).

- **Frame rate:** fork patch *Unlocked frame rate (follows Vblank Rate)*: the vblank handler's flip interval 2 -> 1.
  Game time is measured: real-time at 60/120/180 (same track positions at the same wall times). Flat 130-180 FPS.
- **Profile:** generated in a race (`column_vectors c[138, 4, 0]`, HUD `c[138]`, `hud_box_after_shader`, metres),
  without the generated `depth_offset_projection` (a dark band in the HUD box) and the 640-wide stereo rule.
- **Culling:** fork patch *Wider view (VR culling)* (Scale 3.0 = 150 degrees high, cap): straight, turned and looking up
  filled on the simulator. Costs 120 -> 90 Hz sustained.
- **Distant shadows fixed 2026-10-04:** the half-resolution cascades (`ed46d28a122d7235`) rebuild positions from a
  game-camera view ray; new renderer variant `depth_remap_ray_texcoord` / `depth_remap_xyw` remaps the ray too (fork
  1aef7457b). Eyes agree; 90 Hz kept.
- **Open (reported by Matt 2026-10-05, state `BLUS30839_1_0`):** graphical corruption: many horizontal lines
  across the image; and a shadow that differs between the left and right eye (a new case: the distant-shadow
  fix above covers `sonic_rock`). Not investigated yet. (The missing sound in the same run was not a game issue:
  a test run had left `Audio Renderer: Null` in the custom config; restored to Cubeb.)
- **Open (Matt 2026-10-07): no car can move (player and AI), in his states `BLUS30839_1_1`/`_1_2` and sometimes
  from a fresh boot.** The race HUD appears (10th, lap 1) but the 3-2-1 countdown never starts; race clocks run, audio
  plays. Matt's states stay stuck even at 60 Hz, with patch 2.0 off, and after Restart Race, so the stuck state is
  saved in the savestate. Fresh boots: sim at 60 OK 5/5; patch 2.0 at 90 froze 4/7, at 120 2/2. **Ruled out:** dropped
  fixed steps (a test patch that never drops steps, `0x1f97f8 -> b 0x1f981c`, still froze 3/3 at 120), Wider view,
  the measured-rate fallback. A fresh-boot fly-by state made at 60 (`son_fly60`, mine) starts the race normally at 60
  and 90, so the freeze is decided before the fly-by (loading / race setup), not at the race start. Next: repeat
  `son_fly60` at 120 a few times to confirm, then find the race-start gate. Details in the notes.
- **Open (Matt 2026-10-07): the image looks low resolution even at 400%.** Cause found: the final FXAA pass
  (`ad9998b4d5599447`) has its tap offsets (fc5, fc7, fc10, fc12) sized in guest pixels, so at high resolution scale it
  blurs over several real pixels. `fragment_constant_overrides` setting them to 0 (FXAA off) is in the
  `vr-non-working` profile and the bin copy, **not yet checked visually or committed**.
- **Ghosting on fast head turns (Matt, headset, 2026-10-11, state `BLUS30839_1_8` = `vrtest_sonic_matt_ghost2`): fixed
  2026-10-11 (fork 6df850777, profile `reproject_older_frames`), simulator; headset recheck.** The final
  composite's radial blur blends a copy of the previous frame (texture `0xc1608000`, filled by a blit), drawn at an older
  head pose: doubled scenery mid-turn (`evidence/sonic-ghosting/fast_turn_*`). Earlier report below.
- **Open (Matt, headset, 2026-10-09): turning the head leaves ghosting everywhere**, which Matt thinks is linked to the
  sunlight. State `BLUS30839_1_6` (17:49), hard-linked as `vrtest_sonic_matt_ghosting`. Not investigated yet.
- **Open:** headset run.

## Dynasty Warriors: GUNDAM (BLUS30058, disc 01.00)

Notes: `profiles/BLUS30058-notes.md`. Profile and patch file in `vr-non-working/` (copies untracked in `bin/`).

- **Frame rate:** flips every vblank already but steps battles one 1/60 s frame per frame (1.9x at 120). Fork patch
  *Frame rate follows VR*: the battle step reads a free word (`0x45f880`) the profile sets to 60 / fps
  (`game_vblank_frames_f32`). Real-time at 120 (clocks and a walk timeline).
- **Profile:** generated (`row_vectors c[256, 0]`) + `require_camera_aspect` (the characters keep light vectors in the
  terrain's camera block `c[0]`: stretched mobile suits without it; the generator now writes this key) +
  `preprojected_programs` for the CPU-projected effects; `clip_space_scene_draws` removed.
- **Culling:** fork patch *Wider view (VR culling)* (Scale 3.0: 30 -> 90 degrees high).
- **Menus fixed 2026-10-06 (fork, see notes):** the title and main menu drew the 3D mobile-suit model and the 2D
  panels apart per eye; now whole on the fixed screen (`screen_frame_draws`). The in-mission pause menu was already
  right. **Portraits:** briefing/pre-mission ones fixed 2026-10-06 (`game_camera_programs`); battle dialogue portraits still
  blank (open, see notes).
- **Open:** space missions, cutscenes, other modes; headset run.

## X-Men Origins: Wolverine (BLUS30268, disc 01.00)

**Parked (Matt, headset, 2026-10-08):** the graphics look terrible and low-res, and it performs badly (62-69 FPS at 72
measured 2026-10-08). Not worked on until the other games are done.

Notes: `profiles/BLUS30268-notes.md`. Profile and patch file in `vr-non-working/` (copies untracked in `bin/`).

- **Frame rate:** fork patch *Unlocked frame rate (VR)* removes the main loop's 62 FPS cap; the game keeps its two
  vblanks a frame and the profile runs Vblank 144 (`vblanks_per_frame 2`, `max_fps 72`). Every-vblank flips (patch
  *Present every vblank (flat 60 FPS)*, off by default) are steady flat but alternate in stereo. Real-time at any rate.
- **Profile:** generated (UE3, `row_vectors c[0]`, 100% coverage) with the HUD block corrected to `c[200]` (pause menu
  splat and icons were missing).
- **Per-eye shading fixed 2026-10-04:** the generator had taken UE3's camera-relative eye `c[4]` (always the origin)
  as the camera position, and the wall lighting read the per-eye offset; slot removed, generator fixed (fork 3a40d9c82).
- **Open (Matt, headset, 2026-10-05):** the HUD rotates with the head: not reproduced on the simulator (health
  bar, tutorial prompt and pause menu stay world-fixed at every pose, see notes); needs Matt's screen. Pixelated even
  at 400%: measured, the game renders at full scale; the 16:9 eye image covers 120 x 109 degrees, so vertical density
  is 60% of horizontal in every game (anisotropic resolution scale proposed in the notes).
- **Open:** the sky
  ends at the game's 91 x 60 degree view (no culling patch yet: the scene view is not written by PPU code); 72 Hz has no
  margin; headset run.

## SEGA Rally Revo (BLUS30068, disc 01.00)

**Shipped in vr9 (2026-10-12).**

**Status (Matt, 2026-10-11): everything is done except the race-start frame rate.** Done: water lines (Canyon),
bird shadows, the pre-race hang, the title screen on the fixed screen, menus, mirror, dust, edge culling with head
turns. **Open: Quick Race Canyon start at Vblank 90** (Matt: ~50 FPS). 2026-10-11 (fork 2d6443f53): small reflection-map
draws culled (`small_draw_cull`) and patch *Draw distance (VR performance)* 0.35: start ~82.5 FPS over the first 10 s
(was 74-80), grid 80 (was 73.5), then 88-90 (simulator, 300%). Headset check: your start FPS. Remaining lever: the
Wider view's side culling (~7 FPS; the game's culler takes only the vertical FOV, not found yet). See the notes.

- **Matt, headset, 2026-10-10: 50 FPS in Quick Race, Canyon; water drawn as horizontal lines. 2026-10-11 night
  (simulator, Vblank 90, 300%): water fixed, frame rate improved.** States `sr_canyon_grid`, `sr_canyon_water` (route
  in the notes). Water: VR-only streaks from the water sampling a 640x720 screen copy kept at native size
  (`min_scalable_dimension` 912 -> 600; no measurable cost). Frame rate: only the grid and the first ~10 s are heavy
  (5,500-6,000 draws, RSX 15-17 ms); the 512x512 reflection map (~1,370 draws) is now redrawn every other frame
  (`shared_frame_targets`, -1.0 to -1.2 ms, forks 8a01067b2 + this). Drive at 90: start 74-80 FPS, then 85-90 for the
  rest of the lap (mean 85-87). Not 90 at the start: the cost is spread over thousands of small draws (crowd, tents);
  72 Hz holds there. Headset check: water, start frame rate.

Notes: `profiles/BLUS30068-notes.md`. Patch `BLUS30068_patch.yml`: *Unlocked frame rate (follows Vblank Rate)* (the
flip passes vsync interval 1 instead of 2) and *Wider view (VR culling)* (FOV x2.5 in the projection builder, cave in
the code page tail). Generated profile (`c[8, 0, 4]`, `passthrough_hud`), `max_fps 0`. Race state `sr_race0`,
route `tools/re/sr_boot.sh`. Savestates need Compatible Savestate Mode **and** `Disable SPU GETLLAR Spin
Optimization` (both in Matt's custom config). **Fixed 2026-10-04:** tree shadows on the road showed in one eye only (the right eye's copy of the light-space
shadow map went stale; eye-invariant targets now share the left image). Was: while driving, dark car-sized patches appeared on the road in
one eye only (ruled out: Wider view, eye separation, multiview/batching, the shadow-map and decal programs; gone with
`passthrough_hud` off in one run; identical runs differ, so it is timing-dependent). **72 Hz** sustained with Wider
view 2.0 (now the default; 2.5 drops to 68 FPS).
- **Fixed 2026-10-05 (fork 17b02348e):** on the menus the items flickered on and off (state `BLUS30068_1_2`): the
  front end went whole on the fixed screen via `screen_frame_draws` (its background and card programs).
- **Performance, 2026-10-06 (fork 24f0bf997): 90 Hz.** The RSX thread waited for occlusion query results (22% of
  its time); new profile key `zcull_relaxed_sync`: Vblank 90 at 300% 79.0 -> 88.8-90.0 FPS, late 0-0.3% (two runs),
  Vblank 180 82 -> 105. Race shots relaxed vs strict alike.
- **Fixed 2026-10-09 (fork f2c09242b): the hang before a race** (Matt: black screen after the menus). The emulator froze
  on the title screen, ~40 s after boot: `culling_scale_f32` wrote the Wider view Scale word `0x4d7180`, which sits in
  the patch cave in the code segment's read-only tail ("Access violation writing location 0x4d7180"). It now writes
  past the page protection, as a patch does. Fresh boot through the menus on the simulator: race loads in stereo.
  The savestate runs had not shown it. Headset recheck.
- **Bird shadows slid with the head (Matt, headset, 2026-10-08): fixed later that day (fork 9d39f9c93, simulator),**
  **headset recheck.** The 912x912 shadow map passes went into the head-fixed HUD box (the passthrough-HUD test compared
  with the 512x512 mirror view); with `hud_display_buffers_only` only display-buffer draws can be HUD now. VR matches
  flat at the same moment. Notes "Fixed 2026-10-08". Was: on the start line the birds' shadows slid over the ground as
  the head turned (`evidence/segarally/matt-bird-shadows-2026-10-08.png`).
- Old (Matt, 2026-10-05; since done: 90 Hz on 2026-10-09, the start 74-80 at 90 on 2026-10-11): 72 Hz had no margin, aim for 90.
  Old notes: Known so far: RSX thread ~12 ms a frame in stereo at 72 (~5 ms flat at
  175-225 FPS); Wider view 1.0 and 2.0 cost the same. Profile where the time goes (`RPCS3_VR_FRAMESTATS`,
  `RPCS3_VR_GPUPROF`, draw counts per pass) and look for passes to drop or share between the eyes (shadow
  maps, reflections, post effects).

## FEZ (NPUB31448, PSN 01.00)

**Parked (Matt, 2026-10-09).** Not worked on until the other games are done.

Notes: `profiles/NPUB31448-notes.md`. 60 native, flips every vblank, real time at 120: no patch. Orthographic camera
(`row_vectors c[0]`, w = 1): new profile key **`orthographic_stereo`** (fork 82c80ffdc) puts the game on the fixed
screen in stereo with a 1.5-degree toe-in about clip z 0.507 (the playfield's front); the generator writes it.
**120 Hz** in VR. Test script `tools/re/fez_vr.sh` (savestates crash on load). Open: other scenes and rotations,
headset run (screen size, depth strength).

## Flower (NPUA80083, PSN 01.00)

**Parked (Matt, 2026-10-09): it needs a tilting joypad** (steering is SIXAXIS motion only). Not worked on until the
other games are done.

Notes: `profiles/NPUA80083-notes.md`. Patch *Unlocked frame rate* (PhyreEngine vblank handler 2 -> 1 vblanks); real
time (clocks 1.0x at 120). Generated profile + hand fixes: the sky's camera `c[260]`, `view_y_down` removed (inverted
pitch/roll), the "Hold Any Button" prompt boxed. **90 Hz** sustained at 300%. Savestate `vrtest_flower_l1`.
Open: later levels, the hub in VR, headset run.

## Journey (NPUA70218, from Journey Collector's Edition BCUS98377)

Notes: `profiles/NPUA70218-notes.md`. The collection disc installs its games from PKGs (flOw NPUA80001, Flower
NPUA80083, Journey, three game-jam games); installed 2026-10-07. Patches: *Unlocked frame rate*, *Wider view (VR
culling)* (Scale 2.5: the dunes are tiles chosen by the camera's FOV), *Disable SPU MLAA (VR)*. Profile: SPU post
buffers redirected per eye (`texture_redirects`), their readbacks late, `view_y_down` removed. **72 Hz** sustained; the
game is SPU-bound (~67 flat, 70 with MLAA off; ~75 in VR, where the late readbacks help). Savestate
`vrtest_journey_dune`. Open: 90 Hz (SPU), later levels, headset run.

## flOw and the bonus games (Journey Collector's Edition)

**flOw parked (Matt, 2026-10-09): it needs a tilting joypad** (steering is SIXAXIS motion only), like Flower.

**flOw done 2026-10-08: 120 Hz** (patch *Frame rate follows VR (real-time step)*: its dt was clamped to at least 1/60;
profile generated; notes `profiles/NPUA80001-notes.md`). Was: flOw (NPUA80001, APP_VER 02.10), Grave Diggers (NPUA80788), Duke War!! (NPUA80789), Nostril Shot (NPUA80790) installed
2026-10-07. flOw: 60 native and flips every vblank (120 at 120), game clock real time but a time value at `0xe960c0` (and
few positions) advance 1/60 per frame (2x at 120; written by an SPU job, no PPU store seen): generated profile kept at
`max_fps 60` (perspective camera `column_vectors c[256]`, 72 degrees; no depth buffer); the camera follows the creature
constantly, so the pose sheet could not separate head-locked layers yet. Bonus games (2026-10-08): Grave Diggers, Duke War!! and Nostril Shot are 2D local-multiplayer game-jam prototypes (sprites only, no camera matrices: `profile_survey.py` finds no camera block); 60 FPS flat. Nothing to profile for VR (they would only be a flat screen); left without profiles.

## Dragon Age: Origins (BLUS30415, disc 01.00)

Notes: `profiles/BLUS30415-notes.md`. Already presents every vblank and steps by measured time: no frame-rate patch.
Patch `BLUS30415_patch.yml`: *Wider view (VR culling)* (camera FOV x2.0 at `0x71b85c`, cave `0x144f980`; 2.5 makes
the fireplace flames streak). Generated profile (`c[256]` rigid, HUD `c[260]`, `baseline_per_w`), `max_fps 0`.
State `da1_castle0` (Castle Cousland hall after the opening). **120 Hz sustained** at 300% on the simulator.
Unchecked: combat effects, outdoors, cutscenes.
**Fixed 2026-10-05 (Matt's state `BLUS30415_1_2`, a conversation):** grey to the right, characters without legs and
a ghost overlay on head turns were all culling with the conversation camera's narrow close-up FOV (x2 was not
enough); *Wider view* 1.1 takes at least 60 degrees x Scale (fork 9f525a4c4).

## Dragon Age II (BLUS30645, disc 01.01)

**Parked (Matt, 2026-10-08): corrupted graphics and poor performance.** Not worked on until the other games are done.

Notes: `profiles/BLUS30645-notes.md`. **2026-10-07: both eyes had shown the same scene (the scene comes back from a
main-memory copy by blit): fixed with blit-aware `texture_redirects` to "camera"; 72 Hz passes (71.5-71.6, <1% late).**
Real time without a patch. Generated profile (`c[256, 269, 263, 271]`,
`clip_space_scene_draws`, HUD `c[260]`), `max_fps 0`. State `da2_fight0` (tutorial fight), route
`tools/re/da2_boot.sh`; savestates need Compatible Savestate Mode (set). **Misses 72** by a hair in the fight (70.1-70.6
FPS, 1.2-2.3% late), limited by the game's PPU/SPU work (RSX thread mostly waiting); measure a town scene next.

**2026-10-15 (overnight, Matt asked for all three games at 90):** `vrtest_da2_fight` now runs **86-88 FPS at VR 90**
(300%, 2880x2880 eyes, simulator), 2-4.6% late (the 10-08 run was 67-69 at 72): close to 90, not sustained. The game
thread is the limit: 40-43% of `Eclipse::Update` polls an SPU job (`usleep(30)` loop at `0x2998e0`); the RSX thread
waits 37% in `semaphore_acquire`. Tried at 90, no gain beyond noise: SPU reservation busy waiting (86.1-87.2 vs
85.9-86.4), Usleep Time Addend -25 (86.9-87.5 vs 87.1-88.2). Late frames are scattered, not periodic (frame log).
Graphics: in a paused frame (radial menu) both eyes match each other and the flat image; the shadow differences seen
in a moving fight were motion. **Open:** conversation close-ups put the faces huge and near (the dialogue camera sits
close to them); candidate fix: `screen_frame_draws` with a draw unique to conversations (needs a conversation
savestate; a scripted fight did not reach one reliably). Matt's "corrupted graphics" (10-08): probably the **black sky and floating hair after a fresh boot** (found later that night; a savestate made there and reloaded renders correctly; causes ruled out in the notes).

## Dragon Age: Inquisition (BLUS30997, disc 01.01)

**Parked (Matt, 2026-10-08): corrupted graphics and poor performance.** Not worked on until the other games are done.

The first boot installs 5.3 GB (`dev_hdd0/game/BLUS30997install`), then the game sits at a black screen. Every later
boot stops presenting ~26 s in, while loading the start menu (log: trophy check, content permit, then the main
thread's last flip; PPU threads spin in `sys_event_queue_tryreceive`). Tried, all hang the same way: Clocks scale 50
(Frostbite 3 games are reported to need under 100%), SPU Block Size Mega, Accurate RSX reservation access, Sleep
Timers Accuracy As Host, PPU Threads 1, Cubeb audio, without the headset session. Not a VR issue: an emulation
blocker. **Clocks scale 30** reaches the title (at 9 FPS); a title savestate made at 30% runs at full speed until the
next level load hangs again. The hang is a frame fence (GPU label 0x42) whose commands the SPU job system never
submits. Notes: `profiles/BLUS30997-notes.md`. PPU hash `PPU-22a17ff565b6caaa2a6c498b7b9e9a31b4b43da2`; ELF in `tools/re/elf/BLUS30997.elf`.

## MX vs ATV Reflex (BLUS30321 v01.00)

Profile generated 2026-09-28 (`row_vectors`, camera `c[4, 76, 16]`, HUD `c[24]`, metres, `max_fps 30`,
`vblanks_per_frame 2`). It is untracked in `bin/` only, with no notes, patch or measurements. Next: a notes
file, a frame-rate check, and a decision to commit it to `vr-non-working/` or drop it.

## Final Fantasy X/X-2 HD Remaster (BLUS31211, disc)

Triaged 2026-09-30 with no profile made. PhyreEngine; the launcher offers X, X Eternal Calm, X-2, X-2 Last Mission.
FFX draws one frame every two vblanks (30 at 60, 45 at Vblank 90). In the opening campfire scene at Vblank 180 it
reached 86-90 FPS with game clocks at 1.0x real time (memory dumps; a voiced cutscene, so gameplay timing is
unchecked). At Vblank 240 (cap 120) the ceiling was only **80-91 FPS flat**, with the RSX thread and the game's
`PhyreEngineRenderThread` both at ~100%: no headroom for stereo. The first boot compiles ~2,100 PPU modules
(~8 minutes). Evidence: `evidence/ffx/`.

2026-10-01 re-check: the "RSX thread at 100%" reading was spin-waiting. Sampled properly (`tools/rsx_sample.py`), at
~90 FPS in the FFX intro (Vblank 240) the RSX thread sleeps 80% and the `PhyreEngineRenderThread` waits on lv2 objects
86%; the main thread polls a render-thread flag with 1 ms usleeps (`0x54cd8c`, 720 calls/s). So the ceiling is the
game's own render/SPU job pipeline, about 88-95 in the intro and 120 in menus: still no headroom for stereo.
**FFX-2** (launcher 3rd entry): its opening movie (cellSail) stalls black at a raised Vblank (plays at 60, then
in-engine battle at 30 FPS); same engine and pipeline as FFX, not pursued further. FFX-2 Last Mission and Eternal
Calm (short extras) not tried.

## Uncharted: Drake's Fortune (BCUS98103, update 01.10)

**Matt's headset report (2026-10-15 afternoon, build `faf4a5bce` on `openxr`), open, in his words:**
1. *"this jungle scene is massively dependent where you look, if you push up on the right stick then the frame rate
   crashes into the 50s. This was quite misleading saying its now in the 70s."* His fpsVR shot (jungle, looking up into
   the canopy): FPS 52, average 70.1, CPU frametime 9.2 ms, reprojection 22.8 %. My 72-73 FPS was one fixed view (the
   savestate's camera, looking ahead); the canopy view is far heavier. Measure jungle frame rate at several camera
   pitches (right stick up / level), not one view.
2. *"the boat is still in the 40s."*
3. *"in the jungle it keeps crashing, look at the logs."* Log (two crashes, 2:59 and 8:51): the game's SPU job memory
   runs out, `SpuJobMemory::AllocateSingleBufferedMemory(1936, 16): Failed to allocate.` with `m_buffer = 30300000,
   m_size = 2097152` (a fixed 2 MB buffer), then a SPURS job stops on its assert (`stopd` at SPU 0x7620, "Unknown STOP
   code 0x3fff") and the game dies. Probably the *Wider view* culling sends more objects through the jobs than the
   buffer was sized for (the same kind of overflow as God of War III's frame heap). Fix: enlarge the 2 MB buffer with a
   patch, or cap the widening. **Fixed 2026-10-15 (simulator; fork `776234819`):** the buffer is sized at boot
   (`0x3dd58` `lis r6,0x20`, laid out by `0x19d840` with the next region right after it; allocations follow at
   `0x30700000`, so it cannot grow in place). Any head turn of ~30 degrees sent both culling words to their max of 12
   (~85 degrees each way): job memory 1.94 of 2 MB in the jungle. Capped at 6 (~77 / 69 degrees): 1.33 MB at any yaw
   (5: 1.21, 7: 1.45). Headset recheck in the jungle, including combat.
4. *"the intro video doesn't work, its in a tiny green box."* **Fixed 2026-10-15 (simulator; fork `b9afc086a`):** the movie
   (after New Game) is drawn by the same generic full-screen program and 1280x720 texture as the sun shadow mask (the
   profile's `depth_remap_programs` entry), so it was depth-remapped and landed at native size in a corner of the
   eye-shaped target. The remap now applies only in frames that have drawn through a camera: the movie fills the fixed
   screen; the jungle's shadows unchanged.
5. *"in the jungle shadows are also misaligned and flickery and some rotate with your head."* Shadows on the ground and
   foliage don't line up with what casts them, flicker, and some turn with the head pose instead of staying fixed in the
   world. Candidates: the sun shadow mask pass (`fc15ec0752d20290`, full-screen, reads the depth buffer: if it
   reconstructs positions with the unrotated / one-eye camera, its shadows follow the head), and the shadow maps
   (`c3ee0000` / `c44d0000`, 2432x1216: if the game's cascade fit uses the widened culling or a per-eye camera, the
   cascades shift between frames and flicker). Check on the simulator with `simpose.py` yaw/roll against a level pose.
   Matt (follow-up): *"it also shifts and flickers when you rotate the stick"*: the shadows also shift and flicker when the
   in-game camera turns with the right stick (no head movement), so it is not only the head pose. That points at the
   shadow maps' fit following the (widened) game camera: compare with the *Wider view* patch off, flat vs stereo.
   2026-10-15 (simulator, `vrtest_uncharted_jungle`): not reproduced in stills. The head-driven culling words change with
   every small head movement (x 1.97 -> 2.50 over 6 degrees of yaw), but the sun patches are the same with the words
   frozen, so the culling words are not it; both eyes agree at yaw 0 / +-30. Needs a temporal capture (it flickers) or
   Matt's exact spot. Seen meanwhile: at yaw +-30 the outer edge of each eye shows salmon sky through missing scenery
   (beyond the culling cap of 6, ~77 degrees; the eye's outer corner is ~88 degrees off the game's axis there).
   Matt (2026-10-15 evening): *"uncharted jungle shadows are only wrong WHILST the head is rotating, they snap back into
   place once you stop rotating."* So it is a timing / reprojection effect, not a static mismatch (why stills at fixed
   poses looked right): something in the shadow path uses a head pose from a different moment than the rest of the frame.
   Candidates: the sun shadow mask's depth remap (`fc15ec0752d20290`) built from one frame's eye transform while the
   depth / scene it reads were drawn with another (frame generation, or the remap matrix taken from the previous scene
   draw), feedback textures shifted by the head rotation since their frame (`vr_shift_texture_params`), or the
   late-readback path. Reproduce with `simpose.py` stepping the yaw every frame (a continuous sweep) and capture
   mid-sweep, comparing against a still at the same pose.

Triaged 2026-09-30 with no profile made. Native 30. The flat ceiling at vblank 180 on the boat is only
42-46, with every SPU thread at 100%, so it is SPU/PPU-bound and 90 is not reachable. Evidence:
`evidence/uncharted/boat-vblank180-45fps.png`. Its boot crash in `VKGSRender::flip` (Frame limit Auto) was a
generic bug, fixed in fork 4704701a2.

Title update 01.10 (the latest, `UP9000-BCUS98103_00-UNCHARTEDDF1SCEA-A0110-V0101-PE.pkg`) installed 2026-10-13 at
Matt's request. The triage above was on 01.00 and has not been redone on 01.10.

2026-10-13: Matt made the profile with the generator; details in `profiles/BCUS98103-notes.md`. In short: a VR
late-readback crash fixed (fork 90bd7ed59); 45 FPS locked via the game's own limiter (`default_fps 45`,
`vblanks_per_frame 2`, community *Unlock FPS* off); a head-driven *Wider view (VR culling)* patch fills the deck, hull and
ocean at every head pose; 2.0 (Matt reported lower-detail models with 1.0) enlarges the geometry jobs' viewport 16x so
no triangles are trimmed (combat 44.7 -> ~39 FPS with 2.0, 42.3 with 1.0). DLSS (settings shown again) recovers it: combat 53.8 FPS
with Performance + model E at 250%, 45.3 with Quality + E at 333% (37.3 at 500% without). Matt (2026-10-13): combat drops under 45 when unpaused (his
savestate `BCUS98103_1_0`); the game's SPU/PPU work sets the ceiling (~45 there), no emulator setting moved it.

**2026-10-15 (overnight):** Matt's combat state at Vblank 600 uncapped (300%, his config: DLSS Performance + frame
generation): **46 FPS median (dips 43-44.5)**, so 45 + frame generation gives ~90 shown frames, with dips. RSX thread
waits 35% of the time; PPU main 88%, six SPU threads 87-100%: game-bound. Tried: SPU Block Size Giga (no change),
Accurate SPU Reservations off (the game freezes on its pause screen). Splitting the *Wider view* into x and y scales
(as God of War III, where it gave +13 FPS) would need every reader of camera `+0x1d4` (many; y = x / `+0x1d0`)
patched: not done.

## Prince of Persia (BLUS30214, disc 01.00)

**Matt's headset report (2026-10-15 afternoon), open, in his words:**
1. *"save state 1 - there are culling issues, where shadows come and go behind you as you move."* State
   `BLUS30214_1_0` (14:40). **Fixed 2026-10-15 (simulator; fork `24e9b2433`):** the game fits its shadow maps to its own
   71 x 44 degree camera, so the ground below and beside it had no shadows, with a straight edge that moved with the
   camera. New patch *VR: Shadows cover the headset view* scales the shadow fit's frustum tangent (`0x1fb4e8`, after
   tanf) by a head-driven word (`0x15855d0`, `culling_scale_f32` mode `tangent`, max 6; 3.85 straight ahead). No straight
   edges at yaw 0 / +-90, pitch +-30; matches the flat game's shadows. Headset recheck, also while moving.
   Matt (follow-up, 15:26, state `BLUS30214_1_2`): *"culling is still an issue ... if you look slighty up with the HMD and
   move the joystick up and down you can see the tree and cliff come and go."* **Fixed 2026-10-15 (simulator):** patch
   *VR: Wider view (head-driven culling)* multiplies both culling tangents of the projection builder (`0x27b3d0`: +8,
   +0xc; cave at `0x27b508`) by the same head-pose word. In a stick sweep at head pitch 20 a rock ledge missing in one
   frame is now there in every frame. Cost ~10 %: state 1 at 300 % uncapped 126-136 -> 114-120 FPS.
   Matt (follow-up): *"its the wider view patch ... when I hold left or right to walk the camera swings massively"*: the
   camera controller also reads the horizontal tangent. **Fixed (simulator):** the patch now widens only the vertical
   tangent; walking left / right matches no patches, and the pop-in sweep still shows the ledge in every frame. My first
   test only walked forward. Matt's patch manager had *Unlocked frame rate* and *Shadows* off from his isolation test:
   turned back on.
   Matt (follow-up): *"No this doesnt work. The camera is fixed, but the culling issue is back."* **Still open; culling
   patch removed (fork `c3b9a843e`).** Draws per frame were the same (within 1-2) with no patch, vertical-only and
   both-axis widening in every scenario tried on `BLUS30214_1_2` (head pitch 15-30 with camera-stick nudges, walking
   forward / back, camera tilted down), so the projection builder's tangents do not drive this pop-in; my "ledge fixed"
   comparison was frames from different moments. Next: an exact repro (which stick, which tree / cliff, a present /
   absent screenshot pair), then find what hides it (frustum culling inside batched draws, distance / LOD fade, or a
   camera-obstruction fade), e.g. by the vertex counts of the scene draws rather than draw counts.
   Matt's repro (with screenshots): *"1_2 save state. loads with no tree on the left cliff. move the right stick up, the
   tree appears."* **Fixed 2026-10-15 (simulator; fork `9bbba7669`):** the game culls against its camera's projection matrix,
   not the tangents. Patch *VR: Wider view (head-driven culling)* now divides the main camera's P[0][0] / P[1][1] by the
   head-driven word right after it is built (cave at `0x2db350`). Tree present at load; head poses and framing unchanged;
   walking left / right matches no patch; the sky there takes the game's own hazy look (matches flat with the camera
   level; the vivid blue was the unrendered-sky case). Cost ~12 % (state 1 at 300 %: 111-118 FPS).
   Matt (follow-up, state `BLUS30214_1_4`): *"turning your HMD left or right shows shadows (behind the tree) become much
   brighter."* The shadow fit shared the culling word (3.85 ahead, 6 from 20 degrees of yaw); a 6x fit spreads the shadow
   maps too thin. **Fixed (simulator):** the shadow fit has its own word `0x15855d4` (max 4: 3.85 ahead, 4.0 turned);
   culling keeps `0x15855d0` (max 6). Shadows keep their depth at yaw +-20 / +-40.
   Matt (follow-up): *"This doesnt work. Look at the rock on the left of the first image on the edge of the screen, its
   very light. When moved to the center of the screen (by turning my head left, its much darker. Possibly this is
   something to do with the sand storm too, but its repeatable."* It was the sandstorm haze pass `149a9a825056ebba`: its
   per-pixel world rays come from the camera's inverse view-projection (`c[200]`), i.e. the flat game camera's rays
   stretched over the eye. **Fixed (simulator):** new profile key `inverse_camera_programs` rewrites that block per eye
   (H * G * E^-1); distant rocks keep their colour at any head yaw, the centre unchanged.
2. *"save state 2- if you look straight up in the air there is grass attached to the HMD again, like other games."*
   State `BLUS30214_1_1` (14:45). His shot: looking up between two rocks, a curved strip of grass / leaf sprites hangs in
   the sky in the middle of the view. Playbook candidates: "Objects hang in view when looking up: their program keeps the
   camera in another block" (add the block to `camera_blocks`), or sprites the game places itself (CPU-projected).
   **Fixed 2026-10-15 (simulator; fork `533f0b3cb`):** the grass / leaf program `d2113f906456e49b` gets the full constant
   upload and keeps its camera at `c[202]`; `camera_blocks` is now `[200, 202, 206]`. Gone at head pitch 75. Headset recheck.
4. *"Oh also in Prince of Persia there is a heavy outline on characters, I suspect this is overdone compared to flatscreen
   100% Can you check and if so fix it to make it thinner"* (the ink outline pass is probably sized in pixels: at 300 %
   it may be drawn thicker, or thinner and denser, than at 100 % flat: compare flat 100 % against VR 300 %).
   **Fixed 2026-10-15 (simulator; fork `0a94520f7`):** the outline pass's taps scale to the game's 71 x 44 degrees
   (`fragment_constant_overrides` scaled form): a thin line like the flat game instead of a thick smudge. Headset recheck.
3. *"can you try and optimise the frame rate too."* Measured 2026-10-15, DLSS off, uncapped, 300 % (Matt plays at 250 %),
   head poses 0 / pitch +-30 / yaw +-90 / 180: state 1 126-136 FPS, state 2 129-135, `pop_play` 144-158 (was 116.8 at 120
   on 10-13); with the culling fix state 1 114-120. RSX-thread bound (~7.3-8.6 ms/frame, ~1.6-2 ms of it waiting on the
   game). Nothing PoP-specific optimised yet. (Last measured: 90 Hz at 300 % in the first canyon, RSX-thread bound,
   ~73 FPS at 400 %, 2026-10-13; to remeasure DLSS-off at 120 Hz, heaviest views too.)

New 2026-10-13 (Matt). 30 FPS game: the fork patch *Unlocked frame rate (follows Vblank Rate)* clears the GCM label the
vblank handler counts down (1 instruction); game clocks stay real time (memory dumps at 30 and ~85 FPS). Generated
profile (column vectors `c[200]`/`c[206]`, HUD `c[200]`, 45-degree FOV) plus the new `screen_space.hud_over_scene`
(fork 2b7a97544): the pause menu depth-tests against the scene and near rock hid it on head turns. **90 Hz at 300%**
(walking in the first canyon), RSX-thread bound (~73 FPS at 400%). No edge culling to fix (to yaw 60). Open: combat HUD, world scale. States `pop_desert`, `pop_play`. Notes: `profiles/BLUS30214-notes.md`.

## NiGHTS into dreams... (NPUB30798, PSN 01.00)

New 2026-10-13 (Matt). Gameplay runs at 30 FPS and the logic is frame-locked (measured: unlocking the 33.3 ms limiter
runs the game ~2x fast; no float clocks): **stopped below 72** until the logic step can be split from rendering. RPCS3 draws tree billboards and the yellow orbs on
opaque green squares (also flat, no VR): not the colour key (registers 0), not isolated yet. Savestates fail. The
generated profile is wrong (picked indexed light vectors at `c[68]`); the hand profile (`row_vectors`, bare projection
`c[24]`, HUD ortho `c[68]`) renders in stereo on the simulator. Notes: `profiles/NPUB30798-notes.md`.

- **Uncharted (2026-10-15, branch `vr-pixel-savings`):** jungle at 300 %, DLSS off, uncapped **56 -> 73 FPS** from eager
  command buffer submission (on by default) and a fix for a per-draw depth barrier (Special Depth Comparison). Details in
  `profiles/BCUS98103-notes.md`. Merged into `openxr` (`27ca44435`..`faf4a5bce`), not yet released. Now RSX-thread
  bound (13.6 ms of a 13.8 ms frame); VRS and the hidden-area mask were measured and shelved (`11`/`12` section 8).
- **WipEout HD regression, open (2026-10-15):** `vrtest_wipeout_race` at 120 Hz now 100 FPS with **28-32 % late frames**
  (RSX 3.1-3.3 ms); the 10-11 runs had 100.0 FPS, 0 % late, RSX 1.3-1.6 ms. Not caused by eager submission (off: 29.6 %)
  nor the depth-barrier fix (without it: 27.8 %): something on `openxr` since 10-11. To bisect.
