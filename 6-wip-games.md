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
`rpcs3/vr-non-working/` (see its README). An exception is flagged below: God of War Collection and Killzone 2
are **tracked in `bin/`**, so the next release will ship them unless they are moved or finished first.

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
| God of War selector | the intro is a real-time 3D logo animation through a camera: its four programs are `screen_frame_draws` | |
| God of War 1 | Power Up screen flicker (camera classification changed every ~3 frames): its menu-art draw pins the frame to the screen (180 -> 7 switches in 6 s); **world scale measured: 13.5 units/m, `eye_baseline` 3.2 -> 0.864** (characters ~3.7x bigger) | **QTEs not passable at 90 FPS** (Matt, savestate `BCES00800_1_4`): QTEs need patching |
| God of War II | same Power Up flicker (260 -> 7), same scale (0.864); savestate `vrtest_gow2_rhodes` | |
| Puppeteer | **dark/small explained:** the lit stage is as bright as flat but covers 13% of the view (game FOV 45 x 26, stage 27 m away): `eye_baseline` 0.064 -> 0.64 (diorama ~2.7 m away); try **Camera Depth Offset +2 m** in the VR menu to enlarge it. Velocity buffer fixed (`linked_camera_blocks [264]`), a likely cause of the trails | trails (recheck), deferred lights rebuild rays with the game's projection (shapes unchecked) |
| KH 1.5 (KH Final Mix) | **new profile** (generated + hand-fixed): new key `camera_palette` (characters were head-locked: rigid skinning with full clip matrices per bone), GS-projected effects, scale 6.4. **Unlocked frame rate patch v2 (2026-10-02): real time at 72/90/120 (measured); VR 120 Hz sustained at 300%** | HUD rule unverified (no HUD seen yet) |
| KH 2.5 (KH II Final Mix) | **new profile** (generated + hand-fixed): HUD box (tutorial box, portrait) world-fixed, GS-projected effects, scale 6.4. **Unlocked frame rate patch v2 (2026-10-02): real time at 72/90/120, jump unchanged (measured); VR 72 Hz sustained at 300%** | the game's fixed-step mode (never seen yet) |
| Super Stardust HD | **new profile (2026-10-02, licence added by Matt)**: generated + one hand fix (no `depth_offset_projection`: the whole game is drawn in camera space around the planet, a ~0.7 m tabletop diorama). **Real time at 72/90 (measured), no patch; max_fps 0. VR 120 Hz sustained at 300%.** Gameplay, HUD, pause menu, title world-fixed on the simulator; savestate `vrtest_ssd_lave` | **Matt 2026-10-02: "nearly perfect"; menu 3D text uncomfortable, background slowly rotating -> fixed:** menus, title, attract demo and game over now on the fixed screen (new key `screen_frames_when`, game state word `0x332b7ec0`; fork b9568756d). Recheck the menus and the boot loading screen in the headset |
| Resogun | | **needs the .rap licence** |

**New games to profile (Matt, 2026-10-01/02):** full VR profiles for
- **Super Stardust HD** (PSN, `dev_hdd0/game/NPUA80068`): **done 2026-10-02** (profile, real time, VR 120 Hz; `profiles/NPUA80068-notes.md`).
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
| The Darkness, Anarchy Reigns | parked | |

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
| Dragon's Dogma: Dark Arisen | BLUS31155 | `vr-non-working/` + untracked `bin/` copy | yes (community Unlock FPS, real-time) | **120 Hz** (prologue, 2026-10-02 run; 72 on 2026-10-01) | **broken** (boot screens head-locked; slow in Matt's save) | open-world frame rate and outdoor flares with `zcull_approximate` unchecked; headset frame rate (risk); needs update 01.02 |
| Ratchet & Clank Collection | BCUS98282 | `vr-non-working/` + untracked `bin/` copies (base + rc1/rc2/rc3 executable profiles) | R&C 1, 2, 3 yes (profile frame-time values, run speed verified) | **R&C 1 90 Hz**, **R&C 3 90 Hz** (2026-10-02 run; both 72 before), **R&C 2 120 Hz** (Aranos and the machinery hall) | **broken** (R&C 1 unplayable: scene as a fixed 2D window; loader and menus head-locked) | R&C 1 has little margin at 72; R&C 1 pause menu |
| Tales of Xillia | BLUS31006 | `vr-non-working/` + untracked `bin/` copy | yes (community 60 FPS + fork patch) | 90 | **to recheck**: fixed 2026-10-01 night on the simulator: menus on the fixed screen, a boxed scene copy (misplaced effect); white screen after Start not reproduced (probably the menu fix); battles unchecked | battles unchecked |
| The Darkness | BLUS30035 | `vr-non-working/` + untracked `bin/` copy | yes (community 60 FPS patch, real-time) | below 72 (48 at 72) | **parked**: under 60 FPS in Matt's save; intro black for a long time, videos missing | too slow at 300% (48 at 72); stereo and headset view fixed in the opening |
| Dynasty Warriors 6 Empires | BLUS30306 | `vr-non-working/` + untracked `bin/` copy | no: frame-locked, profile at 60 (180 flat possible) | 120, but frame-locked: plays at 60 | not played | 90 FPS needs a logic-step patch |
| Puppeteer | BCUS98227 | `vr-non-working/` + untracked `bin/` copy | yes (profile frame time, Vblank 180 = 90 FPS, real-time) | 90 (2026-10-02; 72 before) | **barely works**: graphics trails, very dark, world far away and small; the head-locked intro light fixed 2026-10-01 evening | stage small in the headset view; SPU post skipped in VR |
| Jak and Daxter Collection | BCUS98281 | `vr-non-working/` + untracked `bin/` copies | Jak 1 **no**: steps a fixed 1/60 per frame (1.5x at 90): capped at 60 in VR for now; Jak II probably the same; Jak 3 no (74-85 flat in Spargus) | Jak 1 120 (renderer; the game is capped at 60); Jak II 72 (2026-10-02); Jak 3 below 72 | **Jak 1**: HUD boxed, speed fixed (capped at 60, reprojected) and stereo depth fixed 2026-10-01 late, simulator-checked; to recheck in the headset | HUD unchecked |
| Asura's Wrath | BLUS30721 | `vr-non-working/` + untracked `bin/` copy | yes (community Unlock FPS, real-time) | **120 Hz** (Episode 1 space battle) | **works well**; cutscene letterbox box/bars to remove | QTE mashing at 90 untested |
| Anarchy Reigns | BLUS30632 | `vr-non-working/` + untracked `bin/` copies (profile, patch) | yes (fork patch, real-time verified) | 90 (Training only) | **parked**: splash/intro head-locked, HUD culled by depth; bad performance and graphics issues in gameplay | campaign unchecked; HUD timers 3x |
| Dante's Inferno | BLUS30405 | `vr-non-working/` + untracked `bin/` copy | yes (profile `game_frame_ms_f32`, no patch; 0.99x at 90) | 120 | gameplay performs really well; splash, menus, intro movie and pause menu world-fixed since 2026-10-01 evening (simulator); objects culled at the edges of the headset view | sky is a screen card; world scale unchecked |
| God of War Collection (GOW1, GOW2) | BCES00800 | tracked in `bin/` | yes (profile, no patch) | 120 (GoW 1 boat, GoW II Rhodes) | **GoW 1**: main menu on the fixed screen and Kratos's blurred edges fixed 2026-10-01 evening (simulator / desktop checked); performance good; GoW 2 unchecked | 5% black border |
| Killzone 2 | BCUS98116 | tracked in `bin/` | no: default 45 | not measured | not played | RSX-bound; HUD and combat unchecked |
| Gran Turismo 5 | BCUS98114 | `vr-non-working/` + untracked `bin/` copy | yes (patch) | ~~90 (race start)~~ ~40 FPS in the headset (Matt) | tested, broken: **~40 FPS, needs 60 minimum** | menu clipping, race-start frame rate |
| MotorStorm: Pacific Rift | BCUS98155 | `vr-non-working/` + untracked `bin/` copy | yes (patch) | not measured | not played | stereo 50-70 at race start (needs multiview) |
| Blur | BLUS30295 | `vr-non-working/` | yes (patch) | not measured | not played | 45-50 FPS stereo |
| Need for Speed Most Wanted | BLUS31010 | `vr-non-working/` | yes (patch, fixed per rate) | not measured | not played | in-race speed at 90 unconfirmed |
| inFamous 2 | BCUS98125 | `vr-non-working/` | no patch needed | not measured | not played | 52-72 stereo; SPU layer left-eye only |
| Metal Gear Solid 4 | BLUS30109 | `vr-non-working/` | yes (patch) | not measured | not played | ~35 stereo in Act 1; one hang |
| inFamous | BCUS98119 | `vr-non-working/` + untracked `bin/` copy | no patch needed | not measured | not played | ~25 stereo: too slow |
| Split/Second | BLUS30300 | `vr-non-working/` | yes (patch) | not measured | not played | race load-bound |
| God of War III | BCUS98111 | `vr-non-working/` + untracked `bin/` copy | no (`max_fps 36`) | not measured | not played | early experimental; no notes |
| MX vs ATV Reflex | BLUS30321 | untracked `bin/` only | no (`max_fps 30`) | not measured | not played | generated 2026-09-28; no notes |
| Uncharted: Drake's Fortune | BCUS98103 | none | no: 42-46 flat | not measured | - | SPU/PPU-bound; not pursued |
| Final Fantasy X/X-2 HD Remaster | BLUS31211 | none | no: 80-91 flat | not measured | - | RSX-bound flat; not pursued |

## Testing in the headset (applies to all)

Start SteamVR and launch the game normally from RPCS3, with no dev environment variables. To try a game
from `vr-non-working/`, copy its profile to `bin/vr_profiles/` and its patch to `bin/patches/`, then enable the
patch in `Manage > Game Patches`. Those patches are not "Enabled By Default". Things only the headset shows:
- world scale: the near plane sets it; use World Scale in the home menu's VR tab;
- whether a 3D HUD plane lands in the HUD box;
- comfort and frame pacing.

---

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
- **Open:** open-world frame rate; outdoor flares with `zcull_approximate` (any visible pixel reports as fully
  visible); NPC name tags stay in the HUD box; world scale and HUD in the headset.

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

## Tales of Xillia (BLUS31006, disc 01.00)

Notes: `profiles/BLUS31006-notes.md`. Evidence: `evidence/xillia/`.

- **Frame rate:** community *60 FPS* patch plus the fork's *Frame rate follows VR* (scales the game's tick count by
  60/fps; profile `game_frame_time_f32`). Walking speed measured equal at 60 and 90 (1.43x without the fork patch).
  Headroom: 180 flat, 130-150 stereo at Vblank 180.
- **Profile:** generated, `row_vectors c[0, 47]`, HUD `c[0]` + `hud_skips_passes`; stereo and yaw audit clean.
- **Headset (Matt, 2026-10-01):** white screen forever after the first Namco splash, **only when Start is pressed on
  that splash screen**. Left alone it boots normally (headset, desktop stereo at 90, OpenXR Simulator at 90). Not yet
  known whether flat play at 60 does the same; next: press Start on the splash flat, then in stereo, and compare logs.
- **In game in the headset (Matt, 2026-10-01): performance great, image broken.** HUDs all over the place (some tied to
  the head, some offscreen); screen effects in the wrong place; edge outlines around characters with blur outside
  those edges (a post-process edge/outline or depth-of-field pass misaligned with the scene). Desktop stereo and the
  fixed-pose fake headset looked right, so reproduce on the OpenXR Simulator with a head sweep first.
- **Open:** battles; world scale.

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

## Asura's Wrath (BLUS30721, disc 01.00)

Notes: `profiles/BLUS30721-notes.md`. Evidence: `evidence/asura/`. Community Unlock FPS (+ motion blur and depth of
field off): 90 FPS at Vblank 180, real-time; generated profile with `vblanks_per_frame 2`; stereo and yaw audit
look right in Episode 1. Sustained in VR at 300%: 120 Hz (Episode 1 space battle, 119.6 FPS at Vblank 240, no late
frames; savestate `vrtest_asura_space`, made with Compatible Savestate Mode).

- **Headset (Matt, 2026-10-01): works well.** To do: in-engine cutscenes show a 16:9 box with black letterbox
  bars (the game draws the bars; the viewport is the full 1280x720). Hide the box background and the bars in VR so
  the cutscene shows the 3D world with the HUD elements (subtitles, prompts) on top. Find the bar and background
  draws with probe `hide=<vertex hash>[@<target>]` (and `why=`) in a cutscene, then `hidden_draws` (program + texture
  size) or an unboxed/passthrough rule; check subtitles and QTE prompts stay.

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

## Dante's Inferno (BLUS30405, disc 01.00)

Notes: `profiles/BLUS30405-notes.md`. Evidence: `evidence/dante/`. Frame-locked above 60 by a whole-frame clock;
the profile sets its frame interval (new key `game_frame_ms_f32`, `0x119ecb4`): real-time at 90 without a patch.
Generated profile (row vectors, five camera blocks, HUD `c[0]`); the HUD vanished in stereo until
`require_rigid_camera` (generator fixed to write it). Stereo, audit, pause menu right on the desktop.
- **Headset (Matt, 2026-10-01):** gameplay performs really well. Splash screen, menus and the intro movie are tied
  to the head (screens with nothing the profile boxes). Needs culling/FOV work: the game culls to its own narrower
  frustum, so objects in the wider headset view are missing (a culling-widening patch, as ICO's "Wider view (VR
  culling)").

## God of War Collection (BCES00800 v01.00, UK disc)

Notes: `profiles/BCES00800-notes.md`. Evidence: `evidence/gow/`. Profiles: `BCES00800.gow1.json`,
`BCES00800.gow2.json` and a base `BCES00800.json` for the launcher. The collection needs the base profile
so that OpenXR is prepared before the exitspawn into a game.

- **State:** desktop and headset-path verified; not played in the headset. Both games reach 90 FPS in
  stereo on the headset path (flat RSX load 10-45%).
- **Headset, GoW 1 (Matt, 2026-10-01):** performance good. The main menu looks wrong: its 2D and 3D elements are
  combined at the wrong depth. In gameplay the main character has blurred edges (a screen-space pass, e.g. motion
  blur or an outline/glow, misaligned with the head-transformed scene): Matt's savestate `vrtest_gow1_matt_blur`
  (`BCES00800_1_2`, 18:14). GoW 2 not tried. **Note: this collection is tracked in `bin/` and would ship in the
  next release as it is.**
- **Frame rate:** no patch. Profile `game_fps_u32` sets the engine's dt to 1/rate (GOW1 `0x531dd0`,
  GOW2 `0x5720f4`); game time measured at 1.0x at 90.
- **HUD:** a 4:3 bare projection in the scene's slots. The new profile field
  `screen_space.offaspect_projection` handles it, and the generator detects it.
- **Open:**
  - 5% black border: the scene renders at 1216x684, inset in 1280x720, so the world is ~5% smaller than
    the head rotation. Lead: the per-video-mode layout table at GOW1 `0x157918`. Measure k first.
  - One crash in 8 boots at the collection switch (`vkCreateSwapchainKHR` into an unloaded module); not
    reproduced.
  - Savestate restore then checkpoint restart kills the RSX thread: boot fresh.
- **Release question:** the profiles are already tracked in `bin/`.

## Killzone 2 (BCUS98116)

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
- **Release question:** the profile is already tracked in `bin/`.

## Gran Turismo 5 (BCUS98114 v02.11, XL Edition, US)

Notes: `profiles/BCUS98114-notes.md` (the most detailed). Evidence: `evidence/gt5/`. Parked at vr5.

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
- **Open (from the notes):**
  1. Arcade menu clipped when the head moves back (needs the headset path).
  2. Race-start frame rate: the RSX thread is CPU-bound even flat (~42 flat, ~30 stereo). Needs multiview.
- **Headset (Matt, 2026-10-01, on the build with the RSX-thread optimisations): ~40 FPS. Target: at least 60**
  (the game's own rate; below that it does not work). The regression run's "90 Hz (race start)" was measured from the
  grid savestate after a 40 s settle and does not reflect racing. Next: measure the RSX thread (cycle-exact, frame
  stats) in a race at 60 Hz flat and stereo, profile with `RPCS3_RSX_SAMPLE=3`, and check how much of today's per-draw
  gain GT5 got; a savestate mid-race from Matt would make the measurement repeatable.
  3. Intermittent upside-down menu (not seen since the display-buffer size fix).
  4. Cockpit, replay and garage not audited; the shadow and mirror fixes not yet seen in the headset.

## MotorStorm: Pacific Rift (BCUS98155 v01.00)

Notes: `profiles/BCUS98155-notes.md`. Evidence: `evidence/motorstorm/`. Moved to `vr-non-working/` at vr6.

- **Frame rate:** fork patch file with the community unlocked frame rate (60 FPS + Variable FPS). It gives
  90 FPS with clocks at 1.00x, and also turns dynamic resolution and motion blur off. Profile `max_fps 0`.
  Needs Write Color Buffers.
- **Picture:** no stereo-vs-flat difference found on the desktop.
- **Blocker:** frame rate at a race start with the pack in view. At 100%, flat runs ~86 and stereo ~72, then
  85-90. The headset path at 300% runs 35-53 (GPU 68%). The RSX thread is already saturated flat, and
  stereo adds ~1.7 us per draw on 4,500-5,000 draws. Most of that is driver submission for the right eye,
  which multiview would remove. 200% is worth trying in the headset.

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

Early experimental profile (`row_vectors`, camera blocks 256/260/0, `max_fps 36`). It has no notes file
and no recorded measurements: start from the playbook if it is picked up again.

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

## Uncharted: Drake's Fortune (BCUS98103 v01.00)

Triaged 2026-09-30 with no profile made. Native 30. The flat ceiling at vblank 180 on the boat is only
42-46, with every SPU thread at 100%, so it is SPU/PPU-bound and 90 is not reachable. Evidence:
`evidence/uncharted/boat-vblank180-45fps.png`. Its boot crash in `VKGSRender::flip` (Frame limit Auto) was a
generic bug, fixed in fork 4704701a2.
