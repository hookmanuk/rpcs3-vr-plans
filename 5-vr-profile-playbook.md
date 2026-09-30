# Making a VR profile for a new game

This is the process that produced WipEout HD (`BCES00664`) and Pure (`BLUS30182`), written so it can be
repeated for any game. Each step says what to run, what to look at, and what the result must be before
moving on. The profile format itself is documented in `plans/profiles/README.md`.

A profile is a small JSON file, `rpcs3/bin/vr_profiles/<TITLE_ID>.json`. It tells the renderer three
things about the game's vertex constants:

1. **Which constants hold the camera.** These are 4-slot blocks holding the object-to-clip matrix, and
   the matrix layout they use.
2. **Where the camera position is.** This is optional.
3. **Which block is the HUD's screen-space matrix.**

The renderer does the rest: it renders each eye, applies head rotation and position, and fits the HUD
into a fixed box. Most of the work is finding those three facts, then proving that every draw which
should follow your head actually does.

Tools used below, all in `plans/tools/` unless noted:

| Tool | Purpose |
|---|---|
| `launch.ps1` | restart RPCS3 on a game with the inspector, probe file, optional stereo/audit/no-headset |
| `keys.ps1` | focus the game window and press keys (`W+X` = together); needs a keyboard pad profile |
| `f12shot.ps1` | RPCS3's own screenshot (eye 0), works in exclusive fullscreen |
| `sbsshot.ps1` | resize the game window and capture both eyes side by side (desktop, windowed) |
| `profile_survey.py` | analyse a one-frame capture: passes, camera blocks, layout, uncovered programs, camera position, HUD block |
| `keyboard-pad-template.yml` | temporary keyboard pad for scripted input |
| `pine.py` | live memory while the game runs, no relaunch: `info`, `read`/`write` (pointer syntax `[0x1050300]+0x14`), `dump` (1 MB in ~0.04 s), `find` a value, `watch` changes. RPCS3's IPC server (`bin/config/ipc.yml`, port 28012). Not frame-synced: per-frame logs, watchpoints and code patches stay with the `RPCS3_VR_PEEK` / `RPCS3_PPU_WATCH` / `RPCS3_VR_POKE` hooks |
| `tools/pair_eyes.py`, `tools/fit_stereo.py` (repo root) | only for games with native 3D: pair eyes and fit the game's own stereo |

Put evidence in `plans/evidence/<game>/` and findings in `plans/profiles/<TITLE_ID>-notes.md`.

---

## Step 0 - The game must run well in 2D first

- It must boot and run on the Vulkan renderer at your intended resolution scale.
- **Frame rate.** VR needs the headset's rate (72-120 Hz), or at least a steady 60 Hz reprojected by the
  runtime. A 30 fps game needs a frame-rate patch first. Pure's is documented in
  `plans/profiles/BLUS30182-notes.md`: PSGL swap interval forced to 1, plus the game's refresh constant
  set to the vblank rate. Check the game clock stays real-time: time a lap or a timer against wall time.
  This is what decides `match_headset_refresh_rate`.
- **Updates.** Check whether a later game update adds native 3D before you decide there's no native stereo.
- **Scripted input.** Copy `keyboard-pad-template.yml` to
  `rpcs3/bin/config/input_configs/<TITLE_ID>/Default.yml`. Start is `Return`, not `Enter`: the key names
  are Qt's. **Delete this file when you finish**, because it overrides the user's controller for this
  game.
- **Screenshots.** Window captures go stale in exclusive fullscreen, so use `f12shot.ps1` (eye 0 only).
  For stereo checks, run windowed and use `sbsshot.ps1`. Captures must be DPI-aware; the display is
  1920x1200 at 125%.

**Done when:** you can reach a representative gameplay scene from boot with a script, at target frame
rate, and screenshot it.

## Step 1 - Choose the scenes

Pick at least:

- **A:** a stationary, repeatable gameplay moment, such as a start grid or a paused tutorial prompt. Used
  for measurements.
- **B:** normal gameplay in the most complex environment: foliage, rocks, particles, water, many
  opponents.
- **C:** menus and the pause screen, because these often use different post-processing.

Programs that only appear in some scenes are the main way a profile goes wrong. Pure's rocks and sky
only showed up as problems in a real race, not on the tutorial start line. Write down the menu path to
each scene.

## Step 2 - Capture frames with the inspector

```powershell
plans\tools\launch.ps1 -Game 'F:/rpsc3/games/<game>.iso'
# ...drive to the scene...
New-Item "$env:TEMP\rpcs3-vrprofile\insp\ARM" -ItemType File   # arms exactly one frame
```

Each capture is a `<TITLE_ID>_<time>_stereo.jsonl` in the `insp` folder. Every draw record has the
program, the constants by original guest index, the render target and state, the fragment program id and
the bound textures. Capture every scene from Step 1. Also turn on `Log shader programs` in the game's
config. The logged shaders land in `rpcs3/bin/shaderlog/` as `VertexProgram<vp_session_id>.spirv` and
`FragmentProgram<fp_session_id>.spirv`, and you need them in Step 3. Turn logging off and delete that
folder afterwards.

**If the game has native 3D**, also capture the same scene with `3D Display Mode: Side-by-Side` and the
game's 3D prompt accepted. Then `tools/pair_eyes.py` finds the per-eye constants, and `tools/fit_stereo.py`
fits the game's exact stereo shear. That's how WipEout's values were fixed, and it gives a correct
classifier score for free (Gates 3-4 in `4-next-steps.md`).

## Step 3 - Survey the capture

```powershell
python plans\tools\profile_survey.py <capture.jsonl>
```

Read the output in this order:

1. **Render passes.** Note which targets have the output aspect (tagged); those are camera views. Other
   sizes are shadow maps, reflections, post-processing chains and luminance targets. They're eye-invariant
   unless proven otherwise.
2. **Candidate camera blocks, by layout.**
   - `rows`: `clip = v.x*c[b] + v.y*c[b+1] + v.z*c[b+2] + c[b+3]`. WipEout: `c[256]`, then `c[260]`.
   - `columns`: the DP4 transpose, `clip[i] = dot(c[b+i], v)`, which PSGL/Cg games use. Pure: `c[26]`,
     then `c[39]`.
   - Keep every block that more than a couple of programs use. A second block is normal: WipEout keeps
     view-projection in a second block when the first holds the object matrix, and Pure has a second copy
     for its ground clutter.
3. **UNCOVERED programs.** These are programs on camera-view targets that no chosen block covers, and
   they're what will appear head-locked in the headset. For each one, open its logged shaders and decide:
   - **Reads only `c[467]` or no matrix:** a full-screen quad (resolve, composite, post-process). It's fine
     as long as it samples per-eye targets, which it does.
   - **Reads the HUD block:** HUD, handled by `screen_space`.
   - **Does world geometry with a different block:** add that block to `camera_blocks`. Pure's rocks were
     this case: `c[39..42]`.
   - **Computes the view in the fragment shader** (a sky or fog quad driven by fragment constants): not
     fixable by a profile. Record it and raise it as renderer work.
4. **Blocks with no z slot.** Marked `(no z slot: z = w)`. These are DP4 programs that take clip z from
   the w row, usually a sky on the far plane (Pure's `16991145`: `c[26]`, `c[27]`, `c[29]`). The renderer
   supports this for `column_vectors` only. If a row-vector game needs it, that's a code change.
5. **Projection.** A = |x|/|w| and B = |y|/|w|. B/A should equal the output aspect (16:9 → 1.778). A
   second cluster at another scale is a lower-resolution pass: WipEout's 640x360 pass runs at 0.75×. The
   horizontal FOV is `2*atan(1/A)`.
6. **Camera position slot.** A `w = 1` constant equal to the eye point solved from the matrix: WipEout
   `c[465]`, Pure `c[18]`. Games use it for specular and fog; each eye moves it by half the baseline.
   If there isn't one, leave `camera_position.slot` out.
7. **HUD block.** An orthographic block with pixel-scale entries (Pure and WipEout: `c[256]`). Check it in
   a gameplay capture, not just menus.

Also check for **stray matches**. With more than one block listed, an unrelated program can happen to hold
a perspective-looking matrix in one of them. Pure's `dc11dd79` is a post-process quad with arbitrary data
in `c[39..42]`. If any listed block is only perspective by accident, set `"require_rigid_camera": true`,
which requires the clip x, y and w directions to be orthogonal. Don't set it for games whose object
matrices carry non-uniform scale (WipEout).

## Step 4 - Write the profile

Start from Pure's file (`column_vectors`) or WipEout's (`row_vectors`).

- `camera_blocks`, `matrix_layout`, `require_rigid_camera`, `camera_position.slot` and
  `screen_space.orthographic_block` all come from Step 3.
- **World scale, `eye_baseline`.** This is the game's distance between the eyes in world units. It also
  sets the scale for head tracking: `eye_baseline` units equal your IPD.
  - With native 3D, use the game's own value (WipEout: 0.240).
  - Otherwise, check the units. When the w row is unit length, w is view depth in world units. Compare
    known sizes: the distance from camera to player, a vehicle's length or a doorway. If the units are
    metres, `0.064` gives 1:1 scale (Pure).
  - `RPCS3_OPENXR_EYE_SCALE` can tune it later in the headset.
- **Stereo shear**, `clip.x += sep*(clip.w - conv)`.
  - With native 3D, use the fitted values, including the per-target-width rules.
  - Otherwise, the headset keeps only `sep*conv`, which must equal `A * eye_baseline / 2`. Choose `conv`
    near the player's subject distance and solve for `sep`. Pure: A = 1.3006, eye_baseline 0.064 →
    `sep*conv` = 0.0416; conv 2.6 → sep 0.016.
- `reference_screen_width` is only needed if the game's native 3D was tuned for a TV size.
- `match_headset_refresh_rate: true` only if Step 0 proved the game clock stays real-time when the
  vblank rate changes, **with nothing else fixed at boot**. Pure's refresh rate is a patch value, so it's
  off there.

The loader validates the file on boot. The log shows `VR profile loaded for <id>: camera blocks ...`, or
the invalid field with its line and column. A bad file leaves VR off and the game in 2D.

## Step 5 - Prove the camera on the flat route (probes)

Run with VR disabled in the game config and write probe lines to the probe file, one per scene. Each is
re-read every frame against the same booted scene.

| Probe line | Expected |
|---|---|
| (empty file) | baseline |
| `yaw=10`, `roll=10`, `pitch=10` | the whole world turns coherently; HUD fixed |
| `tx=1`, `tz=1` | the world moves; HUD fixed |
| `stereo=0.05,conv=<c>` | far scenery shifts `0.05 * output_width/2` px; objects at depth `c` don't move; HUD 0 px |
| `slot=400,comp=0,add=100` (a slot nobody reads) | same as baseline: the negative control |

The log prints a classifier report per probe (`perturbed / rejected off-aspect / rejected no
perspective`), and the negative control must perturb 0. Measure shifts numerically, for example by
cross-correlating image strips. For stereo, pick regions with texture detail, because a translucent HUD
panel matches the world behind it. The unrotated baseline must match a second baseline to within the
noise floor. Measure that noise first; ambient animation isn't zero.

**Done when:** every axis moves the world, the HUD never moves, and the negative control is noise.

## Step 6 - Stereo on the desktop

```powershell
plans\tools\launch.ps1 -Game <iso> -Probe 'render=1' -NoHeadset
plans\tools\sbsshot.ps1 -Out sbs.png
```

Check each of these, in every scene from Step 1:

- **Disparity.** Far scenery at `2*sep*eye_width/2` px, the HUD at 0, near objects crossed. Pure at 533
  px per eye: far +8 (expected 8.5), HUD 0, rider −5.
- **Both eyes identical apart from parallax,** especially after post-processing: bloom, blur, tone
  mapping, pause-screen effects. A difference means a render-target operation isn't mirrored to the right
  eye. For each suspect draw, see which texture addresses it samples (the capture's `textures`) and who
  writes them.
  - **Blits** (NV3089) between render targets are now mirrored (`VKGSRender::vr_mirror_blit`). Pure
    needed it: its frame reaches the display buffer by blit, so the pause blur was missing in one eye.
  - Partial clears and instanced draws are still not mirrored. If a game needs them, that's code work.
    `plans/evidence/pure/instanced-per-eye.patch` is an untested starting point.
- **Frame rate.** Compare against Step 0. With stereo, it should still reach the vblank rate at your
  resolution scale.

## Step 7 - Rotation audit (desktop stand-in for the headset)

```powershell
plans\tools\launch.ps1 -Game <iso> -Probe 'render=1' -NoHeadset -Audit 25          # yaw
plans\tools\launch.ps1 -Game <iso> -Probe 'render=1' -NoHeadset -Audit 'pitch:35'  # look up
```

The right eye is rotated through the same classifier and rotation as the headset, and the left eye stays
the game's view. **Test in real gameplay (scene B) and look up at the sky.** Pure's two remaining bugs
only showed there.

- **Floating objects in the sky, or anything in the same screen place in both eyes:** a program the
  camera blocks don't cover (Step 3, item 3). Pure's rocks.
- **Sky with a hard white or haze band, or a sky that "moves with you":** a sky draw not covered, often
  one without a z slot (Pure's sky), or a fragment-shader sky.
- **Black regions at the edges:** geometry the game culled against its own frustum. This is expected for
  large head turns and can't be fixed by a profile.
- **The HUD:** it must stay where it is in both eyes.
- **Image scale (world swims on head turns):** measure it. Run the audit through the headset remap
  (`$env:RPCS3_VR_AUDIT_FOV = '1.0'` before `launch.ps1 ... -Audit 15`), screenshot with the
  `RPCS3_VR_SHOT` hook, then `tools/rotation_audit.py <shot> --yaw 15 --proj 1,1 --fit-scale`.
  It must report k = 1.00. k > 1 means the final image is zoomed against the game's projection, usually a
  screen-size/overscan option: ICO measured 1.17 with "Full pixel mode" off and 1.00 with it on.

Make before/after images of the rotated eye for each fix: `plans/evidence/pure/*-before-after.png`.

## Step 8 - Headset

Enable `Video > VR > Enabled` in the game's custom config. The option is only offered once a valid
profile exists. Launch without the development variables and with SteamVR running. Check:

- **Scale.** Does the vehicle or player look life-sized? Adjust `eye_baseline`, or try
  `RPCS3_OPENXR_EYE_SCALE` first.
- **Head turns.** Look behind, up and down: nothing may stay attached to your face.
- **HUD box.** Check size and position, and the Fixed and Head-locked modes in the home menu's VR tab.
- **Pause menu, menus, loading screens** and the RPCS3 overlays.
- **Comfort and frame pacing** over a full race or level.

Every problem found here should become a Step 7 reproduction on the desktop before you fix it.

## Step 9 - Record and clean up

- Evidence: captures, before/after images, measurements in `plans/evidence/<game>/`.
- Notes: slots, reasoning and open issues in `plans/profiles/<TITLE_ID>-notes.md`.
- New profile fields go in `plans/profiles/README.md`; progress goes in `plans/4-next-steps.md`.
- Delete the temporary keyboard pad, `rpcs3/bin/shaderlog/`, and any `Log shader programs: true`.
  Leave `VR > Enabled` on if the profile works.

---

## Known traps

| Symptom | Cause | Fix |
|---|---|---|
| Objects hang in view when looking up | their program keeps the camera in another block | add that block to `camera_blocks` |
| A second picture of the scene inside a portal, refraction or glass, moving with the view (only in the headset) | the refraction program's block is listed but fails the rigid test (object scale folded in), so it keeps the game camera and samples the scene with the game's projection. Check the block's clip x/y/w orthogonality from a capture; list it in `nonrigid_camera_blocks`. The desktop audit does not show it (same projection) | Demon's Souls (`c[4]`, fog gates) |
| Empty frames or icons just outside the HUD box | HUD elements parked off the game's screen; clipped to the box by the renderer since fork 2f18a88b | Demon's Souls |
| Sky moves with the head; white or haze band | sky program omits the z slot (z = w) | supported for `column_vectors`; else code |
| An unrelated full-screen quad gets rotated | stray data in a listed block looks perspective | `require_rigid_camera: true` |
| One eye misses blur or bloom | a render-target blit or copy isn't mirrored | blits mirrored; others need code |
| A particle, glow or flame only in one eye, or with the wrong sprite in the left eye | was a renderer bug (left-eye push constants lost when a draw sampling its bound depth ended the pass); fixed in fork 2dc5848f. To diagnose others: compare with `render=0`, `hide=<program>`, and `RPCS3_VR_BATCH=0` (no right-eye batching) | fixed in the renderer (Demon's Souls) |
| One eye black in a movie or 2D screen that depth-tests | right-eye surfaces were never initialized, so stale depth rejected the draw | fixed in the renderer (fork 50f7c0ea, Ridge Racer 7) |
| Game runs double speed at 90/120 Hz | its clock counts vblanks, not time | fix it in the frame-rate patch; keep `match_headset_refresh_rate` off |
| Scripted Start key does nothing | Qt key name is `Return` | use the template |
| Screenshots never change | exclusive fullscreen | `f12shot.ps1`, or windowed with `sbsshot.ps1` |
| Controller stops working | temporary keyboard pad left in `input_configs/<id>/` | delete it |
| Setting `RPCS3_VR_PROBE_FILE` disables stereo | the file replaces the default `render=1` | put `render=1` in the file |
| Camera keeps pushing into walls and snapping back, even with VR off | a Wider view patch's FOV also reaches camera logic (SotC: framing uses tan(fov/2) of the render view) | find the readers (`RPCS3_PPU_WATCH_FILE` read watch, getter call sites), try fixes live with `RPCS3_VR_POKE` under the interpreter, give camera logic fov / Scale (SotC patch 1.2) |

---

## In-emulator generation (implemented 2026-09-23)

In a game without a profile, **home menu > Settings > VR** shows one button, **Generate VR Profile**.
Pressing it closes the menu. After 30 frames it samples the running game's vertex constants: one frame
every 0.5 s over 10 s of play (time while paused or stalled doesn't count). It then runs Step 3's analysis in C++ (`rsx::vr::profile_generator`,
`rpcs3/Emu/RSX/Capture/rsx_vr_profile_generator.cpp`), writes `bin/vr_profiles/<TITLE_ID>.json`, loads it,
and turns `VR > Enabled` on in the game's custom config. Stereo starts at once; the headset needs the
game restarted. Every choice goes to the log (channel `VRGEN`): candidate blocks, the rigidity decision,
the camera position match, uncovered programs, and coverage. If there's no perspective camera (a menu,
not gameplay), it shows a failure notice and writes nothing.

Tested on both games with the profile removed and VR off, by pressing the button during a race.
Evidence is in `plans/evidence/generator/`.

| | Pure (generated / hand-made) | WipEout (generated / hand-made) |
|---|---|---|
| layout, blocks | `column_vectors [26, 39]` / same | `row_vectors [256, 260]` / same |
| rigid check | on / on | off / off |
| camera position | `c[18]` / same | `c[465]` / same |
| HUD block | `c[256]` / same | `c[256]` / same |
| half-res rule | none / none | 640 wide 0.739x / 0.75x |
| `eye_baseline` | 0.064 / 0.064 | 0.338 / 0.240 (native 3D) |
| `bare_projection` | - / - | not sampled / true (menu only) |

**World scale** comes from the near plane. Engines place it at a similar real distance, and Pure's is
exactly 0.1 m, so `eye_baseline = 0.064 * near / 0.1`. WipEout's near plane is 0.53 units, which gives a
world about 30% smaller than its native-3D tuning. **home menu > Settings > VR > World Scale** corrects
this in the headset: 100% is the profile's scale, and WipEout's native scale is about 140%.

**Per-target-width stereo rules** come from each render-target width's own projection, which is how
WipEout's half-resolution pass gets 0.75x.

**Frame rate** (added 2026-09-25) comes from game frames per second of play against the vblank rate.
A game drawing every second vblank (ICO: 30 at 60 Hz) gets `vblanks_per_frame: 2`. The measured rate is
written as both `max_fps` and `default_fps`, so the Frame Rate setting never offers more than the game was
seen doing. Raising `max_fps` (or `0`, no maximum) needs the game clock checked against real time at a
faster vblank, as for WipEout and Pure. A game that ran slow while sampled logs "uneven" and may get too
low a rate.

**Scene coverage and HUD passes** (added 2026-09-25, after Demon's Souls). The generator records per draw
whether it depth-tests and whether it samples ordinary textures or colour render targets. Camera coverage
is measured over depth-tested draws that don't read colour targets; below 80% it writes
`clip_space_scene_draws` (the renderer then moves those draws with the camera draws' eye transform). An
orthographic block is only taken as the HUD block if full-screen passes (draws sampling colour targets)
don't also read it: Demon's Souls reads `c[0]` for both, and its scene composite was drawn into the HUD box.

**Camera-relative engines and shared HUD blocks** (added 2026-09-25, Demon's Souls; notes in
`profiles/BLUS30443-notes.md`). Programs with indexed constants are sampled by the slots they read
directly, so a camera beside bone matrices is found. A camera block at the origin (view rotation and
projection only) is not used to find the camera position. A `row_vectors` HUD block may lack the z slot.
When full-screen passes read the HUD block too, the generator keeps it and writes `hud_skips_passes`.
Every generated profile gets `stereo.eye_offset: "baseline"`, so a Wider view patch doesn't change the eye
distance.

**Screen-space HUDs and world scale** (added 2026-09-25, Ridge Racer 7; notes in `profiles/BCAS20001-notes.md`).
Full-frame draws without depth test that read no matrix block and sample ordinary textures are a
screen-space HUD: the generator writes `passthrough_hud`, plus `hud_programs` for programs that draw into
a target camera draws wrote that frame. World scale: a near plane from 0.01 to 1 means metres
(`eye_baseline` 0.064); the near/0.1 rule only applies outside that range.

**Frame-locked games.** The generator writes the measured rate as `max_fps`. Check real-time speed before
raising it: run at a faster Vblank Rate and compare an in-game timer with wall time. A frame-locked game can
still reach the headset rate with a game patch plus the profile's frame-timing fields (Ridge Racer 7, 2026-09-26;
method in `profiles/BCAS20001-notes.md`):

1. Physics: find the static 1/60 floats (dump, search 0x3c888889) and list them in `game_frame_time_f32`.
   Measure camera metres per frame before and after to confirm.
2. Timers and counters: two memory dumps (`RPCS3_VR_MEMDUMP`, now 0-0xbfffffff) a few seconds apart at 90 Hz,
   next to screenshots of the on-screen clock; search values changing at the wrong rate in every unit (frames,
   ms, 1/3000 s, float s). Counters in dynamically allocated memory move between runs: find them in the same
   session from a signature (neighbouring words or a vtable), then `RPCS3_PPU_WATCH_FILE` installs the PPU
   interpreter store/read watch on the address found. Look-alike counters are common; confirm each fix against
   the displayed clock, not the dump.
3. Patch each writer with a code cave adding `floor(k*A/fps) - floor(k*(A-1)/fps)` (A = the game's vblank
   count, fps from a `game_fps_u32` word) instead of its constant step. Never slow a counter the renderer uses
   (RR7's global frame counter indexes GPU buffers: deadlock). A field incremented at many sites gets one
   correction per frame after the update instead.
4. Verify at 60 Hz too: the caves must reduce to the native steps.
   A fixed-step game with one step-length constant in read-only data (Gran Turismo 5: `0x14017f8`, read through a getter) can't be fixed by listing that address: PINE and patches can't write it. Patch the getter's `lis`/`lfs` to read a word in the data/bss segment instead (the heap is unmapped when patches apply, so a patch write there silently fails), and put that word in `game_frame_time_f32`. `profiles/BCUS98114-notes.md`.

**Never generated.** These need the game looked at in the headset or reverse-engineered. After generating,
check for each symptom:

| Symptom in the headset | Field (see `profiles/README.md`) | Found in |
|---|---|---|
| Menus or HUD fill the whole view instead of the HUD box | `screen_space.passthrough_hud: true` (generated since 2026-09-25 when the HUD is matrix-less) | ICO, Ridge Racer 7 |
| Menu/title text drawn into the 3D scene's final image stays full-view | `screen_space.hud_programs` (the program's ucode hash from an inspector capture) | SotC |
| HUD box right, but menu text scrambled and HUD elements leave trails when the head turns | fills/clears in output-pixel units boxed with the HUD (they write text coverage and clear the screen): `screen_space.output_pixel_draws_not_hud`; font atlases in view-aspect targets: `hud_display_buffers_only`; text clip masks from the projected position: `hud_box_after_shader`. Test head motion with `RPCS3_VR_WOBBLE=20` | Gran Turismo 5 |
| Rear-view mirror stuck to the head at the top of the view | `screen_space.subviewport_cameras_in_box` (with `hud_box_after_shader`) | Gran Turismo 5 |
| Car/object shadows turn odd colours (green in one eye, magenta in the other) | a shadow map rendered into a display buffer's memory is being HUD-boxed; the display-buffer test must match size, not only address (fixed in the fork for `hud_display_buffers_only`) | Gran Turismo 5 |
| 2D menus leave trails outside the HUD box when the head turns | the game never clears the display buffer; `hud_display_buffers_only` clears the shown region before the first boxed draw of a frame | Gran Turismo 5 |
| 3D world black in gameplay, HUD and menus fine | the game reads its frame back on the CPU: `Write Color Buffers` and `Read Color Buffers` on in the game config (WCB alone was not enough) | Killzone HD |
| Picture soft or washed out only in VR, sharp flat | the game's dynamic resolution reacting to the stereo cost: disable it with a patch | MotorStorm Pacific Rift |
| Stereo FPS far below flat, `cached_texture_section::flush` high in `rsx_sample.py rsx::thread` | the game samples render-target memory as plain textures each frame (needs Write Color Buffers); flushed ranges are copied early in stereo since 2026-09-30 (log "copied early from now on"; MotorStorm gain small); what is left is the wait for the same pass's right-eye work. Measure from fresh race starts, not Pause > Restart | MotorStorm Pacific Rift, GT5 |
| Frame rate low with many objects in view, GPU not busy | profile the RSX thread: `python plans/tools/sampler.py <pid> 8 rsx::thread` (no admin; needs `rpcs3.pdb`); compare with flat at the same moment | Gran Turismo 5 |
| Menu or HUD text missing in the headset, appearing when the head moves back | HUD drawn with depth test on but no depth buffer / ALWAYS; the box kept its z (fixed in the renderer 2026-09-30: such a test no longer counts). Check the inspector `state.depth_func` (519 = ALWAYS) and `rt.zeta_address` | Killzone HD |
| Outside the HUD box turns white (or bright) on a 2D screen | the screen's background is boxed and a glow/bloom pass over the whole display buffer feeds on the unwritten outside: `screen_space.clear_outside_box: true` | Killzone HD |
| Aiming reticule (or another HUD element) huge or too close | `screen_space.scaled_draws` for its draw (find it in an inspector capture: HUD matrix, small texture, drawn near the screen centre); HUD distance is the HUD Depth setting | Killzone HD |
| One eye (left) much softer than the other at a raised resolution scale | the game copies memory into the display buffer (inspector `nv0039` notes after the last draw) and Read Color Buffers reloads the left surface at 1x: `keep_rendered_display_buffers: true`. Measure with `RPCS3_VR_RTDUMP` per eye | Killzone HD |
| The HUD box has a grey or tinted panel behind it in game | a full-screen overlay (film grain, vignette, tint) drawn with the HUD matrix is boxed: `screen_space.unboxed_draws` (find it with probe `unboxfp=`) | Killzone HD |
| Splash screens and menus ultrawide and head-locked until the first 3D frame | the projection layer waited for a game camera; fixed in the renderer 2026-09-30 (layer uses the headset FOV from the first frame) | Killzone HD |
| A movie stays black (or frozen) at a raised Vblank Rate, fine at 60; the log repeats "cellVdec: Video au decode has been waiting for a consumer" | the movie player paces itself by the vblank: `video_vblank_rate: 60`. Beware: screenshots (SHOT hook, F12) force a GPU sync that can keep such a player going, so test without them | Killzone HD |
| Menus look different from run to run in the headset (full view vs boxed) | boxing used to wait for the game's first camera draw; since 2026-09-30 menus are boxed from the first headset frame | Killzone HD |
| Menu layers reorder or vanish when leaning in (HUD depth-tests itself) | `screen_space.hud_keep_depth: true` | SotC |
| HUD (or menu text) sheared/rotated with the world although the scene is fine; the scene camera is a bare projection too, and the HUD draws use the same slots with another aspect (4:3 in a 16:9 game) | `screen_space.offaspect_projection` (generated since 2026-09-30) | God of War HD |
| A collection's second executable gets no headset session (desktop-only stereo; no `OpenXR:` lines after the switch) | the renderer for an exitspawned executable is built before the title ID is known: give the collection a base `<TITLE_ID>.json` (the launcher then prepares OpenXR, which survives the switch) | God of War Collection |
| Sprites (flames, glows) drift away from their source | `screen_space.preprojected_programs` | ICO |
| Reflections or light pools on the ground follow the head | `offaspect_player_views: true` when the reflections are drawn with the player's camera into an off-aspect target and sampled at screen position. Find the drawing program with probe `hide=<vertex hash>[@<target>]` and `RPCS3_VR_RTDUMP` diffs | Ridge Racer 7 |
| Light glows, streaks or particles float in the HUD box, sliding toward the view centre | view-space particles with a bare projection: `bare_projection: false` (the generator now only sets it without depth test) | Ridge Racer 7 |
| Scene edges soft at every resolution scale while the HUD is sharp | a post pass with filter-tap offsets in vertex constants: find the full-screen pass that samples the scene (inspector + `Log shader programs`), then `resolution_scaled_constants` with its program and offset slots | Ridge Racer 7 |
| Floor, view edges or top of the view blurred or doubled; the centre sharp (not the HUD: hiding the HUD programs leaves it) | the game's depth of field, often with a blur that grows from the screen centre. Find its passes with probe `hide=<vertex hash>` (hiding the blur passes makes it sharp), read the composite's fragment shader for the blend-strength constant, then `fragment_constant_overrides` with the composite's program and that constant set to 0 | Demon's Souls |
| Frame rate drops only in busy scenes while GPU use stays low | find the bottleneck thread with `tools/threadcycles.py`, then `tools/rsx_sample.py rsx::thread 10`; `RPCS3_VR_GPUPROF=1` gives per-frame RSX/GPU breakdowns and right-eye rebuilt copies. Games in lockstep with the RSX thread are bounded by its per-draw work, which stereo roughly adds to | Ridge Racer 7 (right-eye cube-map rebuilds, fixed in the renderer) |
| Wheels, glows or other scaled objects stay head-locked while the scene turns | `require_rigid_camera: false` (their object matrices fail the rigidity test); check nothing off-scene gains the rotation. The generator no longer sets rigidity from depth-tested scene draws (2026-09-26) | Ridge Racer 7 |
| A huge stretched wedge in one eye (menus, cutscenes); or scene and sprites need different matrix layouts | a full-screen pass reads the camera slots in the other layout (an orthographic matrix that looks perspective when transposed): `require_rigid_camera`; sprites in the other layout: `row_vector_blocks`; a HUD in the other layout: `orthographic_block_layout` (read the HUD program's shader first: Bayonetta's HUD did not need it) | Bayonetta |
| Characters (or anything moving) smeared or haloed in the headset only, sharp on the desktop | motion blur whose velocity pass keeps the previous frame's view-projection beside the camera; only the camera gets the head transform. Find a program reading two near-identical perspective blocks (`bf6c93fc`: `c[8]` and `c[36]`), then `linked_camera_blocks`. Reproduce with `RPCS3_VR_AUDIT_FOV=1.0` and `-Audit 15` | Bayonetta |
| Splash screens and videos fill the view | `screen_space.frames_without_3d_as_screen: true` | ICO |
| "Cutscenes locked to 30 FPS" | check whether they are videos: no draws and no game flips while they play (RPCS3 only re-shows the buffer by its UI refresh). Nothing to unlock; `frames_without_3d_as_screen` puts them on the fixed screen (UI refreshes during a flip gap count as frames without 3D since fork 77382a4b) | Demon's Souls |
| Glow or blend layers trail head turns; a ghost of bright-edged objects on fast head turns at full frame rate | `reproject_older_frames: true` (the game blends the previous frame), plus `current_frame_copies: true` if it composites an older scene copy. Reproduce with `RPCS3_VR_WOBBLE=30` | ICO, SotC, Killzone HD |
| Walls or sky missing when looking around | a "Wider view" patch for the game's culling, then `stereo.eye_offset: "baseline"` so the wider projection keeps the eye distance; then check the camera logic still sees the game's own FOV (Known traps) | ICO, SotC |
| Objects flash or pop in (CPU/SPU occlusion culling on the depth buffer) | `occlusion_depth_readback` | SotC |
| The game's clock runs fast or slow at a changed vblank | `game_refresh_rate_f32` | Pure, SotC |
| One game of a collection needs different values | the generator already writes `<TITLE_ID>.<executable>.json` beside an existing `<TITLE_ID>.json` | SotC |

Also never generated: `reference_screen_width` (only matters for native-3D TV tuning), and
`bare_projection` unless such a draw is sampled (WipEout's main-menu particle cloud isn't seen in a race).

**Keeping the generator current:** when a game's profile work teaches something measurable from vertex
constants or frame timing, add it to the generator; otherwise add its symptom to the table above.

Generate during the busiest gameplay, then check with Step 7. The playbook is still the process for
fixing what it gets wrong.

## Toward profiles generated inside the emulator (original assessment)

The goal is for end users to make their own profiles from inside RPCS3. How feasible that is depends on
the step.

**Automatable now, with work (the heavy lifting):**

- Steps 2-3 are mechanical. `profile_survey.py` recovered **both** existing profiles from a single flat
  capture each. For WipEout: `row_vectors`, `[256, 260]`, `c[465]`, HUD `c[256]`. For Pure:
  `column_vectors`, `[26, 39]`, the z-less sky, `c[18]`, HUD `c[256]`. Porting it to C++ over the
  existing inspector, and running it **continuously in the background across many frames and scenes**
  instead of once, would fix the "a program only appears in the race" problem. The emulator would
  accumulate per-program statistics while the user plays, then write a draft profile.
- Stereo values without native 3D follow from the projection and an assumed unit scale, as above. With
  native 3D, the Gate 3-4 fit could also run in-app: capture the 3D mode once and fit.

**Needs the user, but can be guided:**

- **Validation.** Steps 5-8 are judgments about pictures. In-app, this could be a "VR profile wizard" in
  the home menu:
  1. "Drive or walk somewhere busy, then press Capture."
  2. A preview with the camera rotated (the audit), showing **uncovered draws tinted red**, so anything
     that would stay stuck to the face is obvious.
  3. Sliders for world scale and HUD box.
  4. Save.
- The red tint doesn't exist yet. It's a debug colour on draws the classifier leaves on the game camera,
  and it would make Step 7 a glance instead of an investigation.
- **World scale** can't be inferred reliably, so it needs a slider in the headset.

**Not automatable (per game, by a developer):**

- **Frame-rate patches.** They need PPU reverse engineering, and a 30 fps game is unplayable in VR
  without one.
- **Cameras not in vertex constants:** CPU-pretransformed vertices, cameras computed in the fragment
  shader (sky or fog quads driven by fragment constants), split-screen or multiple viewports.
- **Renderer gaps** such as unmirrored partial clears, instanced draws, or a matrix layout the code
  doesn't know. These are code changes, not profile values. Each one fixed once helps every later game.

**Realistic estimate:** for the common case of a 3D game whose camera is a standard matrix in vertex
constants (both games so far), an in-app auto-profiler plus a guided validation screen could produce a
working profile with no manual analysis. The user would still need to do the rotated-view check and set
world scale. Games needing a frame-rate patch, or games that break the assumptions above, would still
need someone following this playbook. The next useful steps, in order:

1. The red-tint debug view.
2. Multi-frame background accumulation in the inspector.
3. The C++ port of `profile_survey.py` writing a draft JSON.
4. The home-menu wizard.
