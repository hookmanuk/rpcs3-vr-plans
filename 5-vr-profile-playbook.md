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
- New profile fields go in `plans/profiles/README.md`; game progress goes in `plans/6-wip-games.md` (generic renderer work in `plans/4-next-steps.md`).
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
| The level (or part of it) is a flat window that shears with head turns; a straight seam through the scenery | a program-wide box rule caught world draws (R&C 1's `boxed_camera_programs` listed its two world programs) | box menu cameras by their clip-w row: `screen_space.boxed_cameras` |
| A faint 16:9 rectangle over the world (brighter or darker inside the HUD box) | a full-screen pass reads the HUD block (identity world matrix there) and is boxed: only the box gets this frame | `hud_skips_passes: true` (Asura's Wrath, pass `5c313870`); probe `why=<hash>` shows `box 1` |
| A menu flickers between the fixed screen and stuck to the face | the menu's frames alternate between "camera draws" and none (a 3D element classified only some frames) | `screen_frame_draws` with a draw only that menu makes (GoW 1 Power Up: `a3b1455d`, 512x512) |
| An intro or logo animation is at an odd angle or missing in the headset | a real-time 3D animation through a camera: the headset view turns it with the head | `screen_frame_draws` for its programs (GoW Collection selector intro) |
| A movie stuck to the face although 2D frames go on the screen | the game renders 3D behind the movie (the next level loading), so the frame counts as 3D | `screen_frame_draws` with the movie draw (YUV planes in main memory; Dante's Inferno `2f7541c3`, 1280x736) |
| Characters and the world look tiny (or huge) | `eye_baseline` from the near-plane guess | measure a character (Measuring world scale, above) |
| Skinned characters stay head-locked (same screen spot at every head turn) with stretched limbs, the world turns | the program indexes a palette of full clip matrices (`_fetch_constant(256 + a0.x)`): only bone 0 is the camera block | `camera_palette: [first, last]` (Kingdom Hearts) |
| Light beams or sparkles vanish in stereo; their block holds huge numbers (pixel-space projection) | a PS2-port effect projected to GS pixels and converted to NDC with `c[0..2]` | `require_rigid_camera: true` + `preprojected_programs` (Kingdom Hearts `b7585fdc`) |
| The game looks very dark and small in the headset, fine flat | a narrow game camera (Puppeteer 45 x 26 degrees): the lit scene covers a small part of the headset view, the rest black. Compare brightness per lit pixel, not frame means (`RPCS3_OPENXR_FOV=game` vs default, same savestate and moment) | a smaller world (`eye_baseline` up: a diorama nearer) and the VR menu's Camera Depth Offset (Puppeteer) |
| Trails, or a velocity/motion target that varies across the screen in the headset view only | the velocity pass reads the previous frame's rows beside the camera (Puppeteer `c[264]`, `c[265]`, `c[267]`): dump the velocity target with RTDUMP | `linked_camera_blocks` with the previous block's base (a missing z slot is fine for `column_vectors`) |
| Game runs fast above 60 although a community 60 FPS patch works at 60 | the frame step is "vblanks elapsed", each counted as 1/60 s (Kingdom Hearts). Find the limiter from the 60 FPS patch's site, the step's factor, a free word near it (`tools/re/absrange.py ELF LO HI --gaps 40`, then PPU read/write watches while playing), and make the step read the word | `game_vblank_frames_f32` (60 / vblank rate) on that word; measure with `tools/re/kh_rt.sh` + `rthist.py` (x1.0 at every rate) |
| A movie stays black at the headset rate ("waiting for a consumer" in the log) | the movie player paces by the vblank | `video_vblank_rate: 60` (Killzone HD, both Kingdom Hearts) |
| Need a savestate but the desktop is locked (Ctrl+S does nothing) | the game window gets no keys | create `$Work\SAVESTATE` (`RPCS3_VR_SAVESTATE`, set by `launch.ps1`) |
| In the headset part of the scene (particles, text) sits in the HUD box while the rest of the scene stays in the world | the generator wrote `depth_offset_projection` (draws with `w = z + d`, taken as a 3D HUD as in Blur), but the game draws its whole scene in camera space at a fixed depth (a planet 34.2 units ahead). Check: an inspector capture shows depth-tested `w = z + d` draws that are scene (hide them with `hidden_draws` to see what they are) | remove `depth_offset_projection`; check with the OpenXR Simulator, head straight and turned (the desktop audit does not apply the rule) | Super Stardust HD |
| Menus uncomfortable in the headset (3D text at an odd depth, a background that keeps rolling), but no draw is unique to them | the front end uses the same programs and textures as gameplay (compare inspector captures by vertex program + texture 0), so `screen_frame_draws` cannot mark it | find the game's state word: memory dumps on several menus and in play (`RPCS3_VR_MEMDUMP`), `py tools/re/statevar.py PLAY,... MENU,...` (from `tools/re`) lists words constant in play and different on every menu; log the candidates with `RPCS3_VR_PEEK` through a fresh boot (menus, play, pause, game over) and keep the one that switches exactly there; `screen_space.screen_frames_when` | Super Stardust HD |
| A patch can't be tested on a savestate (RPCS3 applies no patches when a state loads) | the fork's patch key `Apply To Savestates: true` applies it on load too (code patches are idempotent; leave it off for patches that write data the game changes at run time) | Asura's Wrath culling |
| Camera keeps pushing into walls and snapping back, even with VR off | a Wider view patch's FOV also reaches camera logic (SotC: framing uses tan(fov/2) of the render view) | find the readers (`RPCS3_PPU_WATCH_FILE` read watch, getter call sites), try fixes live with `RPCS3_VR_POKE` under the interpreter, give camera logic fov / Scale (SotC patch 1.2) |
| With a Wider view patch, characters (and other skinned or EDGE meshes) lose triangles: holes, "corrupted" people in the headset; draw counts unchanged, vertex counts fall as the scale rises | EDGE geometry (SPU) culls triangles that cover no pixel of the game's viewport; the widened projection shrinks everything on that viewport | find the `EdgeGeomViewportInfo` (scissor u16 x4, depth range, transposed VP, viewport scales, offsets: search memory for the viewport scale/offset floats next to a VP) and its PPU setters; multiply scales, offsets and scissor by a factor >= tan(wide/2)/tan(base/2) (Dante 3.0: 20) |
| With a Wider view patch, small objects or effects (fire, torches) vanish | a screen-size metric from the camera's stored FOV (radius / (tan(fov/2) x distance)) culls them | find the reader of the stored FOV (read watch) and give it fov / Scale (Dante 3.0, `0x65e8f0`) |
| Whole buildings missing in cutscenes, or distant objects popping in as the camera (or head) moves, with a narrow (zoomed) game camera | the game culls to its own frustum; widening the game's FOV to cover the headset would be extreme (Asura's cutscenes are 22-40 degrees) and changes LOD | widen only the culling frustum: find where the scene view builds it (Unreal Engine 3: a `bl GetViewFrustumBounds` with `r3 = view + frustum`, `r4 = view + view-projection`, `li r5, 0`; the function has DELTA^2 = 1e-10 just before it) and pass it a copy with clip x and y scaled down, in a cave over a function the VR patches already disable. Prove it first with `RPCS3_VR_POKE` under the interpreter (branch the side planes' skips). Asura's Wrath (`tools/re/asura_cull.py`) |
| Glows or sprites at lights (torch halos, coronas) move with the head while the world stays put | the game projects them itself (no camera block: clip position computed on the CPU, often drawn with depth test off), so the renderer draws them as the game placed them in its own view | inspector capture: small blended draws into the scene target with no camera block; confirm with `hidden_draws` on the simulator at two head angles; list the program in `screen_space.preprojected_programs`, as `{ "program": ..., "without_depth_test": true }` when drawn without depth test (Dante's torch glows) |

---

## VR frame-rate measurement (2026-10-01)

**Pass mark: 72 Hz.** A game is fully VR compatible when it **sustains 72** in stereo at **Resolution Scale
300%**: run at a fixed rate like a headset (Vblank = rate x vblanks per frame) while the player moves, after the
game has settled, with **under 1% late frames** (a late frame takes over 1.5x the median frame time) and an **average of at least
99% of the rate** (in RPCS3 a frame that misses its vblank is presented as soon as it is ready, ~20 ms at 72 Hz,
so it does not always count as late; the average catches it). The game's **sustainable rate** is the highest of 72 / 90 / 120
that passes; record it in `6-wip-games.md`.

Why not uncapped 1% lows: games that wait for whole numbers of vblanks (WipEout) show their pacing steps instead
(uncapped at Vblank 240: average 100.0, 1% low 45; at 72: 0% late). Capped 1% lows also mislead: the limiter's
jitter shows ~64 while every frame is on time, hence the late-frame count.

- Fork hook `RPCS3_VR_FRAMESTATS=<seconds>` logs per window: frames, average, 1% low, 0.1% low, worst frame,
  median frame time, late %.
- `tools/re/vr1pct.sh ID STATE VBLANK [WALK]` (env `SCALE` default 300, `SETTLE` default 10 s): one run from a
  savestate in desktop stereo with a temporary pad; merges only Vblank and Resolution Scale into the game's config;
  walks ~25 s; prints the windows after the settle and their median.
- `tools/re/vr_regress.sh [filter]`: every state in `tools/re/vrtest_states.txt`, climbing 72 -> 90 -> 120 and
  stopping at the first failing rate; writes `evidence/vrtest/<date-time>/results.txt` (+ screenshots).
- Results move by ~10% between runs; re-run borderline games. Desktop stereo approximates the headset path.
- **Regression set:** one named savestate per game (`bin/savestates/<ID>/vrtest_<game>_<scene>.SAVESTAT.zst`).
  Run `vr_regress.sh` after renderer changes and compare with the previous run. Add a state for every new game.
  How to recreate the set on another PC: `7-vr-regression.md`.

### Finding and measuring RSX-thread cost (2026-10-01)

In stereo the RSX thread is usually the bottleneck (it draws every draw twice): Ratchet & Clank used 13 ms of a
15 ms frame. Measure with exact numbers, change one thing, and compare on the same savestates at the same rate.

- `RPCS3_VR_FRAMESTATS` also logs **the RSX thread's CPU ms per frame** (`QueryThreadCycleTime`; `GetThreadTimes`
  undercounts RPCS3's threads by more than half). At a fixed rate, lower is better, independent of the FPS cap.
- `tools/re/vr_ab.sh LABEL [STATE...]`: one 72 Hz run per state (default R&C 1, R&C 3, Dragon's Dogma), summary
  lines appended to `evidence/vrperf/LABEL.txt`. Env `PROBE=render=0` measures flat; `VIDEO_EXTRA="Key=value;..."`
  overrides Video settings for the run (restored after).
- `RPCS3_RSX_SAMPLE=1|2|3` (fork, in-process): samples the RSX thread's host stack every ms and logs every
  `RPCS3_STATS_PERIOD_MS` the top functions, self and inclusive; `=2` adds the top stacks, `=3` adds **source lines
  resolved through inlined code** (DbgHelp inline trace), which is what finds a hot line inside an inlined helper.
  `tools/rsx_sample.py` (external, same idea without inline lines) and `tools/threadcycles.py` (per-thread CPU)
  also work.
- Function-level self time can mislead: Ratchet & Clank's 5% "in bind_camera_block" was the first read of a
  scratch buffer filled with non-temporal (streaming) stores; only the inline line view showed it.

## Headset checks with the OpenXR Simulator (2026-10-01)

The desktop fake headset (`RPCS3_VR_FAKE_HMD`) has a fixed pose, no OpenXR session and skips the real-headset-only
code, so it is not a headset test. The OpenXR Simulator is a real OpenXR runtime: RPCS3 runs its full headset path.

- Source and build: `F:\rpsc3\source\OpenXR-Simulator` (github.com/elliotttate/OpenXR-Simulator, 8de3457). Local
  change: a **Pimax Dream Air** profile (`dreamair`, hmdgdb "Pimax Dream Air LH": per-eye FOV -55.08/45.54 deg
  horizontal, +-44.55 vertical, panel 3840x3552) in `src/ui_enhancements.h`. Build with VS 2026 Insiders (its CMake
  and Ninja after `Enter-VsDevShell`; **not** `build_simulator.ps1`, which uses `vswhere -latest`):
  `cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF; cmake --build build` -> `bin\`.
- Settings: `%LOCALAPPDATA%\OpenXR-Simulator\settings.json` (`headset_profile: dreamair`, native render size, IPD 64).
  It paces at 90 Hz (fixed). It has no `XR_FB_display_refresh_rate`, so the fork keeps the configured Vblank Rate:
  set the game's Vblank to the headset rate (90) for the test.
- Boot: `tools/re/simboot.ps1 -Iso <disc or savestate> -Probe render=1` sets `XR_RUNTIME_JSON` for that launch only
  (the system's runtime, Matt's headset, is untouched). `-Probe render=1` is required: the dev launcher's probe file
  otherwise disarms stereo and no session starts (a normal launch arms it by default). The log shows
  "Headset 'OpenXR Simulator' found" and "First stereo frame submitted".
- Head: the simulator starts at y = 1.7 m in every space (a real LOCAL space starts at the head), so the screen sits
  low: write `{"x":0,"y":0,"z":0,"yaw":0,"pitch":0}` to `%LOCALAPPDATA%\OpenXR-Simulator\head_pose_command.json`.
  **`yaw`, `pitch` and `roll` there are radians** (25 degrees = 0.436). Before 2026-10-01 late the scripts wrote 25, which is
  25 rad = -7.6 degrees; 10 faces backwards (-147). The trace line `L<pose>(<yaw>)` in the log shows the yaw RPCS3 rendered.
  `pose_sweep_command.json` (`{"enabled":true,"yaw_amp_deg":30,"pitch_amp_deg":15,"freq_hz":0.25}`) moves the head
  continuously: needed to see head-locked screens or anything that changes with head movement.
- Capture: `tools/re/simshot.py OUT` (the composited eyes, as the headset shows them); `shot.py` gives RPCS3's own
  image for comparison. `runtime_status.json` has frame time and the head pose.
- Local patches (branch `rpcs3-vr`, not pushed): the Dream Air profile, and `xrEndSession` moves the session to IDLE
  only (it re-sent STOPPING, so RPCS3 looped STOPPING/IDLE after a collection's executable switch, 9 million log
  lines). Rebuild after pulling: `cmake --build build` in the VS dev shell.
- `tools/re/simscreen.sh ID ISO OUT [WAIT] [SHOTS]`: boot on the simulator at Vblank 90 and capture the headset view
  straight and turned 25 degrees: a world-fixed screen moves between the two, a head-locked one does not.
- Still not the headset: no reprojection or timewarp, a D3D12 compositor, no lens distortion. Matt's runs stay final.

### Measuring world scale (`eye_baseline`) from the headset path (2026-10-02)

The generator's near-plane rule (near plane = 0.1 m) is a guess: God of War 1 came out at 50 units/m and measured
13.5 (the world looked ~3.7x too small). Measure on a character of known size:
1. Run on the OpenXR Simulator, dump both eyes' display buffer (`RTDUMP` with its address; `tools/re/rtdump2png.py`),
   join them side by side.
2. Set `eye_baseline` to 0.0001 live and measure any region with `tools/re/parallax.py`: that R-L is the frusta's
   offset (infinity). Restore the value and measure the character: its disparity d = infinity - R-L.
3. Distance in game units D = fx * eye_baseline / d, with fx = pixels per tangent unit across the eye image
   (from the infinity offset: fx = offset / (tan(right half) - tan(left half)) of the headset's per-eye FOV).
4. Height in units H = h_px / fy * D (fy from the vertical FOV); units per metre = H / real height. Set
   `eye_baseline` = 0.064 x units per metre and check the disparity scales by the same factor.
Jak 1 (0.5 m per unit) used the same relation: parallax = k x eye_baseline / depth.

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
| Shadows or lighting slide across characters as the head turns (dark sections that come and go) | a deferred pass rebuilds positions from the depth buffer with fragment constants made for the game's camera: `depth_remap_programs` (the generator's log names candidates: camera draws reading the depth buffer as colour) | Asura's Wrath |
| A black border around the view; the world a few percent smaller than the head's rotation | the game insets its scene in the display (God of War: 1216x684 in 1280x720) | `display_rect` with the inset, measured on a display dump |
| A menu flickers between the fixed screen and the headset view, shown twice offset | its draws count as camera draws on the fixed screen but as HUD in the headset view, so the frame alternates; the probe's `why=` shows `camera 1` with state 6/2 and `box 1` with state 7 | fixed in the renderer for `offaspect_projection` (God of War); for another rule, the same: classify the HUD the same way with the view off |
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
| 3D menu cards or panels stacked in the HUD box cut through each other in slices when the head turns (the topmost does not change with the selection) | `screen_space.hud_exact_depth_programs: ["<vertex program>"]` (the stack's program from an inspector capture: depth-tested quads into the display buffer sharing one perspective block) | Gran Turismo 5 arcade menu |
| HUD (or menu text) sheared/rotated with the world although the scene is fine; the scene camera is a bare projection too, and the HUD draws use the same slots with another aspect (4:3 in a 16:9 game) | `screen_space.offaspect_projection` (generated since 2026-09-30) | God of War HD |
| A collection's second executable gets no headset session (desktop-only stereo; no `OpenXR:` lines after the switch) | the renderer for an exitspawned executable is built before the title ID is known: give the collection a base `<TITLE_ID>.json` (the launcher then prepares OpenXR, which survives the switch) | God of War Collection |
| 3D view letterboxed (bars top and bottom); the generator finds no camera (projection B/A far from 16:9) | a game-side letterbox: patch its height/width factor to 16:9 (search the executable for the factor next to the viewport setup, e.g. 0.475 = 608/1280) | Dragon's Dogma |
| Skinned characters wrecked, or a stray wedge, in one eye; a listed block is also a bone slot in skinned programs | `camera_slots_read_directly: true` (generated since 2026-09-30) | Dragon's Dogma |
| Right eye black or missing large parts of the scene only in stereo (flat-route `stereo=` probe fine) | was a renderer bug: a stencil-only clear copied the left eye's depth into the right eye (fixed 2026-09-30). To diagnose similar ones: `RPCS3_VR_RTDUMP` with `prog=<vertex hash>` dumps both eyes' surfaces (depth too) just before that program draws | Dragon's Dogma |
| Sprites (flames, glows) drift away from their source | `screen_space.preprojected_programs` | ICO |
| Reflections or light pools on the ground follow the head | `offaspect_player_views: true` when the reflections are drawn with the player's camera into an off-aspect target and sampled at screen position. Find the drawing program with probe `hide=<vertex hash>[@<target>]` and `RPCS3_VR_RTDUMP` diffs | Ridge Racer 7 |
| Generator picks a tiny camera (projection A in the tens) or "every camera draw is a bare projection" while the scene is not covered; near plane absurdly small | fixed in the generator (2026-10-01): a 2D HUD ortho read as x/y/w rows passed as a 2-degree camera, and a few object-scaled MVPs set the near plane. Check the scene's render-target size in an inspector capture: a scene at another aspect (1024x720) needs `camera_target_aspect` | Anarchy Reigns |
| One HUD element stays at its flat-screen position outside the HUD box (headset view) | it samples a render target the HUD drew (a mask): with `hud_skips_passes` it counted as a pass (fixed: only view-shaped targets make passes). If it then shows wrong colours inside the box, its UVs come from the clip position: `hud_box_after_shader`. Find it with probe `hide=<hash>@<target>`, an inspector capture (draws into small targets between HUD draws) and `RPCS3_VR_RTDUMP` of the HUD target | Anarchy Reigns |
| HUD missing in stereo (both eyes, also without a headset) | the HUD program keeps other data in a camera block's slots (Dante's Inferno: UV and colour in `c[4..7]`) and the eye transform wrecks it: `require_rigid_camera: true` (the generator now writes it for strongly sheared depth-less matches). Find the HUD program with an inspector capture (draws with a pixel-scale ortho) | Dante's Inferno |
| Game runs fast above 60 although its clock reads real time | it counts whole frames of a fixed interval, at least one per frame: find the interval (float ms or s) the frame function divides by and drive it from the profile (`game_frame_ms_f32` / `game_frame_time_f32`) | Dante's Inferno |
| HUD stays full-size at the screen edges in the headset view while the scene follows the head | the HUD reads no ortho block the profile names (an object transform plus a packed scale/offset slot) and draws into the scene's target: `passthrough_hud` + `hud_programs` [its vertex hashes] (after-shader box). Probe `why=<hash>` shows what the renderer decided for that program | Dragon's Dogma |
| Stereo well below the flat rate; the RSX thread's CPU ms per frame (`RPCS3_VR_FRAMESTATS`) near the frame time | the per-draw VR cost on the RSX thread. Profile with `RPCS3_RSX_SAMPLE=3` and A/B with `tools/re/vr_ab.sh`. Fixed in the renderer (2026-10-01): the eye constants' CPU scratch was filled with streaming stores and read straight back (~13% of the RSX thread), camera slots were looked up through a thrashing cache (binary search now), and the right eye's attachment list was reallocated per draw | Ratchet & Clank 1-3 |
| Stereo far below flat while the RSX thread spends its time in `ZCULL_control::sync` / `get_occlusion_query_result` | the game reads occlusion-query (ZCULL) results synchronously; in stereo each wait covers both eyes' GPU work. Profile key `zcull_approximate: true` (ZCULL Accuracy "Approximate" while VR renders: any visible pixel reports as fully visible). Check flares and glows that could depend on the visible pixel count | Dragon's Dogma |
| Splash screens, videos or 2D menus follow the head in the headset | fixed generically (2026-10-01): frames with no camera draws and no 3D in the displayed buffer go on the fixed screen. If a pause/menu screen is drawn over a copy of the 3D frame it still counts as 3D: `frames_without_3d_as_screen: true` when gameplay always has camera draws | Dante's Inferno |
| A menu made of a 3D model in front of 2D layers comes apart in the headset (2D boxed in front of the 3D) | `screen_frame_draws` with a draw only that menu makes (its logo): the frame goes whole on the fixed screen | God of War 1 |
| A darker rectangle with a ghost copy of the scene over part of the view (headset view only) | a full-screen copy boxed as HUD because its source is not recognised as a render target (a 2x-wide MSAA buffer, a main-memory buffer). Probe `why=<hash>` shows `box 1`; `unboxed_draws` with that program and the source's texture-0 size | Tales of Xillia |
| Light halo along every silhouette at high resolution scales | a resolve or filter pass with tap offsets as texture-coordinate fractions in vertex constants: `resolution_scaled_constants` (read the pass's vertex program for the slots) | God of War 1, Ridge Racer 7 |
| A light glow or flare stays fixed in the view while the head turns | screen-space glow sprites placed at the light's flat-screen position; if they sample the scene (occlusion) they count as passes and stay as drawn. Find with probe `hide=<hash>` (head turned on the simulator), then `hidden_draws` per texture size | Puppeteer, Jak 1 |
| Game runs fast at the headset rate although it looks real-time on a walking test | memory dumps at 60 and 90 (`tools/re/memcount.py`, look for 1/60 vs 1/90 and 60.0 vs 90.0): if nothing changes the game steps a fixed 1/60; `max_fps 60` / `default_fps 60` (reprojected) until the step is found | Jak 1 |
| Objects at different stereo depths than they should be (headset only; desktop fine) | per-object matrices in the camera slots: the `baseline` eye offset is scaled by each object's scale. `eye_offset: baseline_per_w` (the generator writes it), then `eye_baseline` in view units: find a character's model draw in a capture (its `c[3].w` is its depth in view units), compare its on-screen height. Verify with `tools/re/parallax.py` on a simulator SHOT (depth-ordered offsets; px = 68 x eye_baseline / depth at Dream Air with the 10-degree margin) | Jak 1 |
| Stereo below 90 with the GPU mostly idle and no thread saturated | `RPCS3_VR_GPUPROF=1` prints GPU ms per target and the RSX thread's busy time between flips. If the RSX busy time plus the game's own frame work exceeds the frame, the game waits for the RSX every frame (serialised): cut RSX per-draw cost or find the game's wait | Ratchet & Clank |
| Image blown out, wrong colours or black in stereo, though the lit scene is right | the post chain (luminance reduction, colour-grading LUT build) drawn with bare-projection quads gets the eye transform or the HUD box. Find the pass with RTDUMP `prog=<hash>#n` dumps flat vs stereo; the fork leaves passes sampling render targets as drawn; draws with ordinary textures that are not HUD: `unboxed_draws` | The Darkness |
| Both eyes show exactly the same image (audit shows no yaw, 0 px parallax) though camera draws are classified | the frame is bounced through main memory for SPU post-processing (MLAA/EDGE post) and the composite samples the SPU's output: `texture_redirects` from that main-memory texture to the scene render target | Puppeteer |
| Dark or bright shapes (pentagons, rings) appear in one rotated eye only | a lens flare: quads the game projected itself, killed by a scene-depth test at their flat-screen position. Find the program with `hide=`; hide it in VR with `hidden_draws` | Jak and Daxter |
| Light glows, streaks or particles float in the HUD box, sliding toward the view centre | view-space particles with a bare projection: `bare_projection: false` (the generator now only sets it without depth test) | Ridge Racer 7 |
| Scene edges soft at every resolution scale while the HUD is sharp | a post pass with filter-tap offsets in vertex constants: find the full-screen pass that samples the scene (inspector + `Log shader programs`), then `resolution_scaled_constants` with its program and offset slots | Ridge Racer 7 |
| Floor, view edges or top of the view blurred or doubled; the centre sharp (not the HUD: hiding the HUD programs leaves it) | the game's depth of field, often with a blur that grows from the screen centre. Find its passes with probe `hide=<vertex hash>` (hiding the blur passes makes it sharp), read the composite's fragment shader for the blend-strength constant, then `fragment_constant_overrides` with the composite's program and that constant set to 0 | Demon's Souls |
| Frame rate drops only in busy scenes while GPU use stays low | find the bottleneck thread with `tools/threadcycles.py`, then `tools/rsx_sample.py rsx::thread 10`; `RPCS3_VR_GPUPROF=1` gives per-frame RSX/GPU breakdowns and right-eye rebuilt copies. Games in lockstep with the RSX thread are bounded by its per-draw work, which stereo roughly adds to | Ridge Racer 7 (right-eye cube-map rebuilds, fixed in the renderer) |
| Wheels, glows or other scaled objects stay head-locked while the scene turns | `require_rigid_camera: false` (their object matrices fail the rigidity test); check nothing off-scene gains the rotation. The generator no longer sets rigidity from depth-tested scene draws (2026-09-26) | Ridge Racer 7 |
| A huge stretched wedge in one eye (menus, cutscenes); or scene and sprites need different matrix layouts | a full-screen pass reads the camera slots in the other layout (an orthographic matrix that looks perspective when transposed): `require_rigid_camera`; sprites in the other layout: `row_vector_blocks`; a HUD in the other layout: `orthographic_block_layout` (read the HUD program's shader first: Bayonetta's HUD did not need it) | Bayonetta |
| Characters (or anything moving) smeared or haloed in the headset only, sharp on the desktop | motion blur whose velocity pass keeps the previous frame's view-projection beside the camera; only the camera gets the head transform. Find a program reading two near-identical perspective blocks (`bf6c93fc`: `c[8]` and `c[36]`), then `linked_camera_blocks`. Reproduce with `RPCS3_VR_AUDIT_FOV=1.0` and `-Audit 15` | Bayonetta |
| A glow or flames around a character drawn larger than the model and off to one side; distant cards (trees, plants) floating in front of the sky | camera-facing sprites in a camera block took their own size as the projection scale (rotation, FOV remap, eye offset); fixed in the renderer for blocks listed in `nonrigid_camera_blocks`. To find them: probe `hide=<hash>@<target>` (keys are comma-separated: `render=1,hide=...`), then check the program's block is listed | Bayonetta |
| Splash screens and videos fill the view | `screen_space.frames_without_3d_as_screen: true` | ICO |
| "Cutscenes locked to 30 FPS" | check whether they are videos: no draws and no game flips while they play (RPCS3 only re-shows the buffer by its UI refresh). Nothing to unlock; `frames_without_3d_as_screen` puts them on the fixed screen (UI refreshes during a flip gap count as frames without 3D since fork 77382a4b) | Demon's Souls |
| Glow or blend layers trail head turns; a ghost of bright-edged objects on fast head turns at full frame rate | `reproject_older_frames: true` (the game blends the previous frame), plus `current_frame_copies: true` if it composites an older scene copy. Reproduce with `RPCS3_VR_WOBBLE=30` | ICO, SotC, Killzone HD |
| Objects missing at the edges of the headset view even looking straight ahead | the game culls to its own camera frustum, narrower than the headset's | find the projection in live memory (`tools/re/findpair.py <x scale> <y scale>`), the record it is built from (`findvals.py` for the FOV angle), the writer (`RPCS3_PPU_WATCH_FILE` with the PPU interpreter), test a wider FOV live (`RPCS3_VR_POKE` on the code under the interpreter), then a patch; measure the frame rate after (Dante's Inferno: FOV x2 at the camera update, `fadds`) |
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
