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
- Also tried, no gain: Multithreaded RSX, Asynchronous Texture Streaming (slightly worse), MSAA off (~5% GPU only),
  presenting the desktop window only every third headset frame (RSX thread unchanged; reverted). The fork's per-draw
  eye-constant work is ~0.65 ms of the RSX thread's ~10 ms at 1,400 draws.
- New savestates: `gt5_rome_prerace` (Rome Circuit grid, City tab), `gt5_rome_start` (race 5 s in, pack ahead);
  `vrtest_gt5_race_start` is now a hard link to `gt5_indy_start` (regression list).
- **Visual, not fixed:** on Rome (race and flyby) the top of the headset view shows a black arc: the sky dome ends
  inside the wider headset view (as noted for the pre-race flyby before). Needs the dome or the culling widened.
- **Intermittent device lost at boot** (2 of ~30 savestate boots tonight, 0 of 8 in a boot loop with
  `tools/re/gt5_bootloop.sh`): GPU write fault at address 0 during the first frames after a savestate loads
  (`wait_for_fence`). Known since 2026-10-03; not reproduced on demand.
- Regression subset after tonight's changes (`evidence/vrtest/2026-10-05-0356-gt5night`, simulator, 300%): WipEout,
  GoW 1, SotC, Demon's Souls, Pure, RR7, Killzone, ICO unchanged against the 2026-10-04 runs; GT5 race start (new
  state) sustains 120 (90 with 0% late frames).
- Config A/B on the Rome start (2 runs each): Allow Host GPU Labels on drops to 48-49 FPS (RSX thread 20 ms: keep it
  off); Accurate RSX reservation access off makes no difference (86-88 either way). Matt's settings stay.
- The black arc above the view (Rome): the game's camera covers ~46 degrees vertically, the headset 89; searches for
  the projection (A 1.3114, B 2.3314) and FOV values in live memory found only per-frame command-stream matrices
  (HUD orthographic) and curve tables. A Wider view patch needs the camera's culling found first; it would also add
  draws to the RSX-bound race start.

## 2026-10-05 early morning: rear-view mirror vs head yaw, reproduced on the simulator

- New dev hook `RPCS3_VR_YAW_FILE=<file>` (fork 2026-10-05): the rendered head yaw is the file's number (re-read every
  30 frames; the value is the quaternion half-angle, so 20 = 40 degrees). Rome race start, yaw 0 / -20 / +20:
  `evidence/gt5/2026-10-05-mirror-yaw-0-m20-p20.png`. At 0 the mirror sits between Position and Total Time at its
  size; turned, it is ~1.7x wider and ~4x taller and pushed outwards, while the HUD text stays put: Matt's
  "resizes and is culled with the HMD angle".
- Cause (logged box map and scissor): the mirror is boxed correctly as a quad (`map_vr_screen_box` already places a
  sub-viewport draw where its viewport puts it; `undo_viewport(..., inverse)`), but turned, that quad is a slanted
  perspective trapezoid (input x feeds output y by ~0.95, w 0.62-0.92 across the mirror), and its scissor is the
  axis-aligned bounding box (67 -> 304 host rows at 200%). The game relies on the scissor to clip its mirror camera,
  whose image extends past the 448x86 viewport, so inside the bigger box the extra camera image shows.
- Fix needed: clip the mirror draw to its own viewport in the shader (its clip-space x/y within +-w before the box),
  not by a scissor. An attempt to re-map through the full output viewport double-applied the viewport (reverted).
- **Fixed** (same morning): the mirror's clear covers the quad in 256 horizontal bands and the rest of the bounding
  box gets the nearest depth (multiview path), so the mirror draws stop at the quad. Turned 40 degrees the mirror is a
  slanted panel, larger near the edge of the wide view (perspective), with the scene around it
  (`evidence/gt5/2026-10-05-mirror-yaw-fixed.png`). Race frame rate unchanged. **Needs Matt's headset check.**

## 2026-10-05 morning: arcade menu with the simulator's real head pose

- `tools/re/simpose.py YAW [PITCH] [ROLL]` turns the OpenXR Simulator's head (its `head_pose_command.json`), so
  compositor layers move too. `RPCS3_VR_YAW_FILE` only turns the rendered pose: fine for content drawn into the eye
  images (the race HUD and mirror), misleading for screens with compositor layers (a dark axis-aligned rectangle
  stayed behind the turned menu panel). Use simpose for menus; set HUD Vertical Offset 70 (temporary config) or the
  box sits low in the simulator's view.
- Arcade menu (`vrtest_gt5_arcade_menu`), poses yaw/pitch/roll 0/0/0, -20/0/0, 20/0/0, 0/15/0, 0/0/15, 20/-10/10:
  `evidence/gt5/2026-10-05-arcade-menu-real-pose.png`. Pitch 15: the panel's lower part (Single Race, thumbnails,
  buttons) is cut along a straight horizontal line; yaw -20: its lower right is cut along a diagonal. Matt's "obscured
  when the HMD turns or tilts". Checked at full resolution: the panel's own cuts are the edge of the field of view
  (looking up 15 degrees the world-fixed box runs off the bottom of the eye image: its scissor clamps at the shown
  region, y 1440 at 200%), so those are expected. **The real fault:** at yaw -20 the front card's art is cut to a
  ~80 px strip (about 250 px straight ahead) while the panel around it is whole. `hud_keep_depth` is already on (all
  box draws keep the game's z/w, as the exact-depth card program does), so it is not the box's w changing depth.
  Next: find the card draws (RTDUMP / per-draw trace at yaw -20) and their scissor and clear rectangles.

## 2026-10-05: arcade menu cards fixed (fork 34fb98183)

Found with the simulator's real head pose (yaw -20), the inspector, `RTDUMP` of the display buffer and the depth
surface `0xc1100000`, and probe `why=`:
- Each card is drawn in two steps: the card art is copied into an 800x452 target (`0xc5a79380`, 2D program
  `6f712431641e8509`, not boxed), then drawn as a perspective quad into the display buffer (program
  `2f7d1792dfd94351`, exact depth, boxed).
- **Fault 1:** the menus draw through a 1280x720 viewport into 2048x1080 buffers, which counted as a sub-viewport, so
  the full-screen colour and depth clears were boxed like the mirror's. Turned, the boxed depth clear missed the
  cards and each card failed its LESS test against its own depth from the frame before (the cut). Sub-viewports
  are now measured against the shown part of the target.
- **Fault 2:** `vr_keep_depth` scaled z by w'/w, but the box matrix's z row is the viewport's (`z' = s*z + o*w'`), so
  depth moved with the head angle (0.99996 straight, 0.948-0.963 at yaw -20) and the stack's cards cut through
  each other. The shader now writes the game's window depth (`s*z/w + o`) at the box's w.
- Checked at yaw 0, +-20, pitch 10, roll 15 and combined (`evidence/gt5/2026-10-05-arcade-cards-fixed-poses.png`),
  and with the selection changed at angles (`...-selection-angles.png`). Regression: SotC (the other keep-depth
  game) 90, GT5 120, ICO 30, unchanged. Mirror rechecked with the real pose. **Needs Matt's headset check.**

## 2026-10-05 midday: cars culled beside the player (Matt, savestates 2_11 and 2_12), not fixed

- Symptom: a car beside the player is invisible (2_11, head turned left: its shadow on the track, no car); a car half
  outside the game's view is drawn without its outside pieces (2_12, straight ahead: rear panels and rear window
  missing, interior visible, paint a multicoloured dot pattern). Scenery is not culled.
- Not the renderer: GT5 never enables user clip planes (logged on 2_12; dev hook reverted). Occlusion queries are
  off in Matt's config (every query reports 0), so they are not the cars' visibility test either.
- Not Sony EDGE: no `EdgeGeomViewportInfo` record in memory (scan for viewport scales 640/-360 next to a scissor and a
  view-projection). The only viewport is the plain one at `0x1a39160`.
- The camera view-projection (inspector, main 1280x720 target, rows 1.3103 ... / ... 2.3289 ...) exists only in the
  RSX command buffer (13 copies at `0x41xxxxxx`), nowhere in PPU memory: the SPUs build the matrices and the draw
  lists, so the per-piece culling runs on the SPUs.
- FOV-looking values are not the camera: `0x1911930`, `0x19972dc`, `0x19cf53c`, `0x186e404`, `0x179a318` (static data)
  and `0x30797488` (46.44) are never read or written by the PPU in a running race (read/write watches, interpreter);
  `0x3053f6e4` (46.5) is read ~15,000/s through a generic accessor `0x8aeb58`, and setting it to 70 only changed a HUD
  text line. Blind writes to the ~36 candidates (an earlier attempt) unpaused the game and switched its camera.
- Next: find the camera parameters the PPU passes to the SPU jobs, or the SPU culling program itself (SPU patch).

## 2026-10-05 afternoon: frame rate with many cars in view (Matt's paused savestate 2_13), no fix found

- `BCUS98114_2_13` (paused, ten cars ahead) loads paused only with Matt's pad connected (otherwise the race runs).
  Simulator, Matt's config, VR Frame Rate 90 (the simulator reports no refresh rate): ~48-50 FPS, RSX thread
  ~20 ms per frame (the limit), 2,420 draws (1,843 on the main 1280x720 target).
- Cars: each car is 110-165 draws at any distance (4.8 m: 132, 63 m: 110); the game's LOD lowers vertices
  (112k at 10 m, 25k at 63 m), not draws. Ten cars ~1,350 main-pass draws (73%). A lower-LOD patch would not
  reduce draws much; only drawing fewer cars would (~1.4 ms of RSX thread per car).
- Hiding the shadow-map programs (`c0324ae756edb42b`, `cbaec9167c09d2`, `373812cf945f923a`, `30532bfcf0d877be`:
  187 draws) and the reflection-map programs (12, 97 draws) with probe `hide=`: +1 and +0 FPS, both +2.5 FPS (the
  per-draw cost is mostly paid before the renderer's skip point). Not worth the lost shadows and reflections.
- RSX thread profile (`RPCS3_RSX_SAMPLE=2`): spread out. FIFO reading ~12%, texture uploads and memory blits
  ~10-14%, `load_texture_env` ~13%, VR per-draw setup ~13%, fragment program lookup ~8%, pipeline lookup ~8%,
  vertex upload ~6%, submits ~5%.
- Texture re-uploads: ~63 per paused frame (54 addresses, car DXT textures, two 1024x1024), the bytes unchanged.
  Cause: GT5 rewrites small per-frame data (e.g. the cars' 8x8 textures) in 4 KB pages shared with the ends of car
  textures; the texture cache locks pages, so each write drops the texture. Tried (reverted): hashing sections
  below 128 KB instead of locking (uploads -90%, but 48 -> 44.5 FPS: every use hashes); skipping the upload copy
  when a reused image's bytes are unchanged (88% of uploads skipped, FPS unchanged: the copy is not the cost).
- Savestate-only corruption (multicoloured dots on cars): the per-car 256x512 ARGB textures (unit 8); theory, not
  tested: built on the GPU at race load and not in the savestate with Write Color Buffers off.

## 2026-10-05 late afternoon: car_draw_limit (fork 51ff40a65), Matt: "works well"

- Draw only part of each distant car. Tried on paused 2_13/2_14 (simulator, VR 90): 5 nearest cars only 48 -> ~63 FPS
  (RSX thread 20.8 -> 15.5 ms); wheels and drivers needed learned car-part programs. A flat cap per car (60, 28)
  showed holes and lost the glass: each car draws a body pass (~100-125 draws, all cars in turn, nearest first) and
  a later pass (~4-40 draws: glass, see-through parts) after all bodies; caps now apply to the body pass only.
  A vertex threshold (400) hit one model built from many mid-size pieces (62% lost); keep_percent (largest draws
  making up p% of the car's vertices, per car) evens it out (85%: 52-64 draws skipped, 15% of each car).
- GT5's own LOD: full model to ~75 m, a ~10-draw far model from ~95 m (complete, with glass). Moving the switch
  closer was tried: the tables [16,76,88] 0x184057c, [50,80,350] 0x185fe38, [60.9,80.54,244.75] 0x18c3a80,
  [4.5,11.75,13.2,79] 0x190be50 written before unpausing: no effect (switch not found; maybe screen size or SPU).
- Profile: `[{ "cars": 2 }, { "cars": 4, "keep_percent": 85 }, { "cars": 0, "keep_percent": 70 }]`. The pre-race
  `reduced_scale_frames` stays (removing it: the fly-by is GPU-bound at high scales, Matt confirmed).
- Do not call `draw_clause::get_elements_count()` before the draw starts: it froze RSX (`get_range` verification);
  `vr_total_elements()` added.

## 2026-10-05 evening: main menu (driver walking out) fixed (fork 72aaa988b)

- Matt: the driver looked doubled; looking down, an overlay in the wrong place; then a translucent duplicate of the
  menu video throughout (also outside the garage).
- Doubled driver: the menu's blurred backdrop is a mip chain at 0xc3780000 (draw 264 copies the menu image in as
  2048x720, draw 265 rebinds the address as 2048x1436 and halves it level by level, draw 277 reads 11 levels). The
  new 2048x1436 surface lost `vr_has_3d`, so the chain counted as eye-invariant and the right eye read the left
  eye's chain (left-right image shift 0 px against ~-900 in races). Inheriting the flag in surface_utils.h
  (set_old_contents / set_old_contents_region) fixed it (-880 px) but was reverted (generic; not needed once the
  menu went 2D).
- Duplicate overlay: draws 277/279 (095a653b00894379, fc7082dabcd91a9a) blend that blur chain over the scene,
  weighted by the depth buffer 0xc2880000 (format 129, read as a 2560x1440 colour texture): depth of field.
  `min_scalable_dimension` 512 left the chain's 512x256 step native between 4x-scaled 2048-wide steps, so the
  blurred layer landed enlarged and misplaced. 511 (or none) fixes it; the 256x511 reflection maps stay native.
  Race cost not measured (512-wide post passes scaled again: GPU work; races are RSX-thread bound).
- Profile: `screen_frame_draws` [095a653b00894379, 2560x1440]: the menu and the pre-race fly-by go on the fixed
  screen whole (Matt: better, the fly-by now at full resolution).
- Method notes: the simulator screenshot (simshot) is black for GT5 menus; RPCS3's SHOT hook (shot.py) works. The
  boot dialog after a fresh ISO boot only shows on RPCS3's window. Compare per-eye images by left-right shift
  (cross-correlation), not by pixel positions: each eye's projection centre differs (~900 px at 400%).
  Do not compare menu shots taken at different moments: the sequence changes lighting fast.

## 2026-10-05 night: why 2_17 runs at ~50 FPS when 2_14 runs at ~75 (simulator, VR Frame Rate 90)

- Same build and tiers: 2_17 ~51 FPS (RSX thread 19.2 ms), 2_14 ~75 (13.0 ms). 2_17 is a heavier frame in every
  category, not one bad pass: even with the car tiers 2,654 draws / 1.49M vertices against 2_14's 1,829 / 978k
  (2_14 without any limit). Main view 940k vertices vs 645k (nine cars at 9-58 m, models of ~183 draws each vs ~135);
  reflection map 534 draws / 139k vs 87 / 12k; shadow maps 345 / 346k vs 202 / 271k; other passes 313 vs 233.
  The rest of the scene is the same (~480-490 main-view draws).
- RSX sampler diff (`RPCS3_RSX_SAMPLE=2`): the extra 6.2 ms is spread over per-draw work; vertex emission grows most
  (`emit_geometry` +2.4 ms: GT5's vertex data is in main memory, copied every draw), then draw handling +1.7, FIFO
  +1.3, VR per-draw setup +0.7.
- Tried on 2_17: reflection map skipped entirely (all 256x256 draws) 48.5 -> ~51 FPS (1.1 ms for 534 cheap draws; not
  kept); `min_scalable_dimension` 511 vs 512: no difference; Multithreaded RSX on: no gain (51.6-52.7 vs 53.7);
  aggressive tiers (nearest car full, rest 70%) ~53.7 but Matt: too much culling, reverted to 2 / 4x85% / 70%.
- Car shadows: shadow draws carry no world position (c[256..259] identity, the model in the light transform), so the
  tiers cannot reach them without inverting each cascade's light matrix; shadows are cheap depth draws (~1 FPS at most).


## 2026-10-09 night: RSX-thread work on the paused busy scene (2_17), in progress

Target: `savestates/BCUS98114/gt5_busy_race_2_17` (paused, pad connected; identical frames at 3 s and 12 s), simulator,
Matt's config at 400% stereo, Vblank 90, Frame Rate Unlimited, multiview. Run helper: scratch `pab.sh` (gt5_race.sh with
`KEYS='\n'`), average of the last 8 s. Baseline 51.5-52.4 FPS, RSX thread 19.0-19.3 ms/frame (GPU idle).

RSX thread sample (`RPCS3_RSX_SAMPLE=2`, 6,653 samples): run_FIFO outside draws ~17% (fetch_u32 4.9 self, run_FIFO 4.5,
read 2.1, decode 1.2), `VKGSRender::end` ~60%: emit_geometry 31 (vr_setup_draw 9.6, program::bind 8.4 = driver descriptor
work, upload_vertex_data 5.1), load_texture_env 11.9 (fast_texture_search ~5, upload_image_from_cpu 2.6), load_program 7.9
(pipeline lookup 6.5: FP storage hash 1.4 + FP compare 1.4 + VP hash), analyse_current_rsx_pipeline 3 (FP analysis 2.2,
VP analysis 2.3 with heap allocations), submits 4.2, blits + inline transfers ~6, flip 2.8, do_local_task 3, VirtualProtect
1.7, heap alloc/free ~3-4 (callers not yet attributed). Nothing dominates: ~7 us of RSX thread per draw at 2,650 draws.

- Config check (Matt: configs are settled, code changes only from here): Max SPURS 5, SPU loop detection, Disable Vertex
  Cache: no change on the paused scene. RSX FIFO Fetch Accuracy "Fast" 54.5 FPS / 18.2 ms against 51.5 / 19.3 (about
  1 ms a frame of the atomic fetch) - recorded only.
- Unpausing 2_17 (Start, hold R2) is not a measurement: the scene reaches the 90 cap within 3 s. Matt: keep it paused.
- Code: the VR trace (`vr_tracing()`, 6 frames of every 150 built strings every draw) is now opt-in (`RPCS3_VR_TRACE=1`).
  The fragment program ucode hash is computed in the analysis pass (`fragment_program_metadata::ucode_hash`,
  `RSXFragmentProgram::ucode_hash`) so the pipeline lookup no longer re-hashes the ucode every draw (the compare stays).
- Dev hook `RPCS3_VR_RSX_CORE=<cpu>` (rsx_vr_hooks.cpp): RSX thread alone on a core, other threads off the SMT pair. Not
  measured: the paused scene has idle SPUs (5.7% total CPU), so there is no contention to remove there.
- Pipeline lookup: a direct-mapped cache (512 slots by program ids) in front of the pipeline map, whose hash and compare
  walked ~300 bytes of pipeline state per draw (`program_state_cache::get_graphics_pipeline`); fragment programs compare
  by two 64-bit hashes computed in the analysis pass instead of a word-by-word scan (`RSXFragmentProgram::ucode_hash2`).
  Three runs: 56.1 / 17.70, 55.1 / 18.01, 53.9 / 18.44 (run-to-run spread ~0.4 ms) against 53.4 / 18.58.
- Inspector capture of the paused frame (2,654 draws): six 256x256 cube faces 534 draws / 139k vertices (environment
  programs only, no car programs), six 256x511 copies of 8 draws each, a 256x128 pass of 129 draws (the mirror), shadow
  cascades 1024x2048 139 / 1365 174 / 682 24 draws (342k vertices), the main 1280x720 pass 1,462 draws / 940k vertices
  (334 body-program draws in 9 transform groups = 9 cars), 2048x1080 display-buffer HUD ~80 draws.
- **New profile key `shared_frame_targets`** (`[{ "width": 256, "height": 256, "frames": 3 }]`): the cube faces take
  turns, two refreshed a frame, the others keep their content (draws and clears left out; one-line hook in
  `clear_surface`). 59.6 FPS / 16.65 ms. Simulator shots at 12 s match the run without it. Headset check: car paint
  reflections lag up to 2 frames.
- LOD (game patch) leads, parked: the executable's reflection metadata names `GTRender::EnvironmentSetting::LOD` members
  `base`, `discreteBase`, `meshBase`, `meshCurveBase`, `meshOffsetBase`, `meshGap`, `forceRoughestLOD` (member descriptor
  tables at 0x1849xxx-0x185cxxx, name strings at 0x155dxxx/0x1586xxx/0x1589xxx/0x1590xxx; `tools/re/strrefs.py`),
  `BasicParameterSet::lod`/`lodEnv`, `ReflectSetting::lodScale` (default 0.05), `PDIGraphics::ModelSetTraverseCallback::LODCtx`
  (PPU-side model traversal with an LOD context). Script natives (binding table at 0x17a7xxx: {0, 0x154d738, 0x154d738,
  name, function}): `setStaticLOD` (0x225db0 -> setter 0x1f0660: model = *(component+0x10); level at model+0x80, flag bit
  31 of model+0x84 = static LOD on), `changeLodCar` (0x2159e0 -> 0x1ffc1c), `getCarLODSize` (file sizes, not rendering).
  Not found yet: the code that reads model+0x84 / the distance thresholds (a scan for sign tests after `lwz 0x84(r)` found
  nothing; the chooser may use a pointer to model+0x70 and offsets 0x10/0x14, or run on the SPUs).
- FIFO: `FIFO_control::fetch_u32`'s cached-word path inline (RSXFIFO.h; the out-of-line call per FIFO word was ~2% of
  the thread in Atomic fetch mode), plus VR trims (no per-draw copy of the game's constants, plain display-buffer
  addresses) and `camera_block_cache: true` in the profile: 62.1 / 15.99 and 61.1 / 16.22. Running total 19.2 -> 16.1 ms,
  52 -> 62 FPS. Fork commit "RSX thread: cheaper per-draw lookups, shared_frame_targets".
- **Texture cache: hashed edge pages** (upstream `texture_cache*.{h,cpp}`, fork commit f6ae732dc). The 4 KB pages at the
  ends of GT5's car textures are written by the game's own per-frame data (the writer is the RSX inline transfer, the
  fault is handled on the RSX thread); the texture cache unprotected and dropped ~60 sections a frame, then uploaded them
  again unchanged. A write into a locked section's slack at one end of its page range now gives that page back to the
  writer and the section's bytes in it are hashed (checked once a frame in `sync()`); the other pages stay locked. Only
  shader-read, non-flushable sections whose other sections do not lock the page qualify; dev `RPCS3_TEX_EDGE=0`.
  67.1 / 14.79 and 67.8 / 14.64 (from 16.1). The Indy race start (`gt5_race.sh`) still 90 locked, RSX 5.4-8 ms, no new
  log errors, picture clean. Running total 19.2 -> 14.7 ms, 52 -> 67.5 FPS.
- Tried and reverted: a memo of texture lookups by the texture unit's registers (valid per update tag, invalidation
  count and frame). Alternating runs off/on: 15.64/15.41 and 14.83/14.72 ms: 0.1-0.2 ms at best, below the run-to-run
  drift. Note the drift: the same build measured 14.6-15.9 ms over an hour (VS Code's cpptools re-indexes after source
  edits; measure A/B alternately, never one run against an old number).
- Vertex program analysis cache (fork 37cc824f7): A/B pairs 14.80/14.59, 14.65/14.52. Kept.
- Profile keys `texture_lookup_memo` (the memo above, Matt asked to keep it available) and `backend_interrupt_per_draw`
  (false: no backend interrupt after every draw), fork 3b6288a8f: alternating A/B within the drift either way (memo on
  14.68/14.63 vs off 14.34/14.48; interrupt off 14.69/14.28). Both off in the profile. Best runs so far: 14.3-14.5 ms,
  68-69 FPS (from 19.2 / 52).
- Memo and interrupt keys removed again (Matt: no improvement, no code). Eye-constants fast path (fork, the block cache
  reuses the previous draw's slot offsets): 14.51/14.18 with, 14.49/14.43 without any block cache.
- **Config, with Matt's go-ahead: `RSX FIFO Fetch Accuracy: Fast`** set in `config_BCUS98114.yml` (was Atomic).
  Alternating A/B: 13.92/13.98 vs 14.37/14.24 ms, no FIFO errors in 2 runs. `Disable FIFO Reordering: true`:
  14.11/14.53 vs 14.37-14.47, inconclusive, left as is. Now 13.9-14.0 ms, 71 FPS on 2_17.
- **Regression 2026-10-09-2330-gt5night** (all 42 states, 72 and 90 Hz, `tools/re/regcompare.py` against
  2026-10-04-1837): no state worse; Jak 2, Kingdom Hearts 2 and Killzone 2 carrier none -> 72, SEGA Rally none -> 90,
  Jak 3 51 -> 61 FPS, X-Men 54 -> 66, DW6E RSX 11 -> 3.5 ms. SotC stalled once at boot (`vk::wait_for_event has timed
  out` from 11 s, the known intermittent boot stall; passed on the retry); R&C 1 one boot without stats, passed on
  retry. Killzone HD trench 1.5% late at 72 (earlier runs 0.3-0.8%): A/B default / `RPCS3_TEX_EDGE=0` /
  `RPCS3_VR_VP_CACHE=0` 1.11 / 0.97 / 0.69%: noise around the threshold, not one change. ICO "none" only because the
  run's RATES override skipped its 30 Hz tag. The temporary keyboard pad `input_configs/BCUS98114` a run left behind was
  moved to the session scratch folder.
- **02:00-03:30 (Matt: decide the visual calls myself).** Tried and removed: `shared_frame_blits` (the exposure chain
  0xc57f8000.. and reflection mip chain 0xc9bca700.. on alternate frames): slower, 15.10/14.68 vs 14.34/14.27 (the
  readbacks those chains feed probably wait). **Kept:** distance-based car tiers (`min_distance`: full under 20 m, 85%
  to 40 m, 70% beyond; 13.92/13.58 vs rank tiers 14.26/14.25; RPCS3 SHOT crops of the 21-58 m cars identical in both)
  and the mirror pass (256x128) in `shared_frame_targets` every other frame (13.84/14.04 vs 14.24/14.26; the mirror
  updates at half rate, delete the rule to undo). Shipped state: 73.8 / 73.7 FPS, RSX 13.45 / 13.52 ms on 2_17; Indy
  start 90 locked, no FIFO errors. Fork commit d85e15e12.

## 2026-10-10 morning: push descriptors, texture lookups (in motion as well as paused)

- **Push descriptors** (fork a631a734e, local until the regression): the fragment set of game pipelines written with
  vkCmdPushDescriptorSetKHR, skipped when unchanged and the pipeline is still bound; fallback on GPUs without
  VK_KHR_push_descriptor or sets over maxPushDescriptors; `RPCS3_VK_PUSH_DESCRIPTORS=0`. Cycle timers (ms per second of
  play, ~75 FPS): descriptor work 76.7 -> 66.6 (commit 33.8 -> 15.1, set bind 15.9 -> 11.3, submit flush 27.0 -> 10.1,
  new push build 4.1 + driver push call 26). Why the profile overstated it: it counted both sets plus the pipeline bind
  (~1.6 ms a frame); push replaces only the fragment set's share (~0.55 ms) and NVIDIA's push call costs ~0.35 ms of
  that. Net ~0.15 ms a frame. Pipeline binds alone: 37 ms per second (GT5 switches programs ~160k times a second).
  Each game rebuilds its pipeline cache once on the first boot after this change (new layout): WipEout's first boot
  measured 32 FPS for that reason.
- **Texture lookups** (counters per second, paused 2_17): 500k units checked, 77% skipped already, 114k real rebinds
  (the game binds a different texture; ~0.7 us per cache search, 77 ms), 380 from the global dirty flag, 0 expired.
  The cache's update tag changes ~1,100 times a second. Would-be memo hits: 39% (tag-cleared), 50% (per frame).
- Tried and removed (no gain): fragment-program analysis cache (byte compare against a stored copy; pairs 14.01/13.87,
  13.63/13.42, 13.54/13.69), lean texture lookup memo (256-entry direct-mapped, per tag + frame): paused 13.13/13.40,
  13.21/12.90, 12.96/12.95; in motion (Indy start, R2, Vblank 180, s 2-12) 5.49/5.55, 5.51/5.42, 5.44/5.57.
- Motion testing: unpausing 2_17 with R2 held drives the car into the wall (no cars in view by second 3); the Indy start
  (`gt5_race.sh`, Vblank 180) stays on the straight but the pack is far ahead (RSX 5-7 ms). A busy scene in motion
  needs a driven replay or a key script that steers.
- **Home-menu options** (fork 0311543de): the three visible trade-offs (cube faces in turns, half-rate mirror,
  distant-car tiers) follow new VR settings Reduced-Rate Reflections, Reduced-Rate Mirror, Simpler Distant Cars, on by
  default and live; the profile tags the rules with `"option"`. Busy scene: all on 13.2-14.1 ms, all off 16.7 ms.
  Quick regression (16 states) and push descriptors pushed: `evidence/vrtest/2026-10-10-pushdesc-check/`.
- Distant cars changed at Matt's request (checked in game): the nearest car always complete (`full_nearest` 1), other
  cars full under 30 m, 85% from 30 m, 70% from 45 m (was 20 / 40 m).
