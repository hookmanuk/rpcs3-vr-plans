# Gran Turismo 5 (BCUS98114 v02.11, XL Edition, US) - findings

Profile `bin/vr_profiles/BCUS98114.json` is the in-emulator generator's output (2026-09-29) plus
`max_fps 0`, `default_fps 0` and `game_frame_time_f32`. Patch `bin/patches/BCUS98114_patch.yml`
("Frame rate follows VR", on by default). Fork commit e1648a6dd. **Not yet checked in the headset.**
Evidence: `plans/evidence/gt5/`.

## Frame rate (90 FPS at real-time speed)

- The "Unlock FPS" patch only changes the flip interval; at Vblank Rate 90 the game ran 1.5x (physics, sim and
  race timer). The game is a fixed-step loop: `0x1864a0` runs `while (accum >= 1.0)` steps of size `dt`, and
  every system (car physics, timer, AI) steps by that same `dt`.
- `dt` comes from one getter, `0x182a30` (`lis r9,0x140; lfs f1,0x17f8(r9)`), reading the constant
  `0x14017f8` = 0.0166833 (1/59.94) in read-only data. PINE cannot write it and a patch cannot write
  read-only memory.
- Fix: the patch redirects the getter (`lis r9,0x195; lfs f1,-0x7bc0(r9)`) to a word at **`0x1948440`**, inside
  the bss zero run, and initialises it to 0x3c88ab7c (1/59.94). The profile's `game_frame_time_f32` rewrites it
  every frame with 1/fps (0.016683 -> 0.011111 s at 90 FPS, logged by VRPROBE). The variable must live in
  the data/bss segment (0x16b0000-0x19485b0): the heap is not mapped when patches apply, and a patch write
  to an unmapped address silently fails, then the game dies with "Access violation reading location".
- Measured with the race timer (`evidence/gt5/timer-60hz.png`, `timer-90hz.png`): 60 Hz 2.98 s of game time per
  2.98 s wall (1.00x); 90 Hz 2.95 s per 2.98 s (0.99x). Everything in the fixed-step loop follows `dt`, so
  physics scales with it. Not checked: UI animation and audio not driven by `dt` (no obvious problems seen in
  the race screens).
- The profile is loaded with VR off too, so the patch works in flat mode as well as VR.

## Rendering

- Camera `c[0]` (`column_vectors`), position `c[467]`, output 1280x720 (game renders 1280x720; Resolution
  Scale 300 in the config). Game projection A = 1.40625, B = 2.5. Units are metres (`eye_baseline` 0.064).
  GT5 has its own side-by-side 3D path (2560x720 texture); the profile uses generic `clip_x_shear` values.
- HUD: drawn last into a **2048x1080** target (aspect 1.896, not the 1.778 output) with a pixel-space
  orthographic matrix in `c[0]` (`[2/1920,0,0,-1]`, `[0,-2/1080,0,1]`). The final target also holds the scene
  composite (program `fc7082da`, identity matrix, samples the 2560x720 scene texture). The generator finds no
  HUD block ("HUD none").
- The rear-view mirror is drawn straight into the 1280x720 scene target through a viewport of 448x86 at
  (416,42): draws 228-304 in the capture, camera `c[0]`, so it is a "camera draw".

## Desktop checks (2026-09-29, `-NoHeadset`, `render=1`, High Speed Ring, Zonda R)

- Stereo SBS (`stereo-sbs.png`): HUD position identical in both eyes, world parallax, graphics match the flat
  image.
- Rotation audit yaw 25 and pitch 35 (`audit-yaw25.png`, `audit-pitch35-mirror-rotates.png`): sky, fence,
  kerbs and racing-line arrows turn together; HUD, gauges and mirror frame stay fixed; no bands or floating
  objects.

## Headset HUD, menus and mirror (2026-09-29, fork 2c10ea9e6)

Profile `screen_space`: `orthographic_block 0`, `hud_skips_passes`, `hud_display_buffers_only`,
`hud_box_after_shader`, `output_pixel_draws_not_hud`, `subviewport_cameras_in_box`, `hud_keep_depth`, with
`output_aspect_tolerance 0.08` (the 2048x1080 display buffers are 6.7% off 16:9). How GT5 draws its 2D:

- HUD and menus go into the display buffers `0xc0000000` / `0xc0880000` (2048x1080) through a 1280x720
  viewport; only that corner is shown. The box is measured against the shown region (else 1.6x too large,
  off to the lower right) and its scissor is clamped to it.
- Both buffers share the depth surface `0xc1100000`. Glyphs live in its unshown part; text draws (vertex
  program `7e7a0eeb`) read it back by texel. Untextured fills in 1280x720 pixel units (`c[0].x = 2/1280`,
  program `fc707dda`) write glyph coverage and clear the screen: boxed, they broke all menu text and left
  trails when the head moved. `output_pixel_draws_not_hud` keeps them as drawn; HUD elements use 1920x1080
  units (`2/1920`, scaled gauges `2/2133`) and stay boxed.
- The track map is masked through that depth surface by depth-only draws (no colour target, address 0):
  they count as display-buffer draws so the mask moves with the boxed map.
- The text shader derives clip masks from the projected position (`tc2 = (NDC - c[133]) * c[134]`), hence
  `hud_box_after_shader`. A centre overlay (`1efd674e`) masks with the 2048-wide scratch `0xc2880000` at
  screen positions: full-width colour targets count as pass inputs (left as drawn), narrower ones (name
  strips 256x48, menu card 800x452) are HUD art.
- A font atlas in a 2048x1080 target is not a display buffer: boxing only display-buffer draws keeps it intact.
- Menu cards are perspective draws straight into a display buffer: boxed (after the shader) with the menu.
- Rear-view mirror: camera draws through the 448x86 viewport at (416,42) of the scene target go into the box
  with the game's mirror camera; its scissored clear moves with it (else a black hole at the old place).

Tested with the headset on its stand and `RPCS3_VR_WOBBLE=20` (renders a +-10 degree yaw sweep): race HUD
complete (position, lap, timers, rank names, gauges, track map, mirror), arcade menu text correct, no trails.
Matt confirmed the in-race box is placed right (his SteamVR view needed recentring).

Known: in some runs the arcade menu showed upside down for the whole run (2 of 7 runs before the last
fixes, 0 of 4 after; not reproduced under capture). Suspected: GT5's display-buffer copy pass (menu frames
that do not redraw) going through the camera path. Watch for it.

## Performance (2026-09-29)

- Right eye: 172 texture rebuilds a frame were shadow-map atlas gathers (`atlas_gather` from the 1024-wide
  cascades, one per lit draw) and 146 copies of a 3x3 dummy texture at address 0. Both now share the left
  eye's copy: 0 rebuilds, 106 instead of 278 right-eye batches, 11.3-11.8 ms/frame on the grid after the
  pack has gone (was 16-17).
- With the pack in view (first 20 s of a race) VR runs 35-90 FPS. The RSX thread is busy 6-8 of 20-29 ms:
  the guest is the limit. Flat also drops to 55-80 FPS there. VR adds guest stalls in two GPU readbacks a
  frame at `0xc58080a0` (2-3 ms, flat 0.25 ms): the guest waits for the GPU, which has both eyes queued.
- Tried: Minimum Scalable Dimension 512 (off-screen targets native): no measurable change. Relaxed ZCULL
  Sync: the game hangs early in the race. Accurate ZCULL stats off: no change. **Disable ZCull Occlusion
  Queries: on** (RPCS3 wiki recommendation, now in Matt's config): first 20 s average about 65 FPS instead
  of 56, no visual change seen.
- GPU per frame on the grid: scene 2.8 ms (both eyes), present 2.3, display buffers 1.6, shadow cascades
  1.1, reflection targets 1.1, cube faces 0.9.

## Follow-up (2026-09-29 evening, fork 820db6c39)

- **Car shadows green/magenta:** GT5 renders its shadow cascades (1024x682/1365/2048) into the memory of the
  display buffer it is not showing (`0xc0000000`). The display-buffer test compared addresses only, so the
  light-camera shadow draws were boxed (perspective draws into a display buffer). A display buffer now also
  has to match the display buffer's size (2048x1080).
- **Duplicate icon row / "small screens" in menus:** icon backgrounds sample a 54x42 patch of a 2048-wide
  blur buffer (`0xc3780000`); counting any full-width colour target as a pass left them unboxed at their flat
  position. A pass is now a draw sampling a screen-sized *texture* (the sampled width, not the surface's).
- **Trails in 2D menus:** the arcade screen never clears its display buffer (it starts with a full-screen
  gradient, boxed). Before the first boxed draw into a display buffer that no pass or full clear covered this
  frame, the shown region is cleared in both eyes.
- **Mirror edge strips:** the mirror's clear also writes depth; each eye now clears its own box rectangle.
- **Pre-race flyby:** below the game's view the headset shows the sky dome's lower half (ground culled by the
  game's own frustum). Content limit, not fixed.

## Performance with cars in view (2026-09-29 evening)

Sampling profiler (`plans/tools/sampler.py`: suspends threads, walks stacks with dbghelp and `rpcs3.pdb`,
no admin needed) on the RSX thread during the first seconds of a race:

- The RSX thread is CPU-bound (88-94% busy) in **flat too**: flat dips to ~42 FPS there, stereo to ~30.
  GPU (RTX 5090) is ~38% utilised; resolution scale 100 vs 300 changes the dip only a little.
- Stereo adds ~40% RSX time: the right-eye replay repeats program/descriptor binds, secondary batch
  begin/execute and draw calls through the driver (~60% of RSX time is driver code), plus the per-draw
  matrix work (`bind_vr_eye_constants`, `matrix_block::bind`, ~8%).
- Base costs also present in flat: CPU texture uploads (~12-14%), pipeline lookup, blits.
- GPU readbacks each frame: the RSX thread reads a 128x322 target at `0xc57f8000` as data (address
  `0xc58080a0`), PPU threads read rotating 16x8 targets at `0x4fec2680..0x4fec3740`. Each read waited for all
  queued GPU work (both eyes). Stereo now copies sections read before as soon as their surface is left and
  submits: stalls 2.5 -> 0.6 ms/frame, ~1 ms off the worst frames.
- No gain: Multithreaded RSX, Asynchronous Texture Streaming, Minimum Scalable Dimension 512, Accurate
  ZCULL stats off. Relaxed ZCULL Sync hangs the race. Disable ZCull Occlusion Queries: small gain (kept).
- Next candidate: multiview (both eyes in one draw), which removes most of the stereo extra; it cannot lift
  the dip above flat's ~42-55 FPS. Matt chose bug fixes first.

## Late evening (2026-09-29, fork dcb87dde3): still broken

Matt's report after the 820db6c39 build: car shadows still red in the right eye, arcade menu clipped when the
head moves back, desktop mirror shows each eye small, race start still slow.

- **Red car shadows (right eye), NOT FIXED.** Flat and the left eye show a dark shadow; the right eye shows
  bright red under nearby cars. The car bodies of nearby cars also show black blocks in both eyes (not
  investigated). Findings:
  - Not the shared-copy optimisation: `RPCS3_VR_NO_SHARE` (all right-eye copies rebuilt) kept the red and
    made the game very slow.
  - Not a view mismatch: the right eye's swapped views have the same format, swizzle, aspect and type as the
    left eye's.
  - The cause is the right eye reading its own scene target `0xc1980000` (1280x720, **2x MSAA**, diagonal;
    sampled as 2560x720 through `sampler2DMS`, tiu 10). The shadow/lighting draws read the pixel under them
    from the target they draw into (feedback loop, `TEX2D(10, wpos * c18.zw)`, then add their term). With
    the right eye not swapping `0xc1980000` (reading the left eye's target) the red is gone; not swapping
    the depth `0xc2100000` does not help.
  - Moving these feedback draws out of the right-eye batch (per-draw replay, barrier after the earlier
    right-eye writes) is committed as a sync fix but does **not** remove the red.
  - Mid-frame dumps of both eyes' resolved `0xc1980000` at a feedback read match each other, but none caught
    a car alongside. Next: Matt is saving a savestate paused with the red shadow in view; dump there, before
    and after the shadow draws, and compare left/right pixels under the car.
- **Arcade menu clipped when the head moves back, NOT FIXED.** The 3D card stack loses parts when the HMD
  moves away from the screen. Hypothesis (untested): boxed card draws depth-test against unboxed
  text-coverage depth. `RPCS3_VR_HEAD_OFFSET=0,0,0.3` (committed) reproduces head movement without the
  headset.
- **Desktop mirror shows each eye small, NOT FIXED.** The mirror calibrates the whole 2048x1080 display
  surface, of which the game shows 1280x720 (62.5% x 67%). The headset gets the right region. Fix: crop to the
  shown size before the calibration pass in `VKPresent.cpp`.
- **Race start frame rate, NOT FIXED** (see above; multiview is the candidate).

Test route: Matt's savestate `bin/savestates/BCUS98114/BCUS98114_1_0.SAVESTAT.zst` (car selection), then
X, X, X; the race starts ~17-20 s later with the pack in view. Run at Resolution Scale 100 and restore 300.

## 2026-10-01 (fork 5774402d6, 7feab63fd): car shadows and desktop mirror fixed

- **Red/green car shadows: FIXED.** Bisected with probe `hide=` over the scene programs from the race-start
  savestate (`tools/re/gt_quick.sh`, `gtcrop.py`): the shadow blobs are program `1b18b27233f6c174`. It keeps
  per-channel fog densities in `c[467]` (w 0.991), the slot the other programs use for the camera position, and
  the profile's camera-position offset moved them by the eye: red in the right eye, green/blue in the left. The
  renderer now offsets the slot only when it holds a point (w = 1) near the eye solved from the draw's own camera
  block. Both eyes now show dark shadows (`evidence/gt5/car-shadows-before-after.png`). The earlier MSAA-feedback
  theory was wrong: a single sheared view never showed it, and disabling MSAA or right-eye batching changed nothing.
- **Confetti texture on car bodies:** also in flat at the same moment, so not a VR issue (the "black blocks" of
  the old report were not seen).
- **Desktop mirror: FIXED.** The shown 1280x720 region of each eye is copied to a scratch image before the
  calibration pass (`evidence/gt5/desktop-mirror-cropped.png`). Checked on the desktop stereo window only.
- The RTDUMP hook now resolves MSAA surfaces (it crashed the RSX thread on `0xc1980000`).

## Open

1. Arcade menu clipping when the head moves back (above). Not worked on: needs the headset path (SteamVR), whose
   head position the desktop audit cannot fake. Matt stopped the session here.
2. Race-start frame rate (multiview).
3. Car shadows and the mirror crop in the headset (fixed on the desktop only).
4. Intermittent upside-down menu (not seen since the display-buffer size fix, unverified).
5. Cockpit and replay cameras and the garage not audited.
6. Optional 8 GB data install: the game asks at every boot; declined in tests (decline with Left, then X).

## Driving the game unattended

Temporary keyboard pad from `tools/keyboard-pad-template.yml`. Decline the install with Left then X; Return
skips the intro; Right then X = Arcade; X = Single Race, difficulty, High Speed Ring, Zonda R '09, colour, load;
one more X for the list page, another X starts the race (about 20 s to load). Hold W (R2) to accelerate.

## Race-load freeze (2026-09-30)

Matt: "freezes going into a race every time". Reproduced from the car-selection savestate: the RSX thread dies
while the race loads with `Unimplemented BEM class instruction` (`FPOpcodes.cpp`, the fragment-program register
annotation). The program at that draw is garbage (`Unexpected precision modifier`, `Invalid Src type 3`, `TXPBEM`).
It is **not** the VR code: it happens with `VR > Enabled: false` too, and with ZCull occlusion queries on or off.

It depends on **Resolution Scale**: 200% crashes every time (4 of 4 runs, same RSX address `0x0a6f638`);
100% and 300% load the race and drive normally (screenshots). Matt's config had moved from 300 to 200.
Probable cause (untested): at 2x the scaled 1280x720 surfaces are 2560 wide, the same width the 2x MSAA scene
target `0xc1980000` is sampled at, and the texture cache confuses the two, so a transfer the game uses to place
fragment ucode lands in a GPU surface instead of memory. Workaround: any scale but 200% (300% verified).

Fork change: the unimplemented FP opcodes (POW, BEM class, TIMESWTEX) now log an error instead of throwing.
That alone doesn't save the race at 200% (the garbage shaders then hang the GPU: device lost), but the garbage
programs had already been written to the shader cache, and a throw there would end the RSX thread at boot.

## 2026-10-01: fake headset on the desktop

- `-FakeHmd 100` now renders the headset path without SteamVR. At car selection (`BCUS98114_1_0`) the desktop view
  shows the UI boxed but the showroom background black around a small car; RTDUMP of the display buffer
  `0xc0880000` at the flip has the full gradient background, the car and the boxed UI, so the frame itself is right
  and the black is in the fake headset's desktop presentation (not investigated further). With
  `RPCS3_VR_HEAD_OFFSET=0,0,0.3` the box just gets smaller; the arcade card-stack clipping was not on this screen.
- Not a 90 FPS game at race start (~42 flat), so the remaining GT5 items stay parked.

## 2026-10-01: headset (Matt, 90 Hz)

- Still about **40 FPS** in the headset; **at least 60 is needed** for the game to work. Build: 2026-10-01 RSX-thread
  optimisations (uncommitted). The regression's "90 Hz (race start)" (grid savestate, 40 s settle) does not reflect
  racing: re-measure in a race.

## 2026-10-01 night: measured on the current build

- Matt's GT5 config has the VR **Frame Rate: 30**; his ~40 FPS was presumably with a higher setting.
- `vrtest_gt5_race_start` at 60 (desktop stereo, 300%): 60.0 FPS, 0% late, RSX thread 7.0 ms/frame, idle 55%.
  OpenXR Simulator (headset path, VR Frame Rate 60 temporarily, Vblank 90): 60.0 FPS, 0% late, RSX 7.4 ms — but the
  car did not move (R2 is not accelerate in this setup) and after the 40 s settle the pack had left: not the slow
  case. The grid state is not representative of racing.
- Profile of the grid at 60: 11% of the RSX thread in `texture_cache` flushes (`imp_flush` -> `wait_for_event`, a
  GPU readback), the rest mostly idle.
- Next: a savestate from Matt where it drops (mid-pack), then `RPCS3_RSX_SAMPLE=2` and frame stats there.

## 2026-10-03: arcade menu cards improved, not fixed (exact per-pixel depth)

Matt: the arcade menu's images on the right sit on top of each other at the same depth and clip through each other;
left/right should change the topmost. Reproduced on the OpenXR Simulator with the head pitched down to the menu
(savestate `vrtest_gt5_arcade_menu` = `BCUS98114_1_4`: Arcade Mode, Single Race selected).

- **Cause.** The cards are six quads (vertex program `2f7d1792dfd94351`, one perspective block `c[0..3]` for all, depth
  test LESS with writes) drawn into the display buffer and boxed after the shader. The camera is ~2560 units away, so
  every card's depth is 1 - 0.149/w and adjacent cards are ~2e-7 apart. The fixed-in-front box tilts with the head; the
  rasterizer interpolates depth linearly across the tilted box, which is not the game's depth (error ~1e-6), so the
  cards cut through each other in slices and the selected card never came to the top.
- **Fix** (fork `7c8578ffa` on `multiview`, merged into the refactor branch): profile key
  `screen_space.hud_exact_depth_programs: ["2f7d1792dfd94351"]`. For listed vertex programs both shaders get
  `RSX_SHADER_CONTROL_VR_EXACT_DEPTH`: the vertex shader passes (window depth x game w, game w), the fragment shader
  writes their ratio to `gl_FragDepth`, which is the game's exact depth (equal to the normal depth outside the box).
  Simulator, head pitched -0.45 and turned 0.4: the selected card is whole and in front; Right/Left change it (Single
  Race, Time Trial, Drift Trial) as in flat (`evidence/gt5/2026-10-03-arcade-cards-*`).
- **Matt, headset, same day: better, but not fixed.** The selected card is in front, but when the HMD turns
  sideways or tilts up/down parts of the card art are still obscured: the front card (Time Trial) is cut off along a
  diagonal edge on its right, with a white sliver of the card behind showing
  (`evidence/gt5/2026-10-03-arcade-cards-matt-headset-still-cut.png`). Not investigated yet. Leads: another draw's
  depth (the menu background or the unboxed text-coverage fills that share depth surface `0xc1100000`) occluding the
  card where the tilted box moves it; or the card's corners crossing the near/far range once w changes.
- **Rear-view mirror, same symptom (Matt, headset, same day):** in a race the mirror image resizes and is culled
  depending on the HMD angle (`evidence/gt5/2026-10-03-mirror-matt-headset-cut.png`: its scene does not fill the mirror
  frame and is cut off at the right). The mirror is a camera draw through the 448x86 viewport at (416,42), put into the
  HUD box with the game's mirror camera (`subviewport_cameras_in_box`), so both are 3D draws in the tilted box: likely
  one cause. Its scissored clear moves with the box; the culling may be the scissor or the near/far range as w changes.
- Cost: hashing only for a profile that lists programs, once per vertex program (fingerprint cache); early-Z off for
  the listed program only. A race A/B (`matt_gt5_0100_1_3`, 60 Hz) did not complete: GT5 lost the Vulkan device in 3
  of 4 boots of that savestate, including one with the key removed (not this change). One clean run: 60.0 FPS, 1% low
  58.7, RSX 7.8 ms.

Savestates: Matt's 01.00 states are kept as `matt_gt5_0100_1_0` .. `_1_3` (hard links; RPCS3 had rotated `_1_0` out).
`_1_2` and `_1_3` are in races. Reaching the arcade menu from the disc: the title takes Cross only at some moments
(press, wait 8 s, check); a second Cross picks GT Mode, which starts selected. The top menu uses a pointer moved with
the left stick (L key), not the d-pad: hold L ~350 ms from GT Mode to Arcade Mode. GT Mode's exit is the red icon at
the bottom of its left strip (Down x7 from GT Life to Museum, then Left).

## 2026-10-05 night: frame rate everywhere (fork 2a68c4b6b, b0a6ad314, 135da69fc, e2c4d83bf)

All on the OpenXR Simulator, Matt's config (cfgtemp: VR on, Frame Rate Unlimited, Vblank 90, scale 400%, Null audio),
multiview. Tools: `tools/re/gt5_start.sh` (grid state, X, hold R2), `gt5_race.sh` (race-start state or `STATE=`),
`gt5_poke.sh` (write a word live), `cfgtemp.py` (temporary config edits, restored byte-identical).

Savestates (my arcade run, Superspeedway Indy, Fiat 500 '68, rolling start): `gt5_indy_prerace` (grid screen),
`gt5_indy_start` (race just started, pack ahead). Matt's `matt_gt5_0100_1_2` (Indy-like oval, 90 already) and
`_1_3` (tree-lined track, car against a barrier: the heaviest scene found).

| Scene | Before | After | What did it |
|---|---|---|---|
| Grid screen (pre-race views) | 17 | 90 locked | `reduced_scale_frames` 200% (17 -> 45, the cap), the patch "Pre-race at full frame rate" (45 -> 62-85, GPU at 100% there), then 150% (90 locked; 200% reaches only 85-86) |
| Race start, pack ahead (`gt5_indy_start`) | 60-65 | 83-89, then 90 | `skip_readback_sections` (stale 512x512, 60-65 -> 72-74), `late_readback_lengths` 512 (exposure ring) |
| Tree-lined track (`_1_3`) | 78 | 90 locked | `late_readback_sections` 0xc57f8000 (78 -> 84), `min_scalable_dimension` 512 (84 -> 90) |
| Grid -> race transition | - | 77-89 for ~8 s, then 90 (was 66-80) | the temporary image pool limit (fork a2fce3db3): the pool was trimmed and reallocated every frame at 400% stereo |
| Rome Circuit race start (`gt5_rome_start`) | - | 86-90 | same fixes; RSX-thread bound at 1,300-1,500 draws |

Findings:
- **The GPU is not the limit.** An RTX 5090 shows 4-17% utilisation (`nvidia-smi`) during the race start at 400%
  stereo. `RPCS3_VR_GPUPROF` segment times include GPU idle between submissions and must not be read as GPU load.
  Variable rate shading (2x2 for camera draws, `VK_KHR_fragment_shading_rate`) changed nothing and was reverted;
  MSAA off saved ~5%.
- **Readbacks were the stall.** The game reads small GPU results every frame: a 16x8 exposure value blitted into a ring
  of three 512-byte slots in main memory (address differs per session: 0x4fef39c0/3bc0/3dc0 or 0x4fef3340/...), and
  a 0x40000 section at 0xc57f8000 (track scenes with sun through trees). Each read waited for the RSX thread, which
  sat in `flip -> frame_context_cleanup` waiting for an older frame's fence and could not service the flush request
  (8.8 ms a frame blocked on `_1_3`). `late_readback_*` answers from the previous value and writes the result when
  the copy lands; the exposure values were checked to keep changing (PINE).
- **The pre-race views flip every second vblank** (30 FPS at 60 Hz). The interval is picked at `0x17e2f0..0x17e310`
  (`li r0,2` when the flag at `r24+0x1c` is set and `r21 == 0`, else 1; stored at `0x18ee6ac`). Patch `li r0,1`. The
  flyby is time-based: screenshots at 1/3/5/7 s match the unpatched run.
- **Cinematic Scenes** (new VR setting): Lower Resolution (default) / Fixed Screen / Full Quality. Fixed Screen shows
  the pre-race views on the floating screen at the reduced scale (69-81 FPS on the grid), no flyby camera around the
  player.
- The race start and the grid -> race transition are bound by the RSX thread: ~10.5 ms CPU a frame at 1,300 draws.
  Sampled: driver work inside `emit_geometry` (~16%), FIFO parsing, `close_and_submit_command_buffer` (2.7%, one per
  exposure blit to main memory), temporary subresource copies, `VirtualProtect` from `texture_read_semaphore_release`.
  Multithreaded RSX: no difference (83.6/87.5 vs 86.2/85.9).
- Not useful here: `max_scalable_dimension` (scale cap for big targets): GT5's shadow cascades (1024x2048, 2048x1080)
  live in the display buffers' memory, and an unscaled 2048x1080 there became the eye image. Reverted.
- The community "Unlock FPS" patch lists this executable's hash for 02.17, but its bytes do not match 01.00 code.

More (same night):
- **The grid is GPU-bound** once uncapped (5090 at 100%: the 2560x1440 supersampled scene at 200% is 5120x2880 per
  eye, twice). A live sweep of `reduced_scale_frames.scale` (the launcher reloads the profile): 200% 56-86, 150% /
  125% / 100% 90-91. The profile now uses 150.
- **Temporary image pool.** The RSX sampler (`RPCS3_RSX_SAMPLE=3`) on the Rome start showed ~5% of the RSX thread in
  `texture_cache::on_frame_end` destroying images (`FreeGpuVirtualAddress`): upstream halves the pool above 256 MB and
  one temporary copy of a 1280x720 target is 118 MB at 400% stereo. The limit now scales (4 GB on the 5090).
- Also tried, no gain: Multithreaded RSX, Asynchronous Texture Streaming (slightly worse), MSAA off (~5% GPU only).
- New savestates: `gt5_rome_prerace` (Rome Circuit grid, City tab), `gt5_rome_start` (race 5 s in, pack ahead);
  `vrtest_gt5_race_start` is now a hard link to `gt5_indy_start` (regression list).
- **Visual, not fixed:** on Rome (race and flyby) the top of the headset view shows a black arc: the sky dome ends
  inside the wider headset view (as noted for the pre-race flyby before). Needs the dome or the culling widened.
- **Intermittent device lost at boot** (2 of ~30 savestate boots tonight, 0 of 8 in a boot loop with
  `tools/re/gt5_bootloop.sh`): GPU write fault at address 0 during the first frames after a savestate loads
  (`wait_for_fence`). Known since 2026-10-03; not reproduced on demand.
