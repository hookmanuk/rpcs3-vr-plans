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
- **Kingdom Hearts HD 1.5 ReMIX** (`F:/rpsc3/games/Kingdom Hearts - HD 1.5 ReMIX (USA) (En,Fr,Es).iso`)
- **Kingdom Hearts HD 2.5 ReMIX** (`F:/rpsc3/games/Kingdom Hearts - HD 2.5 ReMIX (USA) (En,Fr,Es).iso`)

## First headset test (Matt, 90 Hz, 2026-10-01)

Matt's first real-headset run of four WIP games, on the uncommitted build with the 2026-10-01 RSX-thread changes
(Gate 6 entry in `4-next-steps.md`). Until then none of these games had been run in a headset: they were checked
in desktop stereo and in the simulated headset view (`RPCS3_VR_FAKE_HMD`), from gameplay savestates, so boot
screens, menus and intro videos at the headset rate were never seen in a headset view.

| Game | What Matt saw |
|---|---|
| Dragon's Dogma | All the initial screens are tied to the face (head-locked), not fixed in place. Performance is bad in Matt's save: savestate `bin/savestates/BLUS31155/vrtest_ddda_matt_slow.SAVESTAT.zst` (hard link to `BLUS31155_1_1`, 2026-10-01 17:01; in-game save `BLUS311550` 17:00). Needs improving. |
| Ratchet & Clank Collection | The collection loader and R&C 1's initial screens are head-locked. **R&C 1 unplayable:** gameplay appears on a fixed 2D window, with depth problems (things appearing and disappearing) as the head moves. Matt suspects R&C 2 and 3 break the same way (not tried). |
| Tales of Xillia | Does not work at all: after the first Namco splash screen the view stays white forever (not frozen, but no game). **Later the same day: it only happens when Start is pressed on the first splash screen.** Left alone, it boots normally in the headset, in desktop stereo at 90 and on the OpenXR Simulator at 90 (no video-decoder stalls in the log). **In game (headset): performance great, but the HUDs are all over the place** (some tied to the head, some offscreen), screen effects in the wrong place, edge outlines around characters and blur outside those edges. |
| The Darkness | Broken after the splash screen. Later the same day: not a hang. After the intro's fire video the screen stays black for a long time (the old desktop boot script pressed Start there, so it never showed); waited out in the headset, the intro's videos are missing. **Parked: performance is terrible**, under 60 FPS in Matt's savestate `bin/savestates/BLUS30035/vrtest_darkness_matt_slow.SAVESTAT.zst` (hard link to `BLUS30035_1_1`, 2026-10-01 17:42). |
| Puppeteer | Barely works. Trails of graphics everywhere and very dark; in the intro a light moves with the head. Savestate showing the trails: `bin/savestates/BCUS98227/vrtest_puppeteer_matt_trails.SAVESTAT.zst` (hard link to `BCUS98227_1_1`, 2026-10-01 17:59). In the game proper it kind of works, but the world looks far away and small. |
| Jak and Daxter (Jak 1) | All HUD elements tied to the face. Stereo broken on lots of objects: at the wrong depth, hurts the eyes. Gameplay performs well, but **everything looks 1.5x speed at 90 FPS** (contradicts the desktop "real-time" check, see the Jak section). Savestate in gameplay: `bin/savestates/BCUS98281/vrtest_jak1_matt_gameplay.SAVESTAT.zst` (hard link to `BCUS98281_1_5`, 18:08; an earlier one `vrtest_jak1_matt_1804` = `_1_4`). |
| God of War Collection (GoW 1) | The main menu looks wrong: 2D and 3D elements combined at the wrong depth. In gameplay the main character has blurred edges; savestate `bin/savestates/BCES00800/vrtest_gow1_matt_blur.SAVESTAT.zst` (hard link to `BCES00800_1_2`, 2026-10-01 18:14). Performance good. |
| Gran Turismo 5 | Performance still bad: **around 40 FPS** in the headset. It needs at least 60 to be playable (the game's own rate). The "90 Hz (race start)" figure from the regression run (savestate after a 40 s settle) does not reflect play. |
| Asura's Wrath | **Works well.** In-engine cutscenes show a 16:9 box with black letterbox bars. Wanted: hide the box background and the black bars, showing just the 3D world and the HUD elements (text). |
| Anarchy Reigns | **Parked.** Splash screens and the intro are tied to the head, with HUD elements culled by depth. The intro is very long and cannot be skipped. Bad performance and lots of graphics issues in gameplay. Savestate at the start of gameplay: `bin/savestates/BLUS30632/vrtest_anarchy_matt_gameplay.SAVESTAT.zst` (hard link to `BLUS30632_1_2`, 18:36; also `vrtest_anarchy_matt_1834` = `_1_1`). |
| Dante's Inferno | Splash screen, menus and the intro movie are tied to the head. **Gameplay performs really well**; needs culling/FOV work so objects at the wider headset view are not culled. |

**The simulated headset is not the headset.** `RPCS3_VR_FAKE_HMD` renders the headset image on the desktop (same
camera transforms, headset FOV and HUD box) but with a **fixed forward pose**: head-locked and world-fixed screens look
identical, and nothing that depends on head movement can show. No OpenXR session (no compositor, no 90 Hz pacing, no
reprojection), a symmetric FOV, and the real-headset-only code is skipped: per-target pose stamping
(`vr_stamp_targets`), `vr_track_frame_boundary`, pose carried through copies, `vr_realign_blend_targets`. Running that
pose bookkeeping with the fake headset once dropped Dragon's Dogma to 6 FPS and Anarchy Reigns to 60 (cause never
found): a lead for Dragon's Dogma's slow save. Use `RPCS3_VR_WOBBLE` (moving pose) before trusting a fake-headset result,
and treat only Matt's headset runs as headset results.

**OpenXR Simulator (set up 2026-10-01): use it for headset checks.** A real OpenXR runtime in
`F:\rpsc3\source\OpenXR-Simulator` (Pimax Dream Air profile, 90 Hz); `tools/re/simboot.ps1 -Iso <disc> -Probe render=1`
boots RPCS3 on it for that launch only, `tools/re/simshot.py OUT` captures the composited eyes. Setup and quirks:
`5-vr-profile-playbook.md` > "Headset checks with the OpenXR Simulator".

**The Darkness on the simulator (2026-10-01):** disc boot at Vblank 90: copyright splash, the intro's fire video,
then black (Cross alone does nothing). Not a bug in the headset path: the same black stretch appears in desktop stereo
at 90 and 60, and `tools/re/dk_boot.ps1` (Start + Cross at 25 s) gets through it on the desktop and on the simulator. RPCS3's own image is black too, so the game itself draws black at
90 Hz; the headset path is not losing a picture. No `cellVdec ... waiting for a consumer` warning in the log.
Next: the same boot at Vblank 60 with the headset, and at 90 without it (`RPCS3_OPENXR=0`), to split "90 Hz" from
"headset session". Capture: `evidence/headsetsim/darkness_sim_90hz.png`.

**Status after the 2026-10-01 evening/night fixes (fork openxr, local commits c7b092610..1c082730c; all checked on the
OpenXR Simulator unless noted). Recheck in the headset:**

| Game | Fixed | Still open |
|---|---|---|
| all | splash screens, videos and 2D menus on the fixed screen instead of following the head (generic) | |
| Dragon's Dogma | boot screens | slow save holds 90 on the simulator (not reproduced) |
| R&C collection | loader and menus | R&C 1 "fixed 2D window" not reproduced (headset view correct, also via the collection menu) |
| Tales of Xillia | menus (camera block, 2D frames), a boxed scene copy (misplaced effect) | white screen not reproduced; battles unchecked; character outlines (if any remain) |
| Puppeteer | the intro light that followed the head (hidden glows) | trails (not seen on the simulator), dark, small (try World Scale) |
| Jak 1 | HUD/pause menu boxed; speed (capped at 60); stereo depth (`baseline_per_w`, eye_baseline 0.128) | world scale to confirm in the headset |
| God of War 1 | main menu (whole frame on the fixed screen); Kratos's edge halo (desktop-checked) | GoW 2 unchecked |
| Dante's Inferno | splash, menus, intro movie, pause menu | culling at the wide headset FOV (needs a patch) |
| GT5 | | 60 on the grid state; need a savestate where it drops |
| Asura's Wrath | | cutscene letterbox: need a cutscene savestate |
| The Darkness, Anarchy Reigns, X-Men Origins: Wolverine, Dragon Age II, Dragon Age: Inquisition | parked | |

**Fix in progress (2026-10-01 evening, fork c7b092610, local): boot screens no longer follow the head.** Frames
without 3D now go on the fixed screen by default (render targets carry `vr_has_3d`; a frame with no camera draws
whose displayed buffer holds no 3D is 2D; a paused game re-showing its 3D frame stays in the headset view). The
released profiles that were not opted in set `frames_without_3d_as_screen: false` (unchanged for them). Checked on
the OpenXR Simulator (head straight vs turned 25 degrees): Dante's Inferno (splash, title, intro movie), Dragon's
Dogma (notices, title), the R&C collection (logos, game-select menu), Anarchy Reigns (SEGA, intro text) are
world-fixed; Dante's gameplay returns to the headset view. Dante's pause menu (drawn over a copy of the 3D frame,
so the automatic check counted it as 3D) is fixed by its profile's `frames_without_3d_as_screen: true`. Cost 0.4% of
the RSX thread.

**R&C 1 "fixed 2D window" not reproduced (2026-10-01 evening).** On the OpenXR Simulator R&C 1 renders a proper
headset view, from the savestate and through the collection menu (`rc_boot.ps1` with the simulator runtime): yaw
and pitch move the world, the sky is overhead. Through the menu the simulator first looped STOPPING/IDLE (its
`xrEndSession` re-sent STOPPING; patched locally, branch `rpcs3-vr` in `OpenXR-Simulator`), and the session
then survives the switch (IDLE, READY, VISIBLE). A runtime whose session does not recover after the executable
switch would show the desktop window as a flat panel, which is what Matt describes; Matt's `RPCS3.log` from an R&C
headset run (OpenXR lines) would confirm it.

**First question when continuing: did the 2026-10-01 renderer changes cause any of this?** Not known yet. A/B each
game in the fake headset view (`-FakeHmd 100`, Vblank 90, boot from the disc, not a savestate) on the current build
and on the last committed build (`openxr` 90640f92d), then in the headset. Leads, unverified:
- Head-locked boot screens and menus: these screens are drawn without anything the profile boxes (no ortho block or
  HUD program it names), so they are drawn full-view and follow the head. Never tested; the gameplay HUD was.
- Tales of Xillia and The Darkness: both play an intro video after the splash. At the headset rate (vblank 90)
  Killzone HD's movie player stopped taking frames (black intro) and needed `video_vblank_rate: 60`. The desktop
  tests always skipped the intros or started from savestates.
- R&C 1 "fixed 2D window": the whole scene behaving like a boxed screen suggests the final composite (or the scene)
  is treated as HUD/screen space in the headset path (`passthrough_hud`, `hud_programs ["007f5efab1d12ef7"]`,
  `boxed_camera_programs`), or the camera draws are not classified there. Dump both eyes with `RPCS3_VR_RTDUMP` and
  check `probe why=<hash>` for the scene and composite programs in the headset view.

## Summary

**Sustained in VR, 300%** = the highest headset rate (72 / 90 / 120 Hz) the game holds in desktop stereo at
Resolution Scale 300% (3840x2160 per eye) on a Ryzen 7 9800X3D + RTX 5090, with under 1% missed frames, from its
regression savestate (`tools/re/vrtest_states.txt`, run 2026-10-01 `evidence/vrtest/2026-10-01-1259/`; Ratchet &
Clank and Dragon's Dogma re-measured after the RSX-thread work the same day, `evidence/vrperf/`; **re-run
2026-10-02 03:35 after the night's fixes: `evidence/vrtest/2026-10-02-0335`, no game lower, several higher**). **72 is the
pass mark** for fully compatible.

| Game | ID | Profile | Real-time above 60 | Sustained in VR, 300% | Headset | Blocker |
|---|---|---|---|---|---|---|
| Dragon's Dogma: Dark Arisen | BLUS31155 | `vr-non-working/` + untracked `bin/` copy | yes (community Unlock FPS, real-time) | **120 Hz** (prologue, 2026-10-02 run; 72 on 2026-10-01); Matt's slow save **90 Hz with multiview** (72 two-draw), 2026-10-03 | **WIP: graphics errors in the headset** (Matt 2026-10-03: many render errors, text cut off and a phantom layer when the head turns) | open-world frame rate and outdoor flares with `zcull_approximate` unchecked; headset frame rate (risk); needs update 01.02 |
| Ratchet & Clank Collection | BCUS98282 | `vr-non-working/` + untracked `bin/` copies (base + rc1/rc2/rc3 executable profiles) | R&C 1, 2, 3 yes (profile frame-time values, run speed verified) | **R&C 1 90 Hz**, **R&C 3 90 Hz** (2026-10-02 run, desktop stereo; both 72 before), **R&C 2 120 Hz** (Aranos and the machinery hall). Headset path (simulator, 2026-10-03): R&C 1 **72 on multiview** (90 averages 85.4), two-draw 69.4 at 72; R&C 3 90 on multiview | **R&C 1 working (Matt, headset, 2026-10-08)**; R&C 2 and 3 not yet played in the headset (was: R&C 1 unplayable, scene as a fixed 2D window; loader and menus head-locked) | R&C 1 has little margin at 72; R&C 1 pause menu |
| The Darkness | BLUS30035 | `vr-non-working/` + untracked `bin/` copy | yes (community 60 FPS patch, real-time) | below 72: 53 FPS at 72 in Matt's save (2026-10-04, multiview; 48 on 2026-10-01), 32 in the opening car scene | **parked**: under 60 FPS in Matt's save; intro black for a long time, videos missing | too slow at 300%; stereo and headset view fixed in the opening |
| Dynasty Warriors 6 Empires | BLUS30306 | `vr-non-working/` + untracked `bin/` copy | no: frame-locked, profile at 60 (180 flat possible) | 120, but frame-locked: plays at 60 | not played | 90 FPS needs a logic-step patch |
| Puppeteer | BCUS98227 | `vr-non-working/` + untracked `bin/` copy | yes (profile frame time, Vblank 180 = 90 FPS, real-time) | 90 (2026-10-02; 72 before) | **barely works**: graphics trails, very dark, world far away and small; the head-locked intro light fixed 2026-10-01 evening | stage small in the headset view; SPU post skipped in VR |
| Jak and Daxter Collection | BCUS98281 | `vr-non-working/` + untracked `bin/` copies (profiles, patch) | **Jak II yes** (fork patch *Frame rate follows VR (Jak II)*, 2026-10-04); Jak 1 no: steps a fixed 1/60 per frame, capped at 60 (a ratio fix broke it); Jak 3 no (74-85 flat in Spargus) | **Jak II 72 Hz** at real-time speed (90 averages 86), 2026-10-04; Jak 1 60 (cap); Jak 3 57 FPS at 72 | **Jak 1**: HUD boxed, speed fixed (capped at 60, reprojected) and stereo depth fixed 2026-10-01 late, simulator-checked; to recheck in the headset | Jak 1 at the headset rate; Jak II HUD in the headset |
| Midnight Club: Los Angeles Complete Edition | BLUS30442 | `vr-non-working/` + untracked `bin/` copy (profile, fork culling patch) | yes (community Enable Deltatime) | **below 72**: 60.8 FPS driving in town with full culling, 69.8 with the game's own (2026-10-17) | not played | RSX thread (~3000 draws a frame) |
| Anarchy Reigns | BLUS30632 | `vr-non-working/` + untracked `bin/` copies (profile, patch) | yes (fork patch, real-time verified) | 90 (Training only) | **parked**: splash/intro head-locked, HUD culled by depth; bad performance and graphics issues in gameplay | campaign unchecked; HUD timers 3x |
| Killzone 2 | BCUS98116 | `vr-non-working/` + untracked `bin/` copy | yes (real time; default 45: two vblanks a frame) | **72 Hz** (carrier walk, 72.0 / 0% late, 2026-10-13; 90 reaches 86: the game's PPU/SPU work; SPU Block Size Mega +2-3) | not played | eyes per-eye since 2026-10-13 (the SPU post layer, motion blur/DOF/sun haze made from the left eye only, is hidden in VR: `hidden_draws`); combat and HUD unchecked |
| Gran Turismo 5 | BCUS98114 | `vr-non-working/` + untracked `bin/` copy | yes (profile frame step; patch *Pre-race at full frame rate*) | **90 Hz in races** (400% stereo, simulator, 2026-10-05: race start 83-90, tree-lined track and grid 90 locked) | headset ~40 FPS on 2026-10-01 (old build): recheck | race start dips to 77-86 for a few seconds (RSX-thread bound); black arc at the top of the view on Rome (sky dome); menu cards and mirror fixed on the simulator 2026-10-05 (headset recheck) |
| MotorStorm: Pacific Rift | BCUS98155 | `vr-non-working/` + untracked `bin/` copy | yes (patch) | **72 Hz with multiview** (2026-10-03, race start; 90 averages 87, start window 1.1% late); two-draw misses 72 at the start (7.9% late) | not played | needs the multiview build for 72; ~~in-race HUD head-locked; view jitter while driving~~ **fixed 2026-10-06 (fork 13da162b8, headset recheck):** `passthrough_hud`; the clock now steps by the VR frame time instead of the jittery measured time; patches apply to savestates (a loaded state ran at 60 FPS) |
| Blur | BLUS30295 | `vr-non-working/` | yes (patch) | not measured | not played | 45-50 FPS stereo |
| Need for Speed Most Wanted | BLUS31010 | `vr-non-working/` | yes (patch, fixed per rate) | not measured | not played | in-race speed at 90 unconfirmed |
| inFamous 2 | BCUS98125 | `vr-non-working/` | no patch needed | not measured | not played | 52-72 stereo; SPU layer left-eye only |
| Metal Gear Solid 4 | BLUS30109 | `vr-non-working/` | yes (patch) | not measured | not played | ~35 stereo in Act 1; one hang |
| inFamous | BCUS98119 | `vr-non-working/` + untracked `bin/` copy | no patch needed | not measured | not played | ~25 stereo: too slow |
| Split/Second | BLUS30300 | `vr-non-working/` | yes (patch) | not measured | not played | race load-bound |
| God of War III | BCUS98111 | `vr-non-working/` + untracked `bin/` copies (profile, patch) | runs uncapped (frame rate not yet checked against real time) | **below 72**: 52-55 FPS stereo at 90 Hz (300%, simulator, 2026-10-15, culling tangents capped at 50/48 degrees); ~74-80 with culling left at the game's view (black edges) | simulator only (pose check 2026-10-15) | new profile 2026-10-15 (stereo, lighting, HUD box fixed); head-driven *Wider view* patch (capped: uncapped it crashed the opening, frame heap overflow); SPU job list is the limit. See notes |
| Sonic & All-Stars Racing Transformed | BLUS30839 | `vr-non-working/` + untracked `bin/` copies (profile, patch) | yes (patch, measured time) | **90 Hz** with Wider view 3.0 (120 with it off), 2026-10-04 | simulator only (real head poses checked 2026-10-05) | ~~distant shadows differ per eye~~ fixed 2026-10-04 (depth remap ray variant); ~~horizontal lines and per-eye shadow (`BLUS30839_1_0`)~~ **fixed 2026-10-06: Wider view 2.0 widens only the culling (game FOV for rendering and shadows, SPU frustum test off); faster than 1.0**; **not ready (Matt, headset, 2026-10-06 with 2.0): shadows misaligned between the eyes; some shadows sit in the wrong place on the track (stay in the middle of the track while driving); feels like 60 FPS inside 90 Hz although it reports 90 locked. See notes**; **2026-10-06: measured:** the game simulates at a fixed **60 Hz** at any vblank rate (60.0 new frames/s at VR 72, 90 and 120, new frame-stats measure); the extra flips repeat a frame. The 60 Hz source is not found yet (not the ELF's 1/60 floats, not the flip interval), see notes; headset run |
| Dynasty Warriors: GUNDAM | BLUS30058 | `vr-non-working/` + untracked `bin/` copies (profile, patch) | yes (patch *Frame rate follows VR*) | **120 Hz** (with Wider view 3.0), 2026-10-04 | simulator only (real head poses checked 2026-10-05) | space mission checked 2026-10-04 (120 Hz, correct); cutscenes, cutscenes unchecked; turned left, dark wedge at the far left edge (likely the game culling the starfield); ~~menus broken~~ title and main menu fixed 2026-10-06 (fixed screen); portraits: briefing ones fixed 2026-10-06 (head models on the game camera); **battle dialogue portraits still blank (DXT5 texture drawn blank only while VR renders; see notes)** |
| X-Men Origins: Wolverine | BLUS30268 | `vr-non-working/` + untracked `bin/` copies (profile, patch) | yes (measured time; the patch removes a 62 FPS cap) | **72 Hz** (Vblank 144, two vblanks a frame; 90 reaches 79), 2026-10-04 | simulator only (real head poses checked 2026-10-05) | **parked (Matt, headset, 2026-10-08): graphics look terrible and low-res, and it performs badly.** Earlier: top-left sky edge in the headset (not culling: a 75-degree FOV source found, widening it changes nothing); per-eye shading fixed 2026-10-04; **headset (Matt, 2026-10-05): HUD rotates with the head; image very pixelated even at 400% resolution** ; **2026-10-06: regressed to 52-55 FPS at 72 (RSX thread 17-19 ms/frame) on both today's builds; it held 72 on 2026-10-04: find the change (bisect fork commits since 10-04)**. Ruled out (A/B 2026-10-06): the depth-3D change, eye-invariant sharing (`RPCS3_VR_NO_INVARIANT=1`), the removed `camera_position.slot`. Two-draw (`RPCS3_VR_MULTIVIEW=0`) gives 64 FPS (RSX 15.4 ms) vs 55 multiview (17.6 ms): the multiview path costs X-Men ~2 ms; new frames 60/s of 64 flips. (Measured under the DWM caveat above.) |
| SEGA Rally Revo | BLUS30068 | `vr-non-working/` + untracked `bin/` copies (profile, patch) | yes (fork patch *Unlocked frame rate*: 30 -> vblank rate, measured time) | **90 Hz** except the race start (74-80 FPS for ~10 s on Quick Race Canyon at 300%; 72 Hz holds) | Matt, headset, 2026-10-11: all done but the start frame rate | **one open bug: the race-start frame rate at 90** (RSX thread 15-17 ms on 5,500-6,000 draws). Done (Matt 2026-10-11): water lines, bird shadows, pre-race hang, title screen, menus, mirror, dust, edge culling. History in the section and the notes |
| Need for Speed: Hot Pursuit | BLUS30566 | `vr-non-working/` + untracked `bin/` copies (profile, patch) | yes (patch: limiter + flip every vblank; profile frame step) | flat 110 at 120; **VR 73 at 90, 70 at 72** (RSX-bound) | simulator only (2026-10-07) | **Matt, headset, 2026-10-08: menu lights move as the HMD moves (`vrtest_nfshp_matt_menu`); in races the car ahead is double (`vrtest_nfshp_matt_race_paused`) and the whole race looks low-res, probably the same misalignment. To fix; see notes.** new (Matt, 2026-10-07: wants 90). Open: per-eye car shadow; sky-edge stripes; below 72 in VR (73 at 90). HUD in the box is fine (rechecked). See notes |
| Heavy Rain | BCUS98164 | `vr-non-working/` + untracked `bin/` copies (profile, patch) | yes (no patch needed: real time at 120, checked) | **VR 90 sustained** (with Wider view 2.5), 2026-10-07 | **parked** (Matt, headset, 2026-10-09: full of graphics glitches and stutters) | **Parked (Matt, 2026-10-09): graphics glitches and stutters in the headset.** Not worked on until the other games are done. Was: culling fixed by patch; headset pass (menus, QTE prompts, camera cuts, deferred lighting). See notes |
| FEZ | NPUB31448 (PSN) | `vr-non-working/` + untracked `bin/` copy (profile) | yes (no patch: every vblank, real time) | **120 Hz** (village, 0% late), 2026-10-07 | **parked** (Matt, 2026-10-09) | **Parked (Matt, 2026-10-09).** Was: new (Matt, 2026-10-07): orthographic game, shown as a **diorama on the fixed screen** (new key `orthographic_stereo`); savestates do not load (RSX access violation): every test boots and drives. See notes |
| Flower | NPUA80083 (PSN; also on Journey Collector's Edition) | `vr-non-working/` + untracked `bin/` copies (profile, patch) | yes (fork patch *Unlocked frame rate*, measured time) | **90 Hz** (level 1, 0% late; 120 reaches the game's ~104 ceiling), 2026-10-07 | **parked** (Matt, 2026-10-09) | **Parked (Matt, 2026-10-09): needs a tilting (SIXAXIS motion) joypad to steer.** Was: only level 1 seen (dev key script `motion`). See notes |
| flOw | NPUA80001 (from Journey Collector's Edition) | `vr-non-working/` + untracked `bin/` copies (profile, patch) | yes (fork patch: no 1/60 lower clamp on dt) | **120 Hz**, 2026-10-08 | **parked** (Matt, 2026-10-09) | **Parked (Matt, 2026-10-09): needs a tilting (SIXAXIS motion) joypad to steer**, like Flower. Was: only the first depth seen. See notes |
| Journey | NPUA70218 (installed from Journey Collector's Edition BCUS98377) | `vr-non-working/` + untracked `bin/` copies (profile, patch) | yes (fork patch, measured time) | **72 Hz** (0% late with SPU Block Size Mega); 90 reaches **86-88 on a clean CPU** (75 under the miner): the game's own SPU work, flat the same (84-88); Wider view 1.0 88.6, 2.5 86.8; scheduler/XFloat/SPU threads no help | simulator only (real head poses checked 2026-10-07) | **Matt, headset, 2026-10-08: needs a lot of work:** ~~the traveller renders differently in each eye~~ **fixed 2026-10-08 (fork 650d17969): world scale, `eye_baseline` 0.02 (a unit is ~3 m)**; **the world culls at the edge on large head turns: open** (the game's frustum reaches ~+-77 degrees at Wider view 2.5; head yaw past ~35 degrees shows the edge; FOV patches cannot pass +-90: needs the sand's tile culling disabled; see notes) (state `NPUA70218_1_2` = `vrtest_journey_matt`). new (Matt, 2026-10-07, wants 90): SPU-bound at ~75 in VR; *Wider view* 2.5 fills the dunes at head turns; only the first dune seen. See notes |
| Dragon Age: Origins | BLUS30415 | `vr-non-working/` + untracked `bin/` copies (profile, patch) | yes (no patch needed: every vblank, measured time) | **120 Hz** (Castle Cousland hall), 2026-10-04 | simulator only (real head poses checked 2026-10-05; combat 2026-10-08) | ~~Open (Matt, headset, 2026-10-08): sun rays and the skybox rotate with the head; black box in the sky~~ **fixed 2026-10-08 (fork 2e6f8d7c5): sky and window shafts world-fixed (`either_layout_blocks`), black box gone, sun shafts hidden in VR (world-fixed they showed edges). Headset recheck.** **2026-10-08: combat checked (wolf fight, `vrtest_dao_wolves`: poses clean); party portraits and the equipment figure were tiny full-body views (Wider view floored their FOV): fixed, patch 1.2**; Wider view default 2.0 (2.5 stretches fire); HUD stayed on the face at real head poses (Scaleform `c[0..1]`), fixed 2026-10-05 with `hud_programs`; ~~conversation culling (state `BLUS30415_1_2`: grey to the right, legless characters, a ghost overlay)~~ **fixed 2026-10-05:** Wider view 1.1 floors the FOV at 60 x Scale (close-ups were x2 of a narrow FOV); ~~trees head-locked after the pause menu (`BLUS30415_1_5`)~~ **fixed 2026-10-06 (fork 11323754a):** the foliage uses a DP4 camera at `c[258]`; new key `column_vector_blocks` |
| Dragon Age II | BLUS30645 | `vr-non-working/` + untracked `bin/` copy (profile) | yes (no patch needed, clocks at 1.0 measured) | **Parked (Matt, 2026-10-08): corrupted graphics and poor performance.** **72 Hz, at the edge** (71.5-71.6 FPS, 0.5-0.7% late after the stereo fix, 2026-10-07, measured with the miner busy). **2026-10-08 on a clean idle CPU: 67.5-69.0, 4.3-6.7% late (fails)**; flat the same (69.0; 74.7 uncapped): the game is CPU-bound near 72 and sensitive to wake-up latency (passes with idle states off or a background load). No RPCS3 setting fixes it (Sleep Timers, scheduler, Multithreaded RSX, SPU busy-wait 70.3) | simulator only (real head poses checked 2026-10-07) | **stereo fixed 2026-10-07** (both eyes had shown the same scene: SPU copy blitted back; `texture_redirects` "camera"); Kirkwall, cutscenes unchecked |
| Dragon Age: Inquisition | BLUS30997 | none | - | - | - | **Parked (Matt, 2026-10-08): corrupted graphics and poor performance.** **emulation blocker:** hangs loading the start menu and each level (a GPU frame fence the SPU job system never kicks); Clocks scale 30 gets past it but runs at 9 FPS. `profiles/BLUS30997-notes.md` |
| MX vs ATV Reflex | BLUS30321 | `vr-non-working/` + untracked `bin/` copy | no (`max_fps 30`) | not measured | not played | generated 2026-09-28; no notes |
| Uncharted: Drake's Fortune | BCUS98103 (update 01.10) | `vr-non-working/` + untracked `bin/` copies (profile, *Wider view (VR culling)* patch) | yes (community *Unlock FPS*, but the profile runs the game's own limiter at 45: two vblanks a frame at 90 Hz) | **below 72**: 45 locked (44.3-44.9, <0.6% late, boat, 500%); unlocked ceiling 48-57 boat, ~45 in combat (42.5 with Wider view): the game's SPU/PPU work | simulator only (real head poses checked 2026-10-13 with Wider view) | Matt's profile (2026-10-13). Fixed: a VR late-readback crash (fork 90bd7ed59); edge culling (head-driven Wider view; 2.0 also keeps model detail: geometry viewport 16x; ~-6 FPS in combat, 44.7 -> 39). Shadows that moved with the head: remapped (fork 0eb6a05f5, Matt to check in the headset). Open: combat dips under 45; settings and the shadow/lighting patches gave nothing. See notes |
| Final Fantasy X/X-2 HD Remaster | BLUS31211 | none | no: 80-91 flat | not measured | - | RSX-bound flat; not pursued |
| Prince of Persia | BLUS30214 | `vr-non-working/` + untracked `bin/` copies (profile, patch) | yes (fork patch *Unlocked frame rate*: 30 -> vblank rate; game clocks real time) | **90 Hz** (canyon, walking: 89.9, 0.28% late; 120 reaches 116.8), 2026-10-13 | simulator only (real head poses checked 2026-10-13) | new (Matt, 2026-10-13). Edge culling: none to fix (checked to yaw 60; a head-driven Wider view patch was built and tested, not shipped). Open: combat HUD and world scale unchecked. Pause menu fixed (`hud_over_scene`). See notes |
| NiGHTS into dreams... | NPUB30798 (PSN) | `vr-non-working/` + untracked `bin/` copy (hand profile) | **no: frame-locked at 30** (software limiter, 33.3 ms at `0x743fd8`; unlocked it runs ~2x fast) | below 72 (30) | simulator only | new (Matt, 2026-10-13). **Blocked on the frame rate (30) and an RPCS3 rendering fault: tree billboards and the yellow orbs draw on opaque green squares (flat too).** Savestates fail (SPU lock). Hand profile renders in stereo (bare projection `c[24]`, like God of War). See notes |

## Testing in the headset (applies to all)

Start SteamVR and launch the game normally from RPCS3, with no dev environment variables. To try a game
from `vr-non-working/`, copy its profile to `bin/vr_profiles/` and its patch to `bin/patches/`, then enable the
patch in `Manage > Game Patches`. Those patches are not "Enabled By Default". Things only the headset shows:
- world scale: the near plane sets it; use World Scale in the home menu's VR tab;
- whether a 3D HUD plane lands in the HUD box;
- comfort and frame pacing.

---

## DLSS (all games; open issues)

DLSS (NGX, VR multiview, per-eye features) and its frame generation are experimental (fork `framegen` branch; design and
history `10-dlss-test.md`, `8-framegen.md`). State 2026-10-13: DLSS can be turned on live from Off again (the context
and NGX's extensions exist from boot with the SDK; Off costs nothing per draw); a live mode change scales Resolution
Scale by the modes' upscale ratio (the headset eye shape snaps x to 25 % steps and never uses 100 %, so the output can
come out one step smaller: SEGA Rally Off 300 % 2240x2160 -> Performance 150 % 1920x2160); VR > DLSS Sharpening (RCAS,
0..100 = 0..-0.36 stops, default 0). Dev diagnostics: `RPCS3_DLSS=motion|depth|warp`, `RPCS3_DLSS_RSTATS=1` (paired draws
whose motion is not the camera's; programs drawn without a camera matrix), `RPCS3_DLSS_JITTER_SCALE`, `RPCS3_DLSS_JITTER_BITS`.

### Sonic & All-Stars Racing Transformed (BLUS30839): scenery jumps up and down (open)

Matt (headset, 2026-10-13): "certain parts of the scenary (to the right ahead) jump up and down in my latest save state"
(the rock pillars and trees ahead on the right of the track, his crop). "its just a DLSS issue, frame gen is irrevalent.
it happens off & on." Paused it is fine: "it only happens unpaused". State `BLUS30839_1_9` (2026-10-13 20:47), hard link
`vrtest_sonic_matt_dlss_jump`; his config: 385 %, DLSS Quality (2560x2700 -> 3840x4050 per eye), Frame Rate Unlimited.
Unpause with Start (keyboard pad Return) after the load; the race then runs on (a fresh load per check).

Ruled out so far:
- Not frame generation (Matt).
- Not the draw pairing: Sonic builds its geometry on the SPUs, so draws pair by program + element count + order (the
  address key never repeats). `RPCS3_DLSS_RSTATS` over 20 s of the race: ~230 paired draws a frame, **none** with motion
  other than the camera's (Sonic's matrices carry only the camera), so a wrong pairing changes nothing. Pairing only
  unambiguous draws was tried and reverted (no gain in the warp view; the A/B moments differed).
- Not draws without motion: the programs drawn into the scene without a camera matrix are full-screen passes (4-48
  elements, no depth test): `63572270c1a084d2`, `ae412e7fb7d97794`, `8761ccb6b94bd151`, `f780fabddcd9eba2`, `520b713527e8c714`.

- Not the jitter (Matt, headset, `dlss_jitter: 0`: "nope, jitter off didn't fix that either").
- **Not reproduced on the simulator (2026-10-14).** Measured with `RPCS3_DLSS_SEQ` (now with the motion vectors, depth, raw
  motion image and frame number) and `tools/re/mvcheck.py` (each 16x16 block's motion vector against its measured motion in the
  DLSS input; search +-26 px, so blocks moving faster are not judged: `parity3.py` counts only those under 18 px) and
  `kymo.py` (x-t strips, input against output): the vectors match the image to ~1 px (median) and the output strips match the
  input's, at Frame Rate Unlimited (60) and 90. Earlier "wrong vectors" on a near rock were the search window (it moves ~70 px a frame).
- Unpaired draws (~35 % in Sonic, geometry rebuilt on the SPUs) by the previous frame's camera motion are the most accurate:
  per-frame alternation in one run, 42.8 bad blocks a frame against 63.4 for the nearest previous matrix; this frame's motion
  (b83d83a2e) and a vote among paired draws no better. Reverted to the previous frame's (fork be6bd86ad).
- Pairing: the busy program (`...41b3833855`) draws with one matrix a frame (the camera's), so a wrong fallback pairing cannot
  move it; disabling the fallback key is far worse (all draws unpaired).
- At VR 90 the game sits just under 90 with DLSS (the measured-rate fallback switched 7 times in 22 s; none with DLSS off).

Next: needs a reproduction: Matt's headset at his frame rate and head motion; whether it shows with DLAA, at Frame Rate 60,
or with `game_rate_measured: false` (the 90 Hz rate switching).

### MotorStorm: Pacific Rift (BCUS98155): black ground patches with DLSS (worked around)

Matt (headset): random blocky black "shadows" on the ground, "like ambient occlusion", never in the air, with DLSS on
(frame generation not involved). Gone without DLSS's sub-pixel jitter (`RPCS3_DLSS_JITTER_SCALE=0`; Matt: "perfect"):
profile key `dlss_jitter: 0` in `BCUS98155.json` (DLSS still upscales, with less sub-pixel detail). Every scene program
gets the jitter (logged with `RPCS3_DLSS_DEBUG`), and no colour pass on the scene depth escapes it, so the pass that
compares jittered against unjittered depth is not found (the blocky edges suggest a low-resolution pass upsampled
against depth). Earlier MotorStorm fix: depth-only passes jittered through the viewport (`dlss_jitter_viewport`).

## Dragon's Dogma: Dark Arisen (BLUS31155 v01.02)

Notes: `profiles/BLUS31155-notes.md`. Evidence: `evidence/ddda/`. Profile `BLUS31155.json`, patch file
`BLUS31155_patch.yml` (both in `vr-non-working/`, copies untracked in `bin/`).

- **Needs update 01.02** (installed): the community *Unlock FPS* patch (enabled in Matt's `patch_config.yml`) and the
  fork's *Full screen (no letterbox)* patch (on by default) target it.
- **Frame rate:** real-time with Unlock FPS (clocks 1.0x at ~130 FPS). Flat ceiling 120-135 in the prologue; stereo
  89-90 at 100% (RSX ~91%). Profile `max_fps 0`.
- **Letterbox:** the 3D view was 1280x608; the patch sets the game's 0.475 height/width factor to 16:9.
- **Profile:** generated (`row_vectors c[255, 3, 0, 258, 19]`, HUD `c[266]`), `eye_baseline` 6.4 (centimetres,
  estimated). Stereo, yaw and pitch audits clean after two renderer fixes (bone slots:
  `camera_slots_read_directly`; stencil-only clears copied left depth into the right eye).
- **Frame rate at 4K per eye (2026-10-01):** 68-69 at 72 Hz until the RSX thread was profiled: 41% of it waited
  for exact occlusion-query counts (both eyes' GPU work per wait). Profile key `zcull_approximate: true` (ZCULL
  Accuracy "Approximate" while VR renders only): **72.0 FPS, 0% late**, RSX thread 13.9 -> 7.8 ms per frame.
- **Headset (Matt, 2026-10-01): broken.** Boot screens head-locked; performance bad in his save
  (`vrtest_ddda_matt_slow`). See "First headset test" above.
- **2026-10-03 (simulator, multiview build `d6acea81e`), to recheck in the headset:** Matt's save now holds
  **90 Hz** at 300% on multiview (90.0 FPS, 0% late; 120 averages 110.7); two-draw holds 72 (90 averages 87.2).
  The boot screens (notices, Capcom, title, main menu) are world-fixed: each moves across the view when the head
  turns 29 degrees (`evidence/ddda/2026-10-03-boot-screens-yaw0-vs-yaw05.jpg`). Nothing head-locked seen.
- **Headset (Matt, 2026-10-03): WIP.** Lots of graphics render errors; the text layer is cut off when the head turns; a phantom graphics layer shows when the head turns. No savestate or screenshots yet; not
  investigated.
- **2026-10-04:** new patch *Wider view (VR culling)* (FOV x2.0): the culled distant scenery seen past the game's
  55-degree view when the head turns (a likely cause of the "phantom layer") is drawn; Matt's save still 90 Hz.
- **Open:** the headset errors above; open-world frame rate; outdoor flares with `zcull_approximate` (any visible
  pixel reports as fully visible); NPC name tags stay in the HUD box; world scale and HUD in the headset.

## Ratchet & Clank Collection (BCUS98282, disc 01.00)

Notes: `profiles/BCUS98282-notes.md`. Evidence: `evidence/ratchet/`. All three games tried (each has an executable
profile `BCUS98282.rc1/rc2/rc3.ppu.json`).

- **Frame rate:** each game keeps a constant timing block (1.0, 1/60, 1/3600, 1/216000...); the executable profiles
  drive it with `game_frame_time_f32` / `_sq_` / `_cube_`, `max_fps 0`. Run speed at 90 equals 60 in all three.
- **Stereo frame rate (2026-10-01):** the RSX thread was the bottleneck (cycle-exact 13.2 ms of a 15 ms frame in
  R&C 1 at 72 Hz; the earlier 4.2 ms figure came from an undercounting timer). After the renderer work (Gate 6 entry
  in `4-next-steps.md`): R&C 1 **72 Hz** (10.7-10.8 ms, 71.5 FPS, 0% late), R&C 3 **72 Hz** (9.2 ms), R&C 2 **120 Hz**
  in Matt's `vrtest_rc2_aranos_hall` (the hangar state is too light to show anything).
- **Profile:** generated, `column_vectors c[0]`, HUD `c[4]`, metres, 100% coverage; stereo and yaw audits clean;
  HUD sprites boxed in the headset view via `passthrough_hud` + `hud_programs`.
- **Headset (Matt, 2026-10-01): R&C 1 unplayable.** Gameplay on a fixed 2D window with depth popping as the head
  moves; loader and R&C 1 menus head-locked. See "First headset test" above.
- **Open:** R&C 1 has little margin at 72 (busier scenes may drop); R&C 2 outdoor levels unmeasured; R&C 1
  pause-menu button frames use their own perspective camera and turn with the head.

## The Darkness (BLUS30035, disc 01.03)

Notes: `profiles/BLUS30035-notes.md`. Evidence: `evidence/darkness/`.

- **Frame rate:** community *60 FPS* patch applies to the disc (01.03); real-time at 180; stereo 75-80.
- **Profile:** generated (`column_vectors c[0]`, 100% coverage).
- **Blocker:** any stereo shear breaks the multi-pass lighting (red light leaking, dark bands), even in a single
  sheared view. Needs a stationary scene to bisect (the opening is scripted and animated).
- **Headset (Matt, 2026-10-01): parked.** The black screen after the splash is a long black stretch of the intro
  (waited out, its videos are missing), not a hang. Performance is terrible: under 60 FPS in Matt's savestate
  `vrtest_darkness_matt_slow`. Not worth continuing for now.

## Dynasty Warriors 6 Empires (BLUS30306, disc 01.00)

Notes: `profiles/BLUS30306-notes.md`. Evidence: `evidence/dw6e/`. Generated profile, stereo and yaw audit clean,
180 FPS flat in battle, but frame-locked (3.4x at 180, no dt found): runs at 60 with reprojection for now.

- **2026-10-04:** tried DW Gundam's fix (a step constant passed to the battle update): clocks at Vblank 120 run 1.3-1.8x,
  but the one traced (`0x30d1abb0`, 0.95x at 60, 1.77x at 120) is an effect parameter (vector store at `0x2ae068`), not
  the logic step. Still at 60.

## Puppeteer (BCUS98227, disc 01.00)

Notes: `profiles/BCUS98227-notes.md`. Native 30, frame-locked; the game's frame time (`0x98ebec`) is now driven by
the profile and gives near-real-time movement at 90 FPS. Still flips every 2 vblanks: needs a flip-interval patch.
Generated profile not yet checked in stereo.
- **Headset (Matt, 2026-10-01): barely works.** Trails of graphics everywhere and very dark; in the intro a light
  moves with the head. Matt's savestate with the trails: `vrtest_puppeteer_matt_trails` (`BCUS98227_1_1`, 17:59). In
  the game proper it kind of works, but the world looks far away and small (world scale / `eye_baseline`). Leads,
  unverified: trails = something not cleared per eye or an older frame reprojected with a stale pose (the frame goes
  through main memory for SPU post, see `texture_redirects`); darkness = the skipped SPU post (tone map/MLAA) in VR;
  the light = a screen-space light/flare not getting the head transform.

## Jak and Daxter Collection (BCUS98281, disc 01.00)

Notes: `profiles/BCUS98281-notes.md`. Evidence: `evidence/jak/`. Jak 1 (170-180 flat) and Jak II (~130 flat) are
real-time at any rate, so no patch; generated per-executable profiles, yaw audits coherent apart from Jak 1's indoor
sparkles. Jak 3 not started.
- **Headset, Jak 1 (Matt, 2026-10-01): broken.** All HUD elements tied to the face (the profile has no HUD block).
  Stereo wrong on lots of objects: at the wrong depth, uncomfortable (objects whose matrices the camera classification
  misses, so they get no or the wrong eye offset). Performs well, but **everything looks 1.5x speed at 90 FPS**: the
  desktop "real-time" check (float clocks 1.00x, the same walk displacement at 60 and 180) was wrong or measured the
  wrong thing; what the eye sees (animations, effects, NPCs, camera) runs per frame. Jak II's "real-time" rests on
  the same test and is suspect too.

- **2026-10-04 later: Jak II real-time at the headset rate.** Jak HD runs the PS2 code recompiled, PS2 RAM little-endian at
  `0x20000000`; Jak II's 13 GOAL clocks sit at `0x20401fc0 + n x 0x60` and add the display's time-factor (5.0, at
  `0x20401f7c`) each frame. Fork patch *Frame rate follows VR (Jak II)* (`BCUS98281_patch.yml`, on by default): the
  recompiled set-time-ratios (`0x317db0`) loads time-factor from `0x16ba300`, which the profile sets to 300 / fps
  (`game_vblank_frames_f32` with `scale` 5). Measured: 256 instead of 515 ticks/s at 120 FPS; a walk timeline at 120
  matches 60. VR 72 Hz sustained at 300% (90 averages 86). The 60 cap is lifted again. Jak 1 (display at `0x2032fe58`,
  set-time-ratios `0x1ff668`) also needs its ratio argument scaled, and that warped Jak to a checkpoint: reverted.
- **2026-10-04:** Jak II is frame-locked too (idle/walk timeline from `vrtest_jak2_prison`: at Vblank 120 Jak is twice as
  far along at the same wall times). `BCUS98281.jak2.json` now `max_fps 60` / `default_fps 60` (fork 28687269a), verified
  60.0 FPS on the simulator at 90 Hz. Re-measured on the multiview build: Jak II renders 90 Hz sustained (it was 72),
  Jak 3 57 FPS at 72 (was ~43). Looked for OpenGOAL's clock fields (seconds-per-frame 1/60 beside frames-per-second 60,
  time-factor 5.0) in Jak II's memory to drive the step from the profile: not found (the HD port's layout differs).

## Anarchy Reigns (BLUS30632, disc 01.00)

Notes: `profiles/BLUS30632-notes.md`. Evidence: `evidence/anarchy/`. Fork patch *Frame rate follows VR* (instead of
the community 60 FPS) routes the characters' fixed 1/30 step through a word the profile sets: 90 FPS at Vblank 180,
walk and run speed equal to 60 FPS (1.5x without it). Scene at 1024x720; generated profile (after generator fixes)
`row_vectors [4, 24]`, HUD `c[54]` after the shader. Stereo, audit and the fake-headset HUD box are right in
Practice. Open: campaign, HUD sprite timers at 3x, headset run.
- **Headset (Matt, 2026-10-01): parked.** Splash screens and the intro are tied to the head, with HUD elements
  culled by depth; the intro is very long and cannot be skipped. In gameplay: bad performance and lots of graphics
  issues (the desktop checks only covered Training > Practice). Matt's savestate at the start of gameplay:
  `vrtest_anarchy_matt_gameplay` (`BLUS30632_1_2`, 18:36); also `vrtest_anarchy_matt_1834` (`_1_1`).
- **2026-10-03 (simulator, multiview): still parked, blocked before stereo.** Gameplay in Matt's save at 300%:
  flat 60.2 FPS, multiview 51.8-61, two-draw 46.7 (72 needed): the game's own CPU work holds it near 60 (the RSX
  thread idles ~35%). A once-a-frame GPU readback (render targets sharing pages with the ucode) costs the paused
  popup screen; Force CPU Blit removes it there but is slower in gameplay. The headset
  picture in gameplay has large dark-grey wedges over the ground (notes, `evidence/anarchy/2026-10-03-*`).

## Killzone 2 (BCUS98116)

**2026-10-07: both eyes show the same scene** (`tools/re/eyesame.py` on the 10-04 regression shot: best shift 0, residual 2.5;
only the HUD differs). Probably the Dragon Age II case (the scene comes back from a main-memory copy the SPUs process):
check the inspector blit notes and use `texture_redirects` (`"to": "camera"` covers blits since fork 7c91de0b5).

Notes: `profiles/BCUS98116-notes.md`. Evidence: `evidence/killzone2/`. Fork d12f50a6e.

- **Config:** Write Color Buffers and Read Color Buffers on. Without them the loading screens are garbage
  and look stuck.
- **Frame rate:** real-time game, so no speed patch is needed. Native 30. The ceiling flat is 86-89 at
  vblank 180 (RSX thread ~85%), and stereo is ~60 on the headset path (RSX saturated). The profile defaults
  to 45 (`vblanks_per_frame 2`, vblank 90); 60 and 90 are selectable but will not hold in combat.
- **Profile:** generated in the carrier walk: `row_vectors`, camera `c[0, 5, 1]` (base varies:
  `require_camera_aspect`), `linked_camera_blocks [25]`, HUD `c[8]`, metres. It covers 85% of depth-tested
  draws.
- **Open:**
  - 7 uncovered programs to classify; pitch audit; a combat scene (Corinth River landing) for coverage and
    frame rate.
  - HUD `c[8]` unchecked.
  - Translucent slab in the rotated eye of the yaw audit.
  - One occlusion-query hang in 5 boots (`get_occlusion_query_result`); log
    `%TEMP%\rpcs3-vrprofile\kz2_query_hang1.log`.
  - Movies at the raised vblank: does it need `video_vblank_rate: 60`, as Killzone HD did?
- **2026-10-04:** new regression state `vrtest_kz2_carrier` (Campaign > Continue, the carrier walk; made with a temporary
  copy of Matt's config plus Compatible Savestate Mode). Multiview build, 300%: 63.1 FPS at 72 Hz (Vblank 144), 64.6 at
  90; RSX thread 15.5 ms/frame, so still RSX-bound below 72.
- **Files:** `vr-non-working/vr_profiles/BCUS98116.json` (moved out of `bin/` for vr7), untracked copy in `bin/`.

## Killzone 3 (BCUS98234, disc 01.00)

**Started 2026-10-17; frame rate passes.** Flat 120.0 FPS at vblank 240 (RSX 8.2 ms); stereo on the simulator, 300%,
DLSS off: **113 FPS** walking (1% low 64). Community *Disable MLAA* patch on. Generated profile (`c[0]`, linked
`c[25]`, HUD `c[8]`, metres). The opening mission's Helghast helmet visor (a screen-space refraction box in the
middle of the headset view) is hidden in VR. Open: whether the first-person gun follows the head (it has its own
camera at the origin), 15 scaled draws on the game camera, the helmet HUD markings, a normal mission. Notes:
`profiles/BCUS98234-notes.md`, savestate `bin/savestates/BCUS98234/kz3_helghan_base`.

## Gran Turismo 5 (BCUS98114, XL Edition, US; disc 01.00 since 2026-10-03, was v02.11)

**VR 45 game speed (Matt, headset, 2026-10-13: "GT5 doesnt work at 45fps", slow motion, audio stutter; then with a 90 Hz vblank "now it runs too quickly. Compare it to a run at 60fps"): fixed 2026-10-14 (fork 5e10624bf, profile `vblank_steps`), Matt to check in the headset.** GT5 steps its race once per vblank: the physics by the frame-time word, plus a race tick of a fixed 1/60 s (`0x28fd18`: tick count x 1/60). The new key keeps a 60 Hz vblank below 60 FPS (the limiter holds 45), writes 1/60 to the frame-time words and skips the measured-rate fallback. Measured on the simulator with memory dumps of `gt5_busy_race_2_17` (object speeds per wall second against a 60 FPS run; a 60-vs-60 control agrees at 1.00 for ~5,500 objects): 45 now 1.00x (5,197 of 6,263 objects, tick clock 1.00); before 0.75x at a 45 Hz vblank and 1.5-2x at a 90 Hz vblank. Frame generation (90 -> 45) unchanged: a generated pair on 225 of 451 headset frames, none repeated. Audio not checked (Null audio).

**Real 90 (Matt: "Make 90 real work"): fixed 2026-10-14 (fork e4254e45b + the wheel commit), headset check pending.** On
disc 01.00 three things assumed 60 steps a second, each found by measurement against a 60 FPS run (a 60-vs-60 control is
exact, 1.000; `tools/re/xformspeed.py`, `gt5_dump3.sh`, `bisect.sh`/`bisect2.sh`):
1. The vehicle physics step: the constant `0x185f64c` (1/60 in writable data; `0x56a1ac` sets each car's physics object to
   scale x it). Found by poking all 42 words of 1/60 to 1/120 at 60 FPS and bisecting on the AI cars' speed. Profile
   `game_frame_time_f32`. Cars at 90: 1.6-2.3x -> 1.00-1.07x.
2. The race clock: +1 tick of 1/60 per step (`0x40e420`). Patch *Race ticks follow the frame time*. 1.5x -> 1.00x.
3. The wheel rotation rate: the car-update layer computes (angle - previous) x 60.0 (`0x32ff6c`, `0x330050`; the word
   `0x184cb98`), so the wheels spun at 2/3 at 90 (per-wheel counters 0.60-0.66x; found by poking all 88 words of 60.0 to
   120 and bisecting on wheel revolutions per metre). Profile `game_refresh_rate_f32`. 0.96-1.00x at 90, 0.97-0.99x at 45.
The player: identical to 60 under full throttle on the Indy oval (59/58/59/60/61 vs 61/58/59/60/61 km/h at 4-20 s) and in
coasting decay (0.32-0.34 over 5 s); its 10 % lower speed in the busy state is a resume transient (same decay after it).
Engine-RPM fields in the physics object ~1.05x at 90. Not it: the 60.0 companion `0x185f650` (reached the physics objects,
changed nothing), the other 1/60 and 60.0 words, a 90 Hz vblank at 45 FPS (the game then steps only ~54-60 a second).
Frame generation 2x/3x at 90 on the simulator: a generated pair on 225/301 of 451 headset frames, 0 repeats; Matt's 150
repeats and "nothing happens when I activate frame gen" not reproduced. His log showed frame generation switching itself
off 150 ms after on: `VKGSRenderDLSS.cpp` disables it when the live setting reads false, so the 2D settings dialog saving
its stale value (changing Frame Rate there) is the likely cause; toggle it in one place. Audio unchecked (Null).
Open: a few car fields still off at 90 (`car+0x1080..` 1.3x, `+0x1a0` ~3x, unknown quantities).

**Back in for vr10 (2026-10-12, fork e0ecd0d65, zip rpcs3-v0.0.43-vr10-e0ecd0d6): works from a fresh install (SPU async
compile, display-area fixes, no resolution switch at race starts; details in the notes file). Awaiting Matt's test.
Open: force display area 1.0 in VR (Matt).**

**Pulled from vr9 (Matt, 2026-10-12: "stop. Just remove GT5 from the release."; fork 9fcf9ddbf moved the profile and
patch back to `vr-non-working/`).** Matt's report on the vr9 test folder (fresh install, 7d93c188): "on first boot it hangs
on black screen in the menu. On a restart the menu text is all garbled, and running a race hangs on the race flyby."
Also "for some reason in test we get asked to size the display every time we run" (no GT5 save in that folder, so the
first-run welcome and display-size screens show each boot). Found so far: the welcome text ("Welcome to the world of
Gran Turismo.") is right with VR off and garbled in VR; it only shows before the first save, so the dev setup (which
has the save `BCUS98114-GAME`) never shows it. Race-start hang also at 300%, cause unknown. To do: reproduce all three
in a fresh install (no GT5 save, no game data), fix, then re-approve.

Notes: `profiles/BCUS98114-notes.md` (the most detailed). Evidence: `evidence/gt5/`. Parked at vr5.

- **Boot hang (Matt, 2026-10-10: "GT5 doesn't load"; ~1 boot in 3 died after "Accessing game data"): fixed 2026-10-11
  night (fork 81a1335e2, simulator).** Framebuffers were destroyed while queued GPU work still used them (VR keeps more
  frames queued than upstream assumes); idle framebuffers now go through the resource manager. Interleaved disc boots:
  0/10 hung with the fix, 4/10 without. Generic (every game). Notes "2026-10-11 night: boot hang fixed".
- **Race savestate loads lost the GPU device about half the time (`2_17`, 2026-10-11 morning): worked around (fork
  9db719f39).** The desktop mirror's crop of GT5's large display buffer is off by default (crop on 5/8 loads lost, off
  0/8); the desktop window now shows each eye's whole surface with the picture in its top-left part (headset unchanged).
  Cause inside the crop path not found. Notes "2026-10-11 morning".
- **Rarer load failure ~2 s in (~1 in 8: a crash inside NVIDIA's driver, or a lost device): fixed (fork 1ec5dbc9f),**
  **12/12 loads since.** The desktop swapchain rebuild waited for the device while the OpenXR thread used its own queue
  (and created swapchains) unsynchronised. Also behind a Sonic "no present" load. Notes "early-load failure".

- **Rain follows the head (Matt, headset, 2026-10-10): fixed 2026-10-11 night (simulator), headset recheck.** The
  spray/mist particles use the camera matrix from `c[4..7]`; profile `camera_blocks: [0, 4]` (was `[0]`). The car ahead
  is now hidden in spray as in flat; a sunny race state is pixel-identical. Notes "2026-10-11 night".

- **2026-10-09 night: RSX-thread work on Matt's paused busy scene (2_17, nine cars ahead; simulator, 400% stereo,
  multiview): 19.2 -> 13.5 ms a frame, 52 -> 74 FPS.** Code (generic, fork commits 5fa168307..7820e2159): fragment
  programs hashed in their analysis pass and compared by two hashes, a lookup cache in front of the pipeline map, the
  FIFO's cached-word fetch inline, a vertex program analysis cache, the texture cache keeps sections whose edge page
  another writer shares (hashed instead of dropped: GT5 re-uploaded ~60 car textures a frame), VR per-draw trims and
  an eye-constants fast path. Profile: `shared_frame_targets` (two of the six 256x256 cube faces refreshed a frame),
  `camera_block_cache`, distance-based car tiers (full under 20 m, 85% to 40 m, 70% beyond), the mirror pass every other frame. Config (Matt's go-ahead): `RSX FIFO Fetch Accuracy: Fast` (-0.35 ms). Regression over all 42 states: nothing worse. Tried, no gain: a
  texture-lookup memo, skipping the per-draw backend interrupt, SPURS/loop-detection/vertex-cache settings, one cube
  face a frame. Headset check pending: car paint reflections may lag up to 2 frames. Details and the LOD leads
  (reflection metadata naming `EnvironmentSetting::LOD` members, script natives `setStaticLOD`/`changeLodCar`) in the notes.

- **2026-10-05 night: frame rate (simulator, Matt's config at 400% stereo, 90 Hz).** Races hold 90: the Indy race
  start with the pack ahead 83-89 then 90 (was 60-65), a tree-lined track 90 locked (was 78). The pre-race grid runs
  at 90 (was 17). Fixes: readbacks the game takes every frame answered late or skipped (`late_readback_*`,
  `skip_readback_sections`), small passes left unscaled (`min_scalable_dimension` 512), the pre-race views at a
  reduced scale (`reduced_scale_frames`) and at full frame rate (new patch). New VR setting **Cinematic Scenes**:
  Lower Resolution / Fixed Screen / Full Quality for the pre-race views. The GPU is not the limit (5090 at 4-17%);
  what is left is the RSX thread at ~1,300 draws (grid -> race transition 66-80 for ~8 s). Details: notes,
  "2026-10-05 night". **Needs Matt's headset check.**

- **2026-10-03: Matt moved GT5 to version 01.00** (the 02.11 data folder replaced). The profile now targets 01.00:
  the 1/59.94 frame step is in writable data there, two TOC words read by the two step getters (`0x184680c` via
  `0x17d288`, the fixed-step loop `0x1819fc`; `0x184acc0` via `0x281c24`), and `game_frame_time_f32` writes both
  every frame (logged `0.016683 -> 0.016667 s` at 60). No code patch on 01.00 (the 02.11 entry stays; its hash no
  longer matches). Not yet measured at 90 (Matt testing). Executable dump `tools/re/elf/BCUS98114-0100.elf`,
  PPU hash `PPU-a5e547ce3ce25092ac6cae85631f50ba5d9ea914`. **The regression savestate `vrtest_gt5_race_start` no
  longer boots** (it records the 02.11 executable): it needs a new race savestate on 01.00.
- **Multiview (Matt, 2026-10-03): about 35% faster in races** than the two-draw renderer.
- **Arcade menu cards: fixed 2026-10-05 on the simulator (real head pose, turned and tilted), recheck in the headset.** Was (Matt, headset, 2026-10-03): The stacked mode images cut through each
  other in the HUD box; profile key `hud_exact_depth_programs` (the game's exact depth for the card program) made the
  selected card come to the front and change with left/right. **Still open:** turning the HMD sideways or tilting it
  up/down, parts of the card art are still obscured: the front card is cut off along a diagonal edge on its right
  (`evidence/gt5/2026-10-03-arcade-cards-matt-headset-still-cut.png`, Time Trial selected). Notes for details.
- **Rear-view mirror: fixed 2026-10-05 on the simulator (fixed-yaw test), recheck in the headset.** Was (Matt, headset, 2026-10-03): In a race the mirror image resizes and is culled
  depending on the HMD angle (`evidence/gt5/2026-10-03-mirror-matt-headset-cut.png`: the mirror's scene does not fill
  its frame and is cut off at the right). The mirror is a camera draw into the HUD box (`subviewport_cameras_in_box`).

- **Frame rate:** patch "Frame rate follows VR" redirects the fixed step (`0x14017f8`) to bss `0x1948440`,
  which the profile's `game_frame_time_f32` sets to 1/fps. Physics, sim and the race timer run at 1.0x at 60
  and 0.99x at 90.
- **Headset work done:** HUD, menus and the mirror are in the world-fixed box. This added four generic
  `screen_space` options: `hud_display_buffers_only`, `hud_box_after_shader`, `output_pixel_draws_not_hud`
  and `subviewport_cameras_in_box`. Right-eye texture rebuilds went from 172 to 0 a frame. Car shadows,
  menu trails and mirror edges are fixed.
- **Config:** Disable ZCull Occlusion Queries is on in Matt's config. **Resolution Scale 200% freezes
  loading a race** (garbage fragment program, also with VR off). Any other scale works; 300% is verified.
- **Fixed 2026-10-01 (desktop):** red/green car shadows (the shadow program keeps fog densities in the
  camera-position slot `c[467]`; the renderer now checks the slot holds the eye point), desktop mirror crop.
- **2026-10-05 (Matt, headset):** cars beside the player are culled by the game's SPU code (parked; notes); with many
  cars in view ~48 FPS at 90 (RSX thread bound, ~135 draws per car at any distance; hiding shadows/reflections
  +2.5 FPS, texture re-upload fixes no gain; notes "2026-10-05 afternoon"). Savestate loads show multicoloured
  car paint (open).
- **2026-10-05 late afternoon:** profile `car_draw_limit` (fork 51ff40a65): nearest 2 cars full, cars 3-6 85%, the
  rest 70% of their geometry (largest pieces); 2_13 ~48 -> ~64 FPS with the first version. Matt: works well. Next:
  main menu (driver walking out differs between eyes; an overlay below in the wrong place when looking down).
- **2026-10-05 evening:** main menu and pre-race fly-by on the fixed screen (`screen_frame_draws`), `min_scalable_dimension`
  511 (the 512 value ghosted the menu's depth-of-field layer); fork 72aaa988b. Matt: good. Notes "2026-10-05 evening".
- **TODO: find GT5's car LOD switch and move it closer** (the remaining big frame-rate lever in busy races; 2_17 runs at
  ~50 FPS with the car tiers, the RSX thread limited by draws and vertex uploads). The game draws each car with its
  full model (110-165+ draws) out to ~75 m and switches to a complete far model of ~10 draws (glass included) from
  ~95 m. Using the far model for cars 3+ would cut far more than `car_draw_limit` without holes. Not found yet: the
  tables [16,76,88] 0x184057c, [50,80,350] 0x185fe38, [60.9,80.54,244.75] 0x18c3a80, [4.5,11.75,13.2,79] 0x190be50 had
  no effect (written before unpausing). The switch may be screen-size based (FOV and distance) or decided on the SPUs.
  Next: find where a car's model level is stored (per-car state that changes between the full and far model as a car
  passes ~85 m in a running race: memory diff or write watch), then its threshold. Notes: "2026-10-05 late afternoon",
  "2026-10-05 night".
  Test state: `savestates/BCUS98114/gt5_busy_race_2_17` (hard link of Matt's 2_17: paused with his pad connected,
  nine cars ahead within 58 m, ~50 FPS).
- **Open (from the notes):**
  1. Arcade menu cards: improved 2026-10-03 (exact depth for the card program), still obscured when the HMD turns or
     tilts (Matt, headset). The rear-view mirror image also resizes and is culled with the HMD angle.
  2. Race-start frame rate: the RSX thread is CPU-bound even flat (~42 flat, ~30 stereo). Needs multiview.
- **Headset (Matt, 2026-10-01, on the build with the RSX-thread optimisations): ~40 FPS. Target: at least 60**
  (the game's own rate; below that it does not work). The regression run's "90 Hz (race start)" was measured from the
  grid savestate after a 40 s settle and does not reflect racing. Next: measure the RSX thread (cycle-exact, frame
  stats) in a race at 60 Hz flat and stereo, profile with `RPCS3_RSX_SAMPLE=3`, and check how much of today's per-draw
  gain GT5 got; a savestate mid-race from Matt would make the measurement repeatable.
  3. Intermittent upside-down menu (not seen since the display-buffer size fix).
  4. Cockpit, replay and garage not audited; the shadow and mirror fixes not yet seen in the headset.

## MotorStorm: Pacific Rift (BCUS98155 v01.00)

**Shipped in vr9 (2026-10-12).** Open items below are its known issues.

Notes: `profiles/BCUS98155-notes.md`. Evidence: `evidence/motorstorm/`. Moved to `vr-non-working/` at vr6.

- **Sky smearing on head turns (Matt, headset, 2026-10-10): fixed on the simulator, headset recheck.** The game never
  clears colour; turned, terrain outside its ~87-degree view was culled and the area kept older frames. Profile key
  `clear_view_targets` (fork c9aeb8786) clears it each frame; patch *Wider view (VR culling)* (head-driven
  `culling_scale_f32` tangent_x, word 0x145fe00) draws it. State `BCUS98155_1_3`; shots `evidence/motorstorm/2026-10-10-*`.
  Frame-rate cost not measured yet (MotorStorm needs multiview for 72).

- **Screen shakes left-right on boost (Matt, headset, 2026-10-10): fixed on the simulator, headset recheck.** The chase
  view hangs under a "Vehicle shake platform" node whose range the game raises while boosting (y 0.003 at rest to ~1.0);
  its offset flipped every frame. Patch *Disable camera shake (VR)* stores a zero range (0x37384c/0x373850), so the
  offset stays 0: boosting, the view no longer alternates (yaw 0.1-0.26 deg frame to frame before, ~0.01 after, as unboosted).
  A first patch zeroed the other shake node ("Shake the camera", a slow speed wobble); Matt: still shook; reverted.
- **LOD changes on trees as you approach (Matt, 2026-10-10): option added, headset check.** New VR setting *Highest Detail
  Models* (home menu and settings dialog, Game section, on by default): patch *Highest detail models (VR option)* +
  profile `option_f32` hold the game's lodBias at -8. ~1.14M vertices instead of ~0.65M on a paused race frame; RSX thread
  and GPU load unchanged within run-to-run noise (paused-frame A/B per bias level), so no mid level was added.
- **Race start in the 40s with the field ahead (Matt, headset, 2026-10-10): fixed, Matt-tested.** RSX-bound (14-16 ms a
  frame at the grid; ~45% of draws are the shadow map). New VR settings (Game section, live, default on): *Simpler Other
  Vehicles* (vehicle LOD floor 2, cullThreshold x3) and *Fewer Shadows* (shadowCullThreshold x3 for all groups but the
  player). Matt: both off 40s, vehicles on 50s, both on 70s; no visible difference. Highest Detail Models no longer
  covers other vehicles.

- **Frame rate:** fork patch file with the community unlocked frame rate (60 FPS + Variable FPS). It gives
  90 FPS with clocks at 1.00x, and also turns dynamic resolution and motion blur off. Profile `max_fps 0`.
  Needs Write Color Buffers.
- **Picture:** no stereo-vs-flat difference found on the desktop.
- **Blocker:** frame rate at a race start with the pack in view. At 100%, flat runs ~86 and stereo ~72, then
  85-90. The headset path at 300% runs 35-53 (GPU 68%). The RSX thread is already saturated flat, and
  stereo adds ~1.7 us per draw on 4,500-5,000 draws. Most of that is driver submission for the right eye,
  which multiview would remove. 200% is worth trying in the headset.
- **Multiview (2026-10-03, simulator, 300%, `vrtest_mspr_race` holding R2):** 72 Hz sustained (71.9 FPS, 0.17%
  late; the start window with the pack in view 69.6 FPS, 0.36%). Two-draw on the same build: 69.1 FPS, start
  window 62.9 FPS with 7.9% late. 90 Hz: 87.1 FPS, 0.14% late, but the start window 80.9 FPS and 1.08% late.
  New regression state `vrtest_mspr_race` (countdown "1"; route in `7-vr-regression.md`).
- **Matt's four bugs of 2026-10-09 (state `BCUS98155_1_2` = `vrtest_mspr_matt_bugs`): 1-3 fixed (fork 800c13c3a),
  simulator-checked at yaw 0, +-20, pitch 10 on fresh loads; headset recheck.**
  1. Pause menu black bars moving with the head: the bars (`f7810dbda0d9eba2`) pass clip-space positions through with
     no matrix and were sheared as scene geometry; `screen_space.hud_programs` puts them in the HUD box with the text.
  2./3. Grey box below the car, with a shadow sliding in it on head turns: the vehicle shadow pass `05da43f83668a0ad`
     rebuilds positions from depth with the game's camera; `depth_remap_programs` fixes it (shadow under the bike in
     both eyes, where flat puts it).
  4. Tree shadows aliased: not changed. The shadow atlas (1024x2048, two cascades) is already scaled by the Resolution
     Scale like any target, so VR matches flat at the same scale; the stepped edges at a distance are the game's
     shadow-map resolution. Only a game patch (bigger atlas or tighter cascades) would help.

## Blur (BLUS30295 v01.00)

Notes: `profiles/BLUS30295-notes.md`. Evidence: `evidence/blur/`.

- **Reach gameplay:** Career > Proving Grounds > Barcelona Oval. Needs Write Color Buffers (black screen
  otherwise).
- **Frame rate:** patch "Unlocked frame rate (follows Vblank Rate)" (`0x349f80`: one vblank per flip). Game
  time is wall-clock based, so `match_headset_refresh_rate` suits it. 80-84 mono, 45-50 stereo at 90 (100%).
- **HUD:** 3D planes at a fixed depth (`w = z + 42.65`). They go into the HUD box on the headset path only
  (`screen_space.depth_offset_projection`). The rear-view mirror (320x180) keeps the game camera
  (`game_camera_target_widths`).
- **Open:**
  - The car's shadow can stay where the unrotated view had it under big head turns (probably the deferred
    pass).
  - The mirror's motion blur streaks in the right eye.
  - Headset run not done.

## Need for Speed Most Wanted (2012) (BLUS31010 v01.00)

Notes: `profiles/BLUS31010-notes.md`. Evidence: `evidence/nfsmw/`.

- **Reach gameplay:** title > Start > decline PSN; the intro hands over to driving.
- **Frame rate** (the hardest so far): the patch "Frame rate 90 FPS (set Vblank Rate 90)", with 60, 72, 80
  and 120 entries. It is fixed per rate, so keep the headset at the matching rate and do not use
  `match_headset_refresh_rate`. The game has three 30 FPS mechanisms:
  1. a 2-vblank flip gate through RSX labels (`0x7400cc` writes 1);
  2. the game's timer pacer `0x635a20`, which spins on `mftb` (`0x678cc` N = 1, period `0x667f4` =
     60000/rate), found with `RPCS3_PPU_SAMPLE` (83% of the main thread);
  3. a fixed 1/60 s sim step at `frame+0x9c`, plus catch-up `+0xa0` and the accumulator. Loads `0x69658`,
     `0x69644` and `0x67960` branch to a code cave at `0xa5a000` that loads 1/rate and 2/rate.
- **Profile:** `column_vectors_xyw`, camera `c[212..214]`; the 3D HUD uses `depth_offset_projection` as Blur
  does.
- **Open:**
  - 90 FPS with real-time clocks was confirmed on the title screen only; the in-race check was interrupted.
    If driving feels 1.5x fast, disable the patch.
  - A dark region near the car in the audit's rotated eye (a screen-space shadow or decal pass?).
  - Headset run not done.

## inFamous 2 (BCUS98125, disc 02.00 / APP_VER 01.00)

Notes: `profiles/BCUS98125-notes.md`. Evidence: `evidence/infamous2/`.

- **Reach gameplay:** New Game (~2.5 min intro).
- **Frame rate:** no patch needed; real-time. 52-72 in stereo at 90 (100%).
- **Profile:** overlapping camera bases (`require_camera_aspect`). The final composite uses
  `rotation_only_passthrough` (no depth test, no translation).
- **Open:**
  - A layer the SPUs process from a copy of the frame is correct for the left eye only: a slight ghost in
    the right eye.
  - Headset run not done.

## Metal Gear Solid 4 (BLUS30109, disc 02.00)

Notes: `profiles/BLUS30109-notes.md`. Evidence: `evidence/mgs4/`.

- **Reach gameplay:** Virtual Range (quick), or New Game / Act 1. Set `LLVM Precompilation` off, or the first
  boot compiles for 20+ minutes.
- **Frame rate:** patch "Frame rate follows Vblank Rate" (`0xfa33c`: frame wait `0xdb720(n)`, n = 1).
  Real-time. 90 mono in the Virtual Range; ~35 stereo in Act 1.
- **Profile:** anamorphic 1024x768 targets (`camera_target_aspect` 1.33333), camera-relative draws through
  `[0, 1, 2, 7]`, millimetres (`eye_baseline` 64, least certain). The HUD is on the final 1280x720 target.
- **Open:**
  - `_sys_lwmutex_lock CELL_ESRCH` ~8 min into Act 1, once followed by a black screen (during memory dumps).
    Not yet checked with the patch off.
  - Headset run not done.

## inFamous (BCUS98119, disc 02.00 / APP_VER 01.00)

Notes: `profiles/BCUS98119-notes.md`. Evidence: `evidence/infamous/`.

- **Reach gameplay:** Continue from the title.
- **Frame rate:** no patch needed (uncapped, real-time). Load-bound at ~55 mono; ~25 stereo (13,500 draws
  a frame). Too slow for VR without multiview.
- **Open:** world scale (centimetres, `eye_baseline` 6.4) not checked against a known size; headset run.

## Split/Second (BLUS30300)

Notes: `profiles/BLUS30300-notes.md`. Evidence: `evidence/splitsecond/`.

- **Frame rate:** hand-made patch with Refresh Rate 90 and `config_BLUS30300.yml` Vblank Rate 90. It uses
  Pure's PSGL swap-interval sites plus the game's own dt (one 1/60 s tick per vblank at `0x509a4`, patched to
  `ticks / Refresh Rate`). Game time is 1.00x at 90/90. Vblank and Refresh Rate must match, and Refresh Rate
  is fixed at boot.
- **Profile:** made by the automatic generator.
- **Open:** a race frame costs 17-25 ms (emulator load), so races run at 30 FPS at 90 Hz. Headset run not done.

## God of War III (BCUS98111)

**Open, Matt (2026-10-17, headset):** *"God of war 3 frame rate is terrible. Its too low in the first fight when you start
the game, and also has really bad hitches causing 1% lows to be even worse."* (The first fight after a new game.) Not
investigated yet.

**Matt's headset report (2026-10-15 afternoon), open, in his words:** *"God of War 3 is terrible. The menu screens are
doubled and flicker, the game is in a slanted window not full screen which tilts with my head."* So in the headset:
(1) menus doubled and flickering; (2) gameplay shown in a slanted window, not full screen, that tilts with the head
(the screen-frame / fixed-screen detection or the camera blocks are not taking the game view as the 3D view on his
headset). None of this showed on the simulator checks: reproduce on the simulator with real head poses first.
**Fixed 2026-10-15 (simulator, fresh boot; fork `28c2017bb`):** the intro movie and the title / main menu counted as
camera frames (their 2D draws read `c[256..261]`), so the movie and the menu text were drawn in the HUD box over a held
3D frame, and the menu's 3D Kratos close-up (a few tens of cm from the camera) was doubled. `screen_frame_draws` now also
lists the movie quad (`a17105d6566d129d` + 1280x720 texture) and the logo (`611d3d65c7fb2bdc`, 256x256): logos, movie,
title, loading and main menu go on the fixed screen, both eyes alike, no flicker. The window "tilting with my head":
Matt's GoW III config has **HUD Fixed In Front: false**, which makes the HUD box and the fixed screen head-locked;
set it on for a world-fixed screen.
**Matt (2026-10-15 evening, headset), still open, in his words:** *"You havent fixed the god of war 2d screen issue. I've
set the HUD to fixed in front, but still the actual game renders in a big box in front of me. If I turn my head I see
the edges of the box and everything is black beside it. I think its not switched to proper 3d rendering."* So gameplay
itself (not only the menus / movie) is shown as a flat box (the fixed screen) instead of the headset view: the frames
are classified as screen frames (a `screen_frame_draws` entry matching gameplay, `frames_without_3d_as_screen`, or no
camera draws found on his setup). My simulator checks used savestates `vrtest_gow3_gaia` / `gaia2` and a fresh boot only
up to the main menu; check his route (New Game / Continue into gameplay) and the log line "frames without camera
draws: shown as the fixed screen" vs "camera draws again: headset view".
**Not reproduced on the simulator (2026-10-15 late, build 7ebad6b21 = openxr + head aim):** fresh boot, title, main
menu (fixed screen, clean), *Load* -> his autosave (`BCUS98111-AUTOSAVE`, not overwritten; backup in
`F:/rpsc3/source/backup_saves/gow3_*`) into gameplay, with his config: Frame Rate Default, Vblank 36 and again at 90,
HUD Fixed In Front on, wider view applied. Every run showed gameplay as the full headset view (log "camera draws again:
headset view"), 36.0 FPS at Vblank 36 (1% low 34), 39.8 at 90 Hz. The profile's view checks use the PS3 output size
(his 1280x720), not the headset's eye shape, so his MeganeX shouldn't change them. Seen along the way: (a) idle at the
load point Kratos dies; the death screen shows as a yellow full view with a black box on the HUD box (frames count as
camera frames); (b) "BATCHJOB: AddJob: waiting for room in job list 3" hundreds of times after each load (546 in one
run), and in one run (key script went another way, probably a movie) the game froze with cellVdec "waiting for a
consumer": a frozen game shows the last frame as a box with black around it when the head turns, which matches his
description. Next: ask Matt for a savestate where it happens, or whether it still happens on this build.
Matt (2026-10-16 night): *"God of war 3 renders in a box, just rotate your head and you should see it."* Still not
reproduced (simulator, 2026-10-16: savestates, fresh boot + Load, a plain `rpcs3.exe` launch without the dev launcher,
MeganeX-shaped eyes, MLAA on and off, pause / tutorial / weapon menus and back): gameplay always fills the headset view.
The box he describes (world-fixed with HUD Fixed In Front on, head-locked with it off) is the fixed screen. **Fix
attempted (fork `6ea34c51b`, openxr `b0d0432a2`):** the profile's movie marker is a generic full-screen copy program
(`a17105d6566d129d` + 1280x720), which would put any gameplay frame that uses it on the fixed screen; it is now
`"without_camera": true` (counts only in frames without camera draws, judged over the whole frame). The switch log now
gives counts: "VR: frames without camera draws: shown as the fixed screen (camera draws N, screen-frame draws M)" and
"screen_frame_draws entry i (...) drawn after N camera draws". If it still happens: his RPCS3.log after seeing the box
tells which path it is.
**Found and fixed 2026-10-16 ~03:30 (simulator; fork `e4e646542`, openxr `70ed5e35c`):** the head pose was not
reaching gameplay at all. The trace showed `L228(0.0)` with the simulator head at yaw -30 (frozen pose): the *Wider view*
raises both of the camera's tangent floors (x 1.2, y 2.0), so the camera's projection aspect becomes ~1.07, and
`require_camera_aspect` (16:9 +-10%) rejected the real camera. The scene stayed at an old pose, so turning the head
showed a flat picture with its edges and black beyond: his box. (My stills at fixed poses looked like a full view
because the frozen picture filled each eye's straight-ahead view.) New key `reject_camera_aspect: 1.0` (keeps the
full-screen passes' square matrix out instead). Now the pose follows the head (`L904(-30.0)`) in both Gaia states;
title, menu, gameplay and pause classified as before. Frame rate with tracking: **50-52 FPS** in `gaia2` at Vblank 90
(300%, RSX thread 16.5 ms; unchanged from before). Correction: the 33-35 FPS in the fork commit message and first note
was his config's Vblank Rate 36 (limiter wait 9.5 ms/frame), not a cost of tracking. At yaw +-30 the outer edge shows
the culling cap (50 / 48 degrees each way).

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

## Midnight Club: Los Angeles Complete Edition (BLUS30442, disc 01.06)

**Stopped at step 1 (2026-10-17): stereo under 72 FPS.** Free roam in Hollywood while driving, 300%, DLSS off, on the
simulator: **60.8 FPS** (1% low 49, RSX thread 16.5 ms) with the culling the headset needs, 69.8 with the game's own
culling (control, same drive). Flat runs 85-98 at vblank 240 (RSX-thread bound, ~10.5 ms). Multithreaded RSX does
not help; Vertical / Horizontal View 60 / 80 gives 63. With the community *Enable Deltatime* and *Disable Motion
Blur* patches (enabled in `patch_config.yml`) and the fork's new *Wider view (VR culling)* 1.2 patch plus a generated
profile (`camera_block_cache` added), the picture is complete and stereo-correct at every head pose checked. Profile,
patch, frame-rate table and how the culling was found: `profiles/BLUS30442-notes.md`. Savestate
`bin/savestates/BLUS30442/mc_freeroam`. Next if picked up: cut the RSX thread's draws (LOD / draw distance, traffic).
**Open, Matt (2026-10-17, headset, state `BLUS30442_1_0`, saved 13:35; screenshot
`evidence/midnightclub/matt-errors-2026-10-17.png`):** *"you'll see multiple errors:*
*1 - The wheels on the car are too wide, this changes as you drive.*
*2 - In the distance there are black horizontal lines on the road, this looks the same issue as Sonic had with culling
in the distance*
*3 - At the bottom of the screen the road is missing and instead you get smeared gfx everywhere. This smearing happens
everywhere the gfx are missing too."* Not investigated yet.

## Uncharted: Drake's Fortune (BCUS98103, update 01.10)

**Matt's headset report (2026-10-15 afternoon, build `faf4a5bce` on `openxr`), open, in his words:**
1. *"this jungle scene is massively dependent where you look, if you push up on the right stick then the frame rate
   crashes into the 50s. This was quite misleading saying its now in the 70s."* His fpsVR shot (jungle, looking up into
   the canopy): FPS 52, average 70.1, CPU frametime 9.2 ms, reprojection 22.8 %. My 72-73 FPS was one fixed view (the
   savestate's camera, looking ahead); the canopy view is far heavier. Measure jungle frame rate at several camera
   pitches (right stick up / level), not one view.
2. *"the boat is still in the 40s."*
   2026-10-16 (simulator, `vrtest_uncharted_boat`, uncapped Vblank 180, 300%): 52-59 FPS with the VR culling, RSX thread
   17 ms; culling words fixed at 1.0 (the game's own view): **88-89 FPS**, RSX 11 ms. Split: y widening alone 65,
   x alone 77, both 57-59; the shadow-fit words cost nothing; head-driven = fixed at the same values (within noise);
   camera block cache no gain. Straight ahead the headset needs x 1.97, y 3.6 (57 degrees vertical against the game's
   23). So the boat's cost is the extra scenery the wider frustum lets through (more draws for the whole pipeline),
   not VR overhead. Options not tried yet: a far-plane / LOD reduction while widened, or a smaller vertical margin.
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
   2026-10-15 late (simulator, `vrtest_uncharted_jungle`), ruled out so far: (a) a pose change inside the frame:
   `RPCS3_VR_TRACE=1` shows every camera draw of a frame on one pose (`L453 ... C453`, updated at the flip), so the
   shadow-mask pass (`fc15ec0752d20290`, depth-remapped) and the depth it reads share the pose; (b) the culling words:
   stepping them 2.0 -> 2.6 with the head still left the sun patches unchanged (only 1.4, below what the view needs,
   culls scenery and its shadows); (c) Fewer Shadows: Uncharted's profile has no `fewer_shadows` option. A head sweep at
   90 deg/s (margin 3 vs 20) showed nothing in stills. Likely: the headset runtime's reprojection. The profile runs the
   game at 45 (`default_fps` 45, `vblanks_per_frame` 2) on a 90 Hz headset; his fpsVR showed 22.8 % reprojection, and
   SteamVR Motion Smoothing makes fine high-contrast patterns (dappled sun patches) swim while the head moves and settle
   when it stops. The simulator doesn't reproject. To check with Matt: the same spot with Motion Smoothing off in
   SteamVR, and / or VR Frame Rate at the headset rate.
   Matt (2026-10-16 night): *"No, uncharted shadows are not due to reprojection. It happens at any frame rate and all
   steamVR smoothing is off. Just turn your head and you will see smears of shadows."* **Fixed 2026-10-16 (simulator;
   fork `ccb7749f4`, openxr `437856509`):** the sun's shadow cascades are fitted to the camera frustum (slice-corner
   builder `0x14fc60` reads camera `+0x1d4` / `+0x1d0`), which the head-driven Wider view widened every frame of a head
   movement: shadow-map dumps at culling scale 1 and 6 show completely different cascade footprints (shadows also
   visibly softer at 6), so the cascades were refitted every frame while turning. New patch *VR: Shadows fit the
   game's own view*: the builder uses the game's own projection widened by separate words `0x7cdd88` / `0x7cdd8c`
   (shadow maps at culling 1 vs 6 now identical, mean difference 0.0008), which the profile moves in steps of 1.0 with
   a new `hold_s` 1.0 (they only fall after the head has been still 1 s): 2 changes in 9 s of +-15 degree sweeps
   (culling words: 236). Culling words: continuous plus new `lead_s` 0.1 (margin grows with head turn speed, so the
   culling, a frame or two behind the head, keeps the leading edge). Jungle still head 69.8 FPS (71 before). Headset
   recheck: turn the head in the jungle and watch the sun patches.
   Matt (2026-10-16): *"uncharted shadows are now flickering on and off between frames on the boat"*, and in those
   frames the bridge window is bright (dark in 2D and all other frames). **Fixed 2026-10-16 (fork `297cf068c`, openxr
   cherry-pick):** measured from fresh loads of the paused state `BCUS98103_1_0` (same delay, 300 consecutive frames
   via `RPCS3_DLSS_SEQ`): 28/300 frames without sun shadows, the same frames in repeat runs, the window bright in exactly
   those. The same in 2D with the fork's patches, 0 with them off; bisect: *VR: Shadows fit the game's own view*
   alone. Its far-corner caves used `r9` as scratch and reset it to `r1-0x60`, but the function holds the camera's
   `+0x1b0` row pointer there (set `0x14fcf0`, read `0x14fdd8`), so the cascade was built from stack data. Now
   `r9 = r4 + 0x1b0`; after: 0/300 in 2D and VR, shadows in every frame, window dark. Lesson: a cave that borrows a
   register must restore its live value, checked to the next read (not to an earlier value).
   Head aim: Matt (2026-10-16) *"head aim is getting better, but its still not good, I think it needs to move a lot
   faster"*. Measured: the camera already takes the whole head turn in one frame (~35 ms after the probe sends it).
   Added a home-menu slider *Head Aim Speed* (50-500 %, scales the gain; 200 % on the simulator: 20 degrees of head
   gives 40 of aim). Matt to pick a value.
   Matt (2026-10-16, state `BCUS98103_1_1`): *"the video from the cutscene is too fast when locked at 45fps, the audio
   is correct speed and lags behind the video."* **Fixed (fork `4c55768a9`):** the game shows each video frame for two
   vblanks, so at the 90 Hz vblank the video ran 1.5x. Profile `video_vblank_rate: 60` (vblank 60 while the video
   decoder is open): on the simulator the decoder opens at the cutscene and closes when the jungle gameplay starts
   (the boat cutscene runs into the next chapter's intro, ~4 min), then back to 45 FPS. No game state word matched the
   cutscene (searched). Headset check: audio in sync.
   Matt (2026-10-16, state `BCUS98103_1_2`): *"Shadows are better, but still not stable... if you rotate the stick left
   and right you can see the shadows at the bottom right of the screen move and flicker"*; also during the game's own
   camera moves; *"Shadows on the boat scene are crazy low res too, edges look terrible and jaggy."* Same cause: the
   shadow map is a fixed size and the VR shadow fit stretches it over the headset view (x 3 / y 6 at that spot), so
   texels are 3-6x larger. Shown in 2D, profile off, words by hand, same stick turn: fit 1.0 crisp and identical frame to
   frame, 3/6 blocky and changing shape every frame. RPCS3 has one resolution scale for all targets, so no sharper
   shadow map for now. **Fork `20911aba0`:** home-menu slider *Shadow Coverage* (default 50 %; 2/3 there, visibly cleaner
   edges; 1.5/2 covers the view straight ahead, 1.0 leaves bright bands at the edges). Matt to pick a value. A real fix
   (shadow map rendered at a higher resolution only) needs per-surface scaling in the surface cache.
   Correction (2026-10-16 evening): the 2D "profile off, words by hand" runs quoted above had the profile's culling
   rules still on, so the probe wrote 1.0 to the words every frame against the script's values: those comparisons are
   void. Redone in VR (profile shadow rules off, words written once, `BCUS98103_1_2`, same stick turn, same frames):
   the grid / crosshatch on the sun patches appears with any widened shadow words, including shadow words exactly
   equal to the culling words (3.0 / 5.53), and never at 1 / 1. So it is not a mismatch between the shadow readers
   (a second slice builder `0x1500d0` fed the shadow words changed nothing: tried and reverted). It is the shadow
   comparison filter (a dithered pattern tuned for one shadow texel per pixel) showing the enlarged texels. Cascades:
   two 2432x1216 depth maps = four 1216x1216 slices, bounding-sphere fit (scissor 1007x472 inside each slice), so a 3 /
   5.5 widening grows texels ~2.5x, not 3-6x. Prince of Persia for comparison: four 1024x1024 maps, fit word 3.85
   straight ahead, looks fine because its shadows are large and soft; Uncharted's are hard-edged dappled light.
   Matt prefers Shadow Coverage 0 % (edges lose shadow). Proper fix tried: `boosted_targets` (the 2432x1216 depth-only
   target rendered at the Resolution Scale x 2..4.5 by swapping the renderer's scaling config while it is bound):
   applied (log "boosted target ... 300% x 600%") but the GPU was lost within a second, at x2 as well; reverted, not
   committed. Next: a run with Vulkan validation to find the device-lost cause.
   **Fixed 2026-10-16 evening (fork, head-aim branch; simulator):** the stripes were never a depth problem. Tested on
   the same stick turn from fresh loads of `BCUS98103_1_2` (words fixed at 3.0 / 5.53, 90 frames each, frames matched by
   content): a 2x shadow map (`boosted_targets`, device-lost fixed: `texture_cache_helpers.h` sized its gathers by the
   renderer's global scale, now by the largest surface's), the map as D32F, a slope depth bias of 2 and 20 and a constant
   bias of 3e5 all left the stripes (lit fill of the sun patches 0.57-0.61 vs 0.78 at fit 1); a constant bias of 3e6
   just removed every shadow. Shadow-map dumps (`RPCS3_VR_RTDUMP`, raw D32F) showed clean geometry, so the cause had
   to be the reader: the sun-shadow mask (`fc15ec0752d20290` / fragment `135614811b7e2009`) takes 4 shadow taps a fixed
   texel distance apart (constant 19) around a per-pixel jitter `fract(wpos * c8)`. The fit enlarges a texel ~2.5x
   (sqrt((3 tx)^2 + (5.53 ty)^2) / sqrt(tx^2 + ty^2) at 46.7 degrees, 16:9), so the taps spread 2.5x on the ground and
   the jitter showed. Now `fragment_constant_overrides` can match the fragment program too (`"fragment"`) and divide a
   constant by that fit growth from the live words (`"inverse_fit_words"`); with it and the 2x map (kept; 66 vs 66 FPS
   uncapped without it) the patches are solid and crisper than the game's own fit (fill 0.84 vs 0.78; evidence
   `evidence/uncharted/shadow-stripes-fixed-2026-10-16.png`, `-zoom-`). Shadow Coverage default is now 100 % (the fit
   covers the whole headset view, so no bright bands at the edges). D32F and the depth bias were reverted (no effect).
   The band seen in the fit-3 shadow-map dumps (casters only in a diagonal strip of each cascade, `shadow-map-fit3-`)
   is the visible frustum itself: the cascade is a bounding sphere of the widened slice and the game only draws casters
   its (equally widened) culling keeps, so the strip is exactly the headset view. Headset check: the jungle sun patches
   at Shadow Coverage 100 %, head turning.
   Matt (2026-10-16 evening): *"ok shadows are fixed! great! Weirdly though this one rock directly behind Nathan has
   the wrong depth, its way too far forward for where it sits"* (the flat stacked slab behind Nathan / Sully in the
   jungle, `BCUS98103_1_2`). **Fixed (fork `0957c4d57`, openxr `240002070`; simulator):** both eyes' colour and depth
   dumped, disparity fitted against depth: the slab sat 6.4 px nearer than its depth, everything else within 1 px.
   Uncharted draws each object with its own matrix and some carry a scale (0.6 to 3.6, 20 % of draws, some uneven);
   the profile's `eye_offset: "baseline"` scaled each object's eye offset by it. Now `baseline_per_w`, whose offset
   comes from the projection's own x scale: every patch within 0.6 px. Evidence
   `evidence/uncharted/rock-depth-before-2026-10-16.png` (red = wrong depth) and `-after-`. Released games on
   `baseline_per_w` rechecked: Tales of Xillia 120.0 FPS, Dragon Age: Origins castle 119.8 / forest 120.0, disparity
   unchanged against their 10-09 shots. Headset check: the slab behind Nathan.
   Head Aim Speed: Matt (2026-10-16) *"When its at 150% nathan turns 50% faster, but the head movement isn't 50% faster,
   so the reticule shifts off center. It should also turn the camera faster too."* **Fixed (fork `e6abe5b35`, head-aim
   branch; merged into openxr 2026-10-17):** the view held still against all of the camera's turn; now against 1 / speed of
   it, so the view turns with the camera by the rest and the aim stays where the head looks. Matt: *"much better."*
   **Open, Matt (2026-10-17):** *"when aiming can you isolate the aim reticule and push it deep into the scene, maybe
   10m?"* Not investigated yet.
   **Open, Matt (2026-10-16):** *"if you walk forward in the jungle you'll see water in front of you. Reflections in the
   water are broken, turning your head changes the reflections incorrectly."* (State `BCUS98103_1_2`, walk forward to
   the water.)
   **Fixed 2026-10-17 (fork `aad83d8ec`, openxr `ae9340f02`; simulator):** the reflection pass (`292d56e8bfecaf63` /
   `59c0ac681f999e51`, blended into the scene; hiding it made the eyes' water equal: brightness ratio 1.41 -> 1.01)
   projects the reflected ray into the half-resolution scene `c31e0000` with a matrix in fragment constants 69 / 73 / 72
   made with the game's camera, while VR draws `c31e0000` per eye: lookups in the wrong place, a bright grey sheen in one
   eye at yaw +20. New profile key `fragment_camera_rows` remaps those rows per eye (the eye transform applied through
   their clip-to-texture mapping). After: no sheen, reflections of Sully, the flowers and Nathan in place at yaw -20 / 0
   / +20, the same in both eyes where both see the reflected object (screen-space reflections only show what that eye
   drew: Sully, off the left eye's image at yaw +20, reflects in the right eye only). Headset check: walk to the river
   **Open again, Matt (2026-10-17, headset):** *"the river reflections are better but still wrong, moving my head up and
   down slightly massively changes whats reflected"* (`evidence/uncharted/water-reflection-head-up-matt-2026-10-17.png`,
   `-head-down-`; repro: jungle state `BCUS98103_1_2`, walk forward to the river, tilt the head).
   **Fixed 2026-10-17 (forks `8469c076b`, `c905a88ff`, `2b591ed79`; Matt, headset: "reflections are finally fixed!"):**
   the pass projects (mirrored game camera + reflected view ray) into a mirror render of the scene (`c31e0000`, drawn
   before it with the camera mirrored in the water) with rows made for a taller square camera. Fixed in turn: the
   mirror was taken as part of the texture mapping (pitch turned the lookup the wrong way); the eye used the game's
   v scale (0.5 x A / B) though each eye draws the source with its own camera (reflections slid faster than the head);
   the 1 m point moved with the eyes' offset and the head's translation (`from_camera`, the shift not mirrored); both
   eyes took the view vector from the game camera (`eye_position`: c52 per eye, reflections get their depth). Matt
   (2026-10-17) on a new state `BCUS98103_2_10`: *"the distant fog is different when you look up and down ... the
   far area with sun shafts is a lot lighter for no reason"*. Two faults. The river turned flat light grey looking up:
   its water program shared the 16-word fingerprint the fork caches shader control bits by with another program, took
   its bits (no fragment rows) and kept the game's lookup, which looking up read the mirror render's empty part (fork
   `2b591ed79`, bits decided every time for profiles with fragment_camera_rows). The far haze: the lighting pass's
   height fog (fp `9fe5ec00ef1c6d6f`, c5 / c13) used game NDC rays and the game's up vector for the eye's pixels; per
   eye now (fork `3030335b5`, rule form `ray` / `view_vector`). Far haze mean, pitch 0 / 30 / 45 / 60: 42.3 / 45.1 /
   48.2 / 48.2 before, 43.8 / 44.5 / 45.0 / 44.7 after; the river teal at both pitches. Matt (2026-10-17) after the
   river fix alone: "its all identical" (that build lacked the fog rule). Matt also
   noticed reflections can show grey where the mirrored geometry is not rendered (the mirror render's empty part):
   expected to be gone with this; recheck.
   **Open, Matt (2026-10-17, headset):** *"Grey flickering of tree leaves still happening, I made a new game state for
   it"* (state `BCUS98103_2_11`; his shots: flat grey-lavender leaf clusters near the top of the view, left top,
   centre top, centre left top; *"It's quite rare, maybe you'll need 5-10 secs to see it"*, *"10 seconds of every
   frame"*). Not reproduced on the simulator (scale 400, Frame Rate 45): a per-frame read-back of both eyes' normal
   and depth buffers (dev RPCS3_VR_HOLEWATCH, not committed: `edit_holewatch.py`) counted at most 8 clear-value pixels
   in 1155 frames of head wander (yaw 15, pitch 8, roll 4, 4 cm) and 1457 frames of sway. Ruled out there: pose
   updates splitting a frame (all at flips, full frames), projection pin-table misses (0), shadow coverage capped to
   the game's (no grey leaves). Matt (more detail): *"both eyes, head still and moving, always in the tree tops,
   single frame"*. His crop: a flat grey-brown silhouette where sky should show between leaves (sky missing for one
   frame, not a normal-buffer hole). A per-frame scene-colour watcher (top 45 %, one-frame jumps, dumps) over 70 s on the
   simulator caught only leaf motion. Next idea: occlusion queries (Disable ZCull Occlusion Queries is off; the profile
   has late readbacks).
   **Open, Matt (2026-10-17):** *"I also found another bug, made a new save state, if you rotate the right stick the
   rock in front warps and disappears!"* (state `BCUS98103_2_12`; his shots show Nate crouched by rocks, the second
   with a rock gone and sky in the gap). Loaded on the simulator the state opens with Sully walking up to the camera
   and Nate standing; turning the camera with the right stick there showed no warp, VR or game view, scaled_camera_blocks
   on or off.
   **Fixed 2026-10-17 (fork `e67de068d`, Matt: "looks good"):** state `BCUS98103_1_9`, *"a lot of the scenery in the
   middle of the screen judder and move over time"*: scaled scenery took last frame's projection while the culling
   widening changed it every frame the head moved; profile `scaled_camera_blocks` solves it from each block.
   **Open, Matt (2026-10-16):** *"I've made a new save state for uncharted where the framerate is in the 30s. We need to
   get this to at least 45."* (State `BCUS98103_1_3`, saved 21:15; also `BCUS98103_1_4`, saved 21:22, Matt: "another
   performance issue one".) Not investigated yet.
   **Open, Matt (2026-10-16):** *"I've made another save state, where textures haven't loaded properly. Moving will make
   them load, but on the initial state you can see in front to the left and right above Nate there are solid grey
   patches. Different models will flicker to gray as you move around, this is an issue everywhere, work out how to
   texture correctly."* (State `BCUS98103_1_5`, saved 21:30.) Matt's headset shot: `evidence/uncharted/grey-textures-matt-2026-10-16.png` ; the grey parts, cropped by Matt:
   `grey-textures-crop1-matt-2026-10-16.png` (a flat panel crossed by a diagonal beam, left of the arch) and
   `grey-textures-crop2-matt-2026-10-16.png` (a tall narrow piece on the right), both untextured flat grey.
   **Fixed 2026-10-17 (fork `62e1044ef`, openxr `a8e4f4831`; simulator; regression subset of 12 states: frame rates as before, pictures normal, `evidence/vrtest/2026-10-17-1039`):** not textures. The grey
   pixels hold the normal buffer's clear value (`c07d0000` = BGRA 90,194,86,57, the same as the hidden-area corner):
   nothing wrote a normal there, and lighting shades the clear value flat grey. Uncharted draws every object twice: a
   depth pass, then the normal pass with depth EQUAL (no alpha test). Flat: 0 holes; VR: ~1200 per eye (the hanging
   piece right of the arch, thin lines), the same in every run; ZCULL settings change nothing; EQUAL->LEQUAL (probe dev
   0x100) removes a quarter; probe off (`render=0`): 0. Skipping the probe's head rotation or headset-FOV remap: 0
   (eye offset: no effect). A per-draw log showed identical input matrices (273 of 324 normal-pass draws match a
   depth-pass matrix bit for bit) leaving with different outputs, differing only in the cached projection scale A/B
   (2 ulp): a non-rigid block (an object scaled unevenly, ~40 % of draws) took whatever the previous rigid draw
   measured, each object's matrix gives the scale with different last bits, and the frame mixes two projections 0.5 %
   apart, so an object's two draws were remapped with different numbers and failed EQUAL in patches. Now each frame's
   projections are snapped to their first measurement (within 2e-4) and a non-rigid block takes last frame's dominant
   projection when its last measurement is in that camera's family (2 %): holes 10 / 0 (still and with the head turned
   20 / 10 degrees), the hanging piece textured (`evidence/uncharted/grey-holes-before-after-2026-10-17.png`, map of
   the clear-value pixels `grey-holes-normal-buffer-2026-10-17.png`). Rock-depth fit unchanged (0 outliers). Matt:
   "Don't move the camera" and his settings (Vertical / Horizontal View 60 / 80, scale 460) were the reproduction
   advice; the holes reproduce at any settings. Headset check: the state, no movement, then walking around.
   **Open again, Matt (2026-10-17, headset):** *"the specific grey objects have been fixed, but others still exist. I took
   a new snapshot showing them in the same room"* (`evidence/uncharted/grey-holes-remaining-matt-2026-10-17.png`: white /
   grey edges and bars on the scaffolding in the dark hall; state `BCUS98103_1_7`, saved 13:51).
   **Fixed 2026-10-17 (fork `891ec5536`, openxr; simulator; regression not run, Matt checks):** the scaffolding beams are
   blocks stretched along view axes that pass the rigid test, so their scales were taken as the projection (A 0.27, B
   0.60 or 0.64); each beam's depth pass and EQUAL normal pass then got different projections depending on the draw
   before, and whole beams kept the normal buffer's clear value. A per-draw transform log showed 30 groups of identical
   input matrices with different outputs (only A, B and the clip rows differing). Now a measurement whose aspect (B / A)
   is more than 1 % off last frame's dominant projection is only counted (and moves the dominant if a whole frame has
   none at it). Hole pixels (normal at clear value over geometry, both eyes, no movement): 50523 -> 1 at pose 0 and 0
   at yaw -20 / +20 / -40 / +40 / 90 / 180, pitch -10 / +10 / -15 / +15, roll 15.

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
