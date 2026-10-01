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

## First headset test (Matt, 90 Hz, 2026-10-01): continue here

Matt's first real-headset run of four WIP games, on the uncommitted build with the 2026-10-01 RSX-thread changes
(Gate 6 entry in `4-next-steps.md`). Until then none of these games had been run in a headset: they were checked
in desktop stereo and in the simulated headset view (`RPCS3_VR_FAKE_HMD`), from gameplay savestates, so boot
screens, menus and intro videos at the headset rate were never seen in a headset view.

| Game | What Matt saw |
|---|---|
| Dragon's Dogma | All the initial screens are tied to the face (head-locked), not fixed in place. Performance is bad in Matt's save: savestate `bin/savestates/BLUS31155/vrtest_ddda_matt_slow.SAVESTAT.zst` (hard link to `BLUS31155_1_1`, 2026-10-01 17:01; in-game save `BLUS311550` 17:00). Needs improving. |
| Ratchet & Clank Collection | The collection loader and R&C 1's initial screens are head-locked. **R&C 1 unplayable:** gameplay appears on a fixed 2D window, with depth problems (things appearing and disappearing) as the head moves. Matt suspects R&C 2 and 3 break the same way (not tried). |
| Tales of Xillia | Does not work at all: after the first Namco splash screen the view stays white forever (not frozen, but no game). |
| The Darkness | Broken after the splash screen. |

**The simulated headset is not the headset.** `RPCS3_VR_FAKE_HMD` renders the headset image on the desktop (same
camera transforms, headset FOV and HUD box) but with a **fixed forward pose**: head-locked and world-fixed screens look
identical, and nothing that depends on head movement can show. No OpenXR session (no compositor, no 90 Hz pacing, no
reprojection), a symmetric FOV, and the real-headset-only code is skipped: per-target pose stamping
(`vr_stamp_targets`), `vr_track_frame_boundary`, pose carried through copies, `vr_realign_blend_targets`. Running that
pose bookkeeping with the fake headset once dropped Dragon's Dogma to 6 FPS and Anarchy Reigns to 60 (cause never
found): a lead for Dragon's Dogma's slow save. Use `RPCS3_VR_WOBBLE` (moving pose) before trusting a fake-headset result,
and treat only Matt's headset runs as headset results.

**OpenXR Simulator (set up 2026-10-01): use it for headset checks.** A real OpenXR runtime in
`F:psc3\source\OpenXR-Simulator` (Pimax Dream Air profile, 90 Hz); `tools/re/simboot.ps1 -Iso <disc> -Probe render=1`
boots RPCS3 on it for that launch only, `tools/re/simshot.py OUT` captures the composited eyes. Setup and quirks:
`5-vr-profile-playbook.md` > "Headset checks with the OpenXR Simulator".

**The Darkness reproduced on the simulator (2026-10-01):** disc boot at Vblank 90: copyright splash, the intro's fire
video, then black for good (Cross does nothing). RPCS3's own image is black too, so the game itself draws black at
90 Hz; the headset path is not losing a picture. No `cellVdec ... waiting for a consumer` warning in the log.
Next: the same boot at Vblank 60 with the headset, and at 90 without it (`RPCS3_OPENXR=0`), to split "90 Hz" from
"headset session". Capture: `evidence/headsetsim/darkness_sim_90hz.png`.

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
Clank and Dragon's Dogma re-measured after the RSX-thread work the same day, `evidence/vrperf/`). **72 is the
pass mark** for fully compatible.

| Game | ID | Profile | Real-time above 60 | Sustained in VR, 300% | Headset | Blocker |
|---|---|---|---|---|---|---|
| Dragon's Dogma: Dark Arisen | BLUS31155 | `vr-non-working/` + untracked `bin/` copy | yes (community Unlock FPS, real-time) | **72 Hz** (prologue; 68 before the 2026-10-01 renderer work and `zcull_approximate`) | **broken** (boot screens head-locked; slow in Matt's save) | open-world frame rate and outdoor flares with `zcull_approximate` unchecked; headset frame rate (risk); needs update 01.02 |
| Ratchet & Clank Collection | BCUS98282 | `vr-non-working/` + untracked `bin/` copies (base + rc1/rc2/rc3 executable profiles) | R&C 1, 2, 3 yes (profile frame-time values, run speed verified) | **R&C 1 72 Hz** (71.5, tightest); **R&C 3 72 Hz**; **R&C 2 120 Hz** (Aranos hall; outdoor levels unmeasured) | **broken** (R&C 1 unplayable: scene as a fixed 2D window; loader and menus head-locked) | R&C 1 has little margin at 72; R&C 1 pause menu |
| Tales of Xillia | BLUS31006 | `vr-non-working/` + untracked `bin/` copy | yes (community 60 FPS + fork patch) | 90 | **broken** (white after the Namco splash) | battles unchecked |
| The Darkness | BLUS30035 | `vr-non-working/` + untracked `bin/` copy | yes (community 60 FPS patch, real-time) | below 72 (48 at 72) | **broken** (after the splash screen) | too slow at 300% (48 at 72); stereo and headset view fixed in the opening |
| Dynasty Warriors 6 Empires | BLUS30306 | `vr-non-working/` + untracked `bin/` copy | no: frame-locked, profile at 60 (180 flat possible) | 120, but frame-locked: plays at 60 | not played | 90 FPS needs a logic-step patch |
| Puppeteer | BCUS98227 | `vr-non-working/` + untracked `bin/` copy | yes (profile frame time, Vblank 180 = 90 FPS, real-time) | 72 | not played | stage small in the headset view; SPU post skipped in VR |
| Jak and Daxter Collection | BCUS98281 | `vr-non-working/` + untracked `bin/` copies | Jak 1, Jak II yes (real-time, no patch); Jak 3 no (74-85 flat in Spargus) | Jak 1 72; Jak II below 72 (69); Jak 3 below 72 (43) | not played | HUD unchecked |
| Asura's Wrath | BLUS30721 | `vr-non-working/` + untracked `bin/` copy | yes (community Unlock FPS, real-time) | **120 Hz** (Episode 1 space battle) | not played | QTE mashing at 90 untested |
| Anarchy Reigns | BLUS30632 | `vr-non-working/` + untracked `bin/` copies (profile, patch) | yes (fork patch, real-time verified) | 90 | not played | campaign unchecked; HUD timers 3x |
| Dante's Inferno | BLUS30405 | `vr-non-working/` + untracked `bin/` copy | yes (profile `game_frame_ms_f32`, no patch; 0.99x at 90) | 120 | not played | sky is a screen card; world scale unchecked |
| God of War Collection (GOW1, GOW2) | BCES00800 | tracked in `bin/` | yes (profile, no patch) | 120 (GoW 1) | not played | 5% black border |
| Killzone 2 | BCUS98116 | tracked in `bin/` | no: default 45 | not measured | not played | RSX-bound; HUD and combat unchecked |
| Gran Turismo 5 | BCUS98114 | `vr-non-working/` + untracked `bin/` copy | yes (patch) | 90 (race start) | tested, broken | menu clipping, race-start frame rate |
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
- **Headset (Matt, 2026-10-01): broken.** White after the first Namco splash (not frozen). Likely lead: the intro
  video at the headset rate (see "First headset test" above).
- **Open:** battles; world scale.

## The Darkness (BLUS30035, disc 01.03)

Notes: `profiles/BLUS30035-notes.md`. Evidence: `evidence/darkness/`.

- **Frame rate:** community *60 FPS* patch applies to the disc (01.03); real-time at 180; stereo 75-80.
- **Profile:** generated (`column_vectors c[0]`, 100% coverage).
- **Blocker:** any stereo shear breaks the multi-pass lighting (red light leaking, dark bands), even in a single
  sheared view. Needs a stationary scene to bisect (the opening is scripted and animated).
- **Headset (Matt, 2026-10-01): broken after the splash screen.** See "First headset test" above.

## Dynasty Warriors 6 Empires (BLUS30306, disc 01.00)

Notes: `profiles/BLUS30306-notes.md`. Evidence: `evidence/dw6e/`. Generated profile, stereo and yaw audit clean,
180 FPS flat in battle, but frame-locked (3.4x at 180, no dt found): runs at 60 with reprojection for now.

## Puppeteer (BCUS98227, disc 01.00)

Notes: `profiles/BCUS98227-notes.md`. Native 30, frame-locked; the game's frame time (`0x98ebec`) is now driven by
the profile and gives near-real-time movement at 90 FPS. Still flips every 2 vblanks: needs a flip-interval patch.
Generated profile not yet checked in stereo.

## Jak and Daxter Collection (BCUS98281, disc 01.00)

Notes: `profiles/BCUS98281-notes.md`. Evidence: `evidence/jak/`. Jak 1 (170-180 flat) and Jak II (~130 flat) are
real-time at any rate, so no patch; generated per-executable profiles, yaw audits coherent apart from Jak 1's indoor
sparkles. Jak 3 not started.

## Asura's Wrath (BLUS30721, disc 01.00)

Notes: `profiles/BLUS30721-notes.md`. Evidence: `evidence/asura/`. Community Unlock FPS (+ motion blur and depth of
field off): 90 FPS at Vblank 180, real-time; generated profile with `vblanks_per_frame 2`; stereo and yaw audit
look right in Episode 1. Sustained in VR at 300%: 120 Hz (Episode 1 space battle, 119.6 FPS at Vblank 240, no late
frames; savestate `vrtest_asura_space`, made with Compatible Savestate Mode).

## Anarchy Reigns (BLUS30632, disc 01.00)

Notes: `profiles/BLUS30632-notes.md`. Evidence: `evidence/anarchy/`. Fork patch *Frame rate follows VR* (instead of
the community 60 FPS) routes the characters' fixed 1/30 step through a word the profile sets: 90 FPS at Vblank 180,
walk and run speed equal to 60 FPS (1.5x without it). Scene at 1024x720; generated profile (after generator fixes)
`row_vectors [4, 24]`, HUD `c[54]` after the shader. Stereo, audit and the fake-headset HUD box are right in
Practice. Open: campaign, HUD sprite timers at 3x, headset run.

## Dante's Inferno (BLUS30405, disc 01.00)

Notes: `profiles/BLUS30405-notes.md`. Evidence: `evidence/dante/`. Frame-locked above 60 by a whole-frame clock;
the profile sets its frame interval (new key `game_frame_ms_f32`, `0x119ecb4`): real-time at 90 without a patch.
Generated profile (row vectors, five camera blocks, HUD `c[0]`); the HUD vanished in stereo until
`require_rigid_camera` (generator fixed to write it). Stereo, audit, pause menu right on the desktop.

## God of War Collection (BCES00800 v01.00, UK disc)

Notes: `profiles/BCES00800-notes.md`. Evidence: `evidence/gow/`. Profiles: `BCES00800.gow1.json`,
`BCES00800.gow2.json` and a base `BCES00800.json` for the launcher. The collection needs the base profile
so that OpenXR is prepared before the exitspawn into a game.

- **State:** desktop and headset-path verified; not played in the headset. Both games reach 90 FPS in
  stereo on the headset path (flat RSX load 10-45%).
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
