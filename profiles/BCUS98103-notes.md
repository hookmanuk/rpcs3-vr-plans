# Uncharted: Drake's Fortune (BCUS98103, update 01.10)

Executable `PPU-8363904e0b8fc276380a8f0e158dd81d7a9cefc5` (update 01.10, installed 2026-10-13); decrypted copy
`tools/re/elf/BCUS98103-0110.elf` (`RPCS3_DUMP_ELF`). Matt's profile from the generator (2026-10-13), Matt's config:
Resolution Scale 500, VR Frame Rate Default. Community patches on: *Disable Motion Blur*, *Disable Depth of Field*,
*Skip Intro*; *Unlock FPS* **off** (see Frame rate).

Savestates: `vrtest_uncharted_boat` (mine, boat deck after Continue), `BCUS98103_1_0` (Matt's, combat on the boat,
loads paused: Start to resume).

## Crash (fixed, fork 90bd7ed59)

RPCS3 died 14-90 s into gameplay with no fatal log line (Windows: access violation executing a junk address such as
`0x1e800000000`; a DLL's crash handler ends the process, so no WER dump). A temporary log of the faulting context in
`exception_handler` (Utilities/Thread.cpp) gave `rip=0` called from `vr_complete_late_readbacks`: the profile's
`late_readback_lengths: [64]` entry kept the texture section's `dma_fence` pointer, and the section freed that event
(resource manager, at the end of the current submit) when the game copied into it again. Entries now keep the event
counter. Savestates of this game work.

## Frame rate

- The community *Unlock FPS* writes 0 to the limiter word `0xbb4350` (render options struct at `0xbb4348`, built by
  the init at `0xe5100`; 0 unlocked, 1 one vblank a frame, 2 two, the game's default). The word is read at init only:
  poking it in a running game does nothing.
- Profile `default_fps 45`, `vblanks_per_frame 2`, `max_fps 0`: the vblank runs at 90 and the game's own limiter holds
  45. Boat at 500%: 44.3-44.9 FPS, 0-0.56% late, frame time flat at 22.2 ms (unlocked: 48-57 with 1% lows ~33).
- Ceiling (Vblank 600, Frame Rate Unlimited, so no vblank quantisation): boat 48-57, Matt's combat state ~45
  (min 38-42 in its first seconds). Game speed at 45 not yet checked (a walk test was inconclusive: both modes hit the
  railing).
- Where the time goes (combat): six SPU threads ~100% host CPU, PPU main thread 76%, RSX thread waiting on the FIFO
  ~60% of the time. PPU profiler: ~54% of the main thread's busy samples are in the statically linked SPURS job wait
  (`0x6f6c34`, min of six SPU counters vs a target; callers across the engine), so the frame waits on SPU jobs. SPU
  profiler: 27.5% idle, 9% reservation waits; the top block (`fS4Sk69-0x0851c`, 17%) only issues an MFC DMA
  (`wrch MFC_Cmd`), `1Na5eVn-0x08548` (4%) waits on its tag: DMA emulation, not game maths.
- Tried, no gain beyond run-to-run noise (+-4 FPS): SPU XFloat Relaxed, SPU loop detection, Max SPURS 4/5, RPCS3 and
  RPCS3 Alternative schedulers, community *Disable Dynamic Shadows* / *Disable Dynamic Lighting*. SPU GETLLAR busy
  waiting 0%: 3-19 FPS. Not finished: Accurate SPU Reservations off (stopped by Matt for the culling work).

## Culling: "Wider view (VR culling)" (`bin/patches/BCUS98103_patch.yml`)

The game culls against its 75 x 46.7 degree view: in the headset the deck, hull and ocean ended at its frustum (flat
blue below the deck, grey wedges). The camera's projection x scale is built at `0x4b4d28`: `f1 = tanf(fov x k)`,
`f1 += [r27+0x30]`, `cot = f31 / f1`, stored at camera `+0x1d4` (`0xc9cf44`; the camera at `0xc9cd70` holds view
`+0x50`, projection `+0x90` (x -1.30323, y 2.31685 = x / 0.5625), view-projection `+0xd0`). The patch (`calloc` at
`0x4b4d3c`) multiplies the tangent by the word `0x7cdd80` (unused zeros at the end of the code segment, seeded 1.0).
The profile's `culling_scale_f32` (`fov_deg 46.7`, `aspect 1.7778`, `margin_deg 3`, `max 12`, `mode tangent`) sets it
per frame: 3.6 straight ahead, 7.2 at pitch 10, 12 at yaw 35 / pitch -25.

Found by: the FOV (75) copied each frame into a 0xc8-byte settings block (`0xdb24a8`, unpacked at `0x2b46e4` into
globals `0x83fc48` 20 / `0x83fc4c` 100 / `0x83fc50` 75: debug camera limits, not the live camera), then searching memory
for the projection's 1.30323 / 2.31685 and a write watch on `0xc9cf44`.

Simulator (300%, real head pose): fills at yaw 0, +-20, pitch +10 / -25, roll 15 and yaw 35 / pitch -25; at yaw -35 /
pitch -25 a small corner of the right eye still shows. Evidence: `evidence/uncharted/widerview-headposes-2026-10-13.png`,
`widerview-before-after-x2.png`, `widerview-x4.png`. Cost in Matt's combat state (Vblank 600): 44.7 / 44.8 -> 42.1 /
42.5 FPS (RSX thread 21.9 -> 23.2 ms/frame).

Not checked: the aim/zoom camera, cutscenes.

### Lower-detail models (fixed: Wider view 2.0, 2026-10-13)

Matt: with Wider view 1.0 the game used lower-detail models. Not a LOD switch: the geometry jobs (SPU) drop triangles
that cover no pixel centre of the game's 1280x720 viewport, and the widened projection shrinks every triangle on that
viewport. The viewport block is built per pass at `0x452420` (`[r31+0x338]`: u16 scissor 0, width, 0, height at
`+8..+0xe`, the view-projection copied from the constant packet at `+0x10`, viewport scales and offsets at
`+0x50..+0x5c`). Patch 2.0 (cave at `0x452554`) multiplies the four floats and the scissor width/height by 16 before
the view-projection is copied (as Sonic's *Disable mesh trimming (VR)*). Measured on Matt's combat state (paused, so the
frame is frozen), scene target `c0f50000`, straight ahead (scale 3.6): no widening 628 draws / 281,538 vertices; 1.0
658 / 214,545; 2.0 699 / 374,865 (more than the game shipped with: its own trimming at 1280x720 is gone at 500%).
A dynamic grid factor (the scale word instead of 16) gave 703 / 341,763 at the same cost, so 2.0 keeps 16.

Cost (Matt's combat state, Vblank 600, two runs each): no widening 44.7 / 44.8; 1.0 42.1 / 42.5; 2.0 39.2 / 38.6
(the 16x viewport alone 41.4). Head poses on the simulator with 2.0: whole at yaw 0, +-20, pitch +10 / -25, roll 15
(`evidence/uncharted/widerview2-headposes-2026-10-13.png`, `widerview2-none-v1-v2.png`).

How it was found (dead ends included, for the next game): splitting the projection on the PPU (the frustum-plane
builder `0x1547d0`, the projection builder `0x156750` per call site, the per-frame packet `0xe4070` written to
`0xe5b020` for the SPU visibility job and to `0x3264xxxx` constant packets) always moved culling and "LOD" together; the
SPU visibility job (code RAM `0x857c00` -> LS `0x4000`, packet DMA'd to LS `0xdc00`) never reads the view-projection
(temporary SPU interpreter LS watch); `zcull_approximate` changed nothing. A PPU read watch on the constant packet's
view-projection found `0x452420` copying it into the viewport block. Temporary SPU hooks used (not kept): a DMA watch
in `spu_thread::do_dma_transfer` and an LS load/store watch in `SPUInterpreter.cpp`.

## DLSS (2026-10-13)

The DLSS settings are shown again (fork 59b26e4df: VR tab; the home menu offers them live in a session that booted with
DLSS on). Matt's combat state, 2880x2880 eyes, Wider view 2.0, Vblank 600 uncapped: DLSS off at 500% 37.3 FPS; Quality +
model E at 333% 45.3; Performance + model E at 250% 53.8 (the default model, K, at Performance 250%: 44.9). Plain 250%
without DLSS: 58.6 (so the GPU, not only the game's CPU work, limits it at 500%). The image on the simulator matched
500% without DLSS (boat, straight and turned); HUD fine. Note: builds need DLSS_SDK set, or they log "This build has
no DLSS SDK (HAVE_DLSS)" and DLSS does nothing.

## Shadows that moved with the head (2026-10-13)

Matt: all the shadows are wrong, they move with the head (DLSS on or off). The sun shadows are a full-screen pass
(`fc15ec0752d20290`, inspector draw ~3022 of the boat: target `0xc16d0000` 1280x720, texture 0 `0xc2d50000` 1280x720
format 0xa5, the 2432x2432 shadow map `0xc3ee0000` at unit 1). Its fragment program decodes a 24-bit depth from
texture 0 (`floor(tex.wxy * 255)` dotted with fc1), rebuilds the view position from `tc0` (a 0..1 screen uv, from the
vertex input) with fc4..fc6 and takes it to light space with fc12..fc18: positions for the game camera. Texture 0 is a
colour copy: the previous draw (same program, target `0xc2d50000`) reads the 2x MSAA depth `0xc0f50000` (2560x720) as
Z24-as-RGBA8 and writes one sample's bytes. With Wider view the game's NDC covers a 3.6x wider view than the eye's, so
the shadows were wrong even looking straight ahead.

Fix (fork 0eb6a05f5): profile `depth_remap_programs` entry gated to texture 0 1280x720 format a5 with a target of that
size (only this pass of the program), `depth_remap_uv`, `depth_remap_packed_unit: 0`. Checks: an identity remap
reproduces the unpatched picture exactly (the decode and re-encode round-trip); with the remap the shadow pattern no
longer changes with yaw +-15 on a paused frame, where the unpatched one changes shape. Not confirmed on the simulator:
that every shadow sits where flat play puts it (the pause menu covers the comparison area); Matt to check in the
headset. A texture redirect to the depth surface itself was tried first and dropped: the copy's 1280-wide pitch against
the 2560-wide MSAA surface read interleaved rows (blocky). Other passes that rebuild positions from the same copy
(`2ffe2bfb47d877be`, 4 draws into the scene; the 640x360 depth downsamples) are not remapped.

## 2026-10-15 overnight: frame rate re-check

Matt's combat state `BCUS98103_1_0`, Vblank 600 uncapped, 300%, his config (SPU Block Size Mega, DLSS Performance,
frame generation): **46.0 / 46.2 FPS median, minima 42.9-44.5**, RSX thread 21.4 ms/frame (35% of its samples waiting
for the FIFO). Threads: PPU main 88%, SPU kernels 87-100%. SPU Block Size Giga 45.5 (no change). Accurate SPU
Reservations off: the game stays on its pause screen (freeze), not usable.

Splitting *Wider view* into x and y scales (God of War III: +13 FPS, the headset needs ~2x the width but ~3.6x the
height here too) is not a one-site patch in this game: the projection builder derives y = x / `[cam+0x1d0]` at
`0x1569d4`, and many other functions read the scale at `+0x1d4` (culling planes included), so each would need the same
change.

## Wider view 3.0: per-axis, head-driven (2026-10-15)

The culling has followed the head since 10-13 (`culling_scale_f32`, as GT5), but one scale widened both axes by the
larger need: straight ahead the headset needs ~2x the game's width and ~3.6x its height (its FOV is far beyond the
game's 75 x 47 degrees, so the widening never drops to 1 looking forward). The projection builder derives y = x /
`[camera +0x1d0]` (aspect 0.5625), so the cave at `0x4b4d3c` also writes the aspect: base x sy / sx, with the game's own
value kept at `0x7cdd88` and the last value written at `0x7cdd8c` (a change from the game becomes the new base). Words:
x `0x7cdd80` (`tangent_x`), y `0x7cdd84` (`tangent_y`), unused zeros in the code segment. Straight ahead: sx 1.97,
sy 3.60; projection P00 -0.662, P11 0.643 (checked live). Note: a `calloc` count one too high made RPCS3 skip the
cave silently (the branch was never written; the old values stayed); count the instructions.

| `BCUS98103_1_0` combat, 300%, simulator | v2 (one scale) | v3 (per axis) | no widening |
|---|---|---|---|
| Vblank 600 uncapped, median FPS (2 runs) | 46.7 / 46.8 (min 43.7-44.9) | 47.2 / 48.0 (min 45.9-46.4) | - |
| 45 locked (Vblank 90), 1 s windows under 44.5 of 30 | 0, 7 | 1, 4, 0, 1, 2 | 1, 3 |

At 45 locked, v3 dips as often as no widening at all: the remaining dips (1-3 s per 30, to 39-43) are the game's
own combat spikes. Coverage: full eye dumps at pitch -25 with yaw 0 / +35 / -35 show the same small corner holes as v2
(`evidence/uncharted/v3_edges_*`, `v2_edges_*`); head poses 0 / +-20 / pitch +-10 / roll 15 whole
(`v3pose_sheet.png`). Model detail unchanged (the 16x geometry viewport stays).

## What costs what (2026-10-15, Matt's combat state, Wider view 3.0, his config: DLSS Performance + frame generation)

GPU profile (`RPCS3_VR_GPUPROF=1`, 300%): ~21 ms of GPU work per 21.5 ms frame, GPU 85-89% busy. Per target:
present (DLSS + frame generation + composite) 5.5 ms, main scene `c07d0000` 4.9 ms, `c34b0000` (a 102-draw pass of the
world programs before the scene) 3.7 ms, depth prepass `c0f50000` 2.8 ms, depth copies/shadow mask `c2d50000` 1.8 ms,
shadow maps 2432x1216 0.2 ms (1214 draws). Frame order: shadow maps, half-res scene `c31e0000` (277 draws), depth
prepass, `c34b0000`, scene, sun-shadow/lighting `c16d0000`.

| Change (uncapped, Vblank 600, two fresh loads each) | FPS |
|---|---|
| base, 300% | 46.9-48.0 |
| Resolution Scale 250% | 53.0 / 53.0 |
| Resolution Scale 100% | 66.2 / 68.5 |
| DLSS Ultra Performance (300%) | 38.1 / 38.3 (slower; not investigated) |
| Video MSAA Disabled (the game's passes are 2x MSAA, `aa_mode 3`) | 47.0 / 47.1 (no change) |
| Dynamic shadows off (debug byte `0x8400d4` = 1, what the community patch sets; pokeable live) | 47.9 / 48.3 vs 47.6: +0.7, the whole level goes flat-lit |
| `c34b0000` draws hidden (probe `hide=hash@c34b0000`) | +0.7, picture unchanged at a glance (noise level) |
| half-res `c31e0000` draws hidden | no change |

No single in-game effect is costly: the cost is the scene's pixel work at the eye resolution, and the present path.
Note: the shadow-map programs also draw the depth prepass (both colour target 0), so a probe hide cannot separate them.

Holding 45 locked (Vblank 90, the game's 2-vblank limiter): the 1 s windows under 44.5 come from single long frames
(over 22.2 ms, shown for 3 vblanks = 33 ms); they appear at 250% (5-9 per 30 s) as at 300% (1-4) and with no widening
(1-3): game-side spikes in combat, not GPU load. Idea not tried yet: a finer limiter (Vblank 180 with the game limiter
word `0xbb4350` set to 4, init-time only, so a patch) so a late frame costs 5.5 ms instead of 11 ms.

## Wider view 3.1 and a frame-pacing idea that did not help (2026-10-15)

3.0 kept the game's aspect and the last written value at `0x7cdd88`/`0x7cdd8c` (code segment): writable after a
savestate load, read-only on a fresh boot, so a fresh boot crashed after the intro (VM access violation writing
`0x7cdd88`). 3.1 keeps them at `0x11eff00`/`0x11eff04`, zeros between the end of .bss (`0x11e22e8`) and the heap
(`0x11f0000`). Fresh boot, Continue into "The Search for El Dorado" (jungle): runs, words correct (base 0.5625).

Finer limiter (tried, reverted): the limiter word `0xbb4350` (2 vblanks) is stored at boot by `0xe515c`
(`stw r8, 8(r29)`); a patch storing 4 with the profile at `vblanks_per_frame 4` (vblank 180) ran. But the same jungle
spot runs 38.1-38.4 FPS with it and 38.4-38.6 without, median frame 26 ms in both: RPCS3 flips a late frame as soon
as it is done (no vsync quantisation), so a missed 22.2 ms slot costs only the lateness, not a whole vblank. Nothing
to gain.

New state `vrtest_uncharted_jungle` (fresh boot, Continue, 3.1, normal pacing): a heavy scene, ~38 FPS at 300%
(Matt's DLSS Performance + frame generation config, simulator). Matt's Uncharted config has VR Frame Rate
**Unlimited**: on a 90 Hz headset that targets 90 FPS (vblank 180 with the game's 2-vblank limiter), not the profile's
45 lock; "Default" gives the 45 lock.

## DLSS off vs on in the jungle (2026-10-15)

`vrtest_uncharted_jungle`, 300%, uncapped (Vblank 600), two fresh loads each: DLSS Performance + frame generation
(Matt's config) **40.5-40.8 FPS**, GPU 24.6 ms/frame, RSX thread 24.3 ms; DLSS off **55.3-56.0 FPS**, GPU 17.9-18.1,
RSX 17.8. In this fork DLSS does not lower the render size: at 300% the eye renders 1920x2160 either way (the eye
shape) and DLSS upscales to 2880x2880; so it costs ~5 ms of present plus GPU contention in the scene pass (9.4 ->
7.9 ms) for anti-aliasing, a sharper upscale and frame generation. With DLSS off the jungle has 4 ms of headroom under
a 45 lock. Plans for cutting pixel work without lowering the centre resolution: `11-vrs-plan.md`,
`12-hidden-area-mask-plan.md`.

## VRS and the hidden-area mask in the jungle (2026-10-15, branch `vr-pixel-savings`)

Both work on the simulator and gain little here: VRS **+1 FPS** (39.6-40.4 -> 40.7-41.6), the synthetic hidden-area
mask at 20 % of the target **+0.6 FPS**. The scene passes are geometry / per-draw bound: the colour pass `c07d0000`
costs 9.2 ms at 300 % and 8.2 ms at 100 %, ~2.05 M vertices per frame (doubled by multiview). Pixel-scaled costs are
present (DLSS + frame generation, 5.3 ms) and the full-screen passes (1.8 ms). VRS needs the special depth compare
dropped in its passes (the EQUAL colour pass broke at coarse rates). Details: `11-vrs-plan.md` and
`12-hidden-area-mask-plan.md` section 7. Next leads for the jungle are vertex work: the shadow maps (~583 k vertices,
not multiview), and the 16x geometry viewport (a savestate keeps the patched code, so only a fresh-boot A/B can test
removing it).

## The jungle, measured properly: a submission bubble, not pixels (2026-10-15, DLSS off)

All numbers DLSS off (the rule from today: performance is always measured without DLSS / frame generation).
300 %, uncapped, `vrtest_uncharted_jungle`: **56 FPS** (17.9 ms), 100 %: 67.5. GPU 84 % busy at 300 %.

Nsight Systems (`tools/re/nsys_admin.ps1`, Vulkan GPU workloads + the new RSX wait counters in the frame stats):
per 18.2 ms frame the GPU is busy 15.5 ms and idle 3.4 ms in **one gap right after the flip**, during which the RSX
thread records the next frame's first ~1600 draws (2.6x its average recording rate) and only then submits: RPCS3
submits at ~5 flush points per frame, half of them at the flip. The RSX thread's 17.7 ms of CPU per frame were 7.5 ms
spinning on the game's FIFO, 1.3 ms in GPU fence waits and ~9 ms of work.

Fork `0f9415b7a` (branch `vr-pixel-savings`), `RPCS3_VR_EAGER_SUBMIT=256`: submit when the GPU has run dry and 256
draws are recorded (3.5 submits per frame). **300 %: 56.0 / 56.5 -> 64.5 / 64.2 FPS**, the frame now equal to the
GPU's busy time; FIFO spin 5 -> 1 ms. 100 %: 67.2 -> 69.7, now RSX-thread bound (14.2 ms CPU, waits under 1 ms).

So at 300 % the remaining limit is the GPU's 15.5 ms. Whether that is draw / vertex work or shading is the next
question (Nsight GPU metrics `GPUMET=10000`: SM active vs vertex / pixel warps); VRS and the hidden-area mask
(`11-vrs-plan.md`, `12-hidden-area-mask-plan.md`) only gained ~1 FPS, so it is probably not shading. At 100 % the
RSX thread (13.5 ms of work for 3450 draws, both eyes through multiview) is the ceiling.

### What the GPU's time is made of: Nsight GPU metrics (2026-10-15, eager submission on, DLSS off, 300 %)

`evidence/nsys/unc_jungle_gpumet` (not in git, 700 MB; `tools/re/nsys_admin.ps1` with `GPUMET=10000`). 62 FPS, 16.2 ms.
While the GPU is busy (GR Active 97.5 %), the shader cores are mostly idle: **SMs active 42 %, SM issue 15.6 %, pixel
warps 18 % of capacity, vertex warps 1 %, DRAM read / write 6 % / 5 %**. Over the whole frame GR Active is 74 %: about
4 ms a frame the GPU still waits for the RSX thread, in two mid-frame stretches (30-45 % and 70-80 % of the frame).
So the GPU is neither pixel- nor vertex-throughput bound: its time goes to the front end working through ~3,450 small
draws, ~700 pipeline binds, ~157 descriptor updates and ~120 pipeline barriers per frame. That is why VRS (+2 FPS
strong), the mask (+0.9) and resolution (100 % only +5 FPS) move it so little. Levers: fewer barriers (each drains the
pipe), less state churn per draw, fewer draws (the wider culling adds draws), and keeping the GPU fed mid-frame.

### The per-draw depth barrier: 63.6 -> 73 FPS (2026-10-15, fork `ae009c868`, branch `vr-pixel-savings`)

A dev barrier census (`RPCS3_VR_BARRIER_CENSUS=1`, fork `6d7e3242c`) counted ~43,500 pipeline barriers a second in the
jungle (~740 a frame), 74 % from `render_target::texture_barrier` called by `load_texture_env`: with **Emulate Special
Depth Comparison** (needed here) every draw of the EQUAL colour pass transitions the bound depth buffer for reading.
The skip for back-to-back read-only barriers worked only every other draw: `post_texture_barrier`'s read-only branch
reset the tracker including `allow_skip`. Keeping `allow_skip` (one line in `VKRenderTargets.cpp`) leaves ~13,900
barriers/s; **jungle 300 % DLSS-off uncapped 73.2 / 72.7 FPS** (eager submission on; was 63.6), picture unchanged.
Uncharted is the only game in the set with Special Depth Comparison on. Today's chain: 56 (start) -> 64 (eager) -> 73.

## Head aim on L1 (2026-10-15, fork e93ee4c, branch `ccr-90beb2ea-38jbn7`)

Matt: while L1 (aim) is held, the head should move the aim, as the right stick does, until L1 is let go. Profile
`"head_aim": { "button": "L1", ... }` and the VR setting *Head Aim* (Game section, live, on by default). Format and
mechanism: `profiles/README.md`, `head_aim`.

How it works: each frame the game camera is measured at the first scene-camera draw (its clip x, y and w axes). While
L1 is held, the pad thread sends the right stick in proportion to the angle between where the head looks and where the
game camera aims (0 under 0.75 degrees, 0.15 just past it, full at 10 degrees). The game camera's turn is folded into an
offset between the game camera and the shown view, so the world does not turn twice (once with the head, again when the
camera follows); the HUD box, crosshair included, stays on the game camera's forward. Mode `relative` (default): head
movement after the press moves the aim, as asked. Let go of L1: the view turns back onto the game camera at 120
degrees a second (if you are still looking to the side, the world turns by that much). The right stick still works
while aiming (big turns), and the head carries on from there.

Simulation (`tools/head_aim_sim.py`: 120 / 90 degrees a second at full stick, two frames of lag): a 20 degree head turn
and 10 degrees up converge in ~0.8 s with the shown view following the head alone; an inverted look axis is detected
(camera turning against the stick for 6 frames) and flipped once.

Not checked yet (no game or headset here, only a syntax build of the probe): that the first scene-camera draw is
Uncharted's main camera (a model-view block of a moving object would make the measured turn wrong), the game's stick
dead zone and turn rate in its aim mode (tune `min_stick`, `full_stick_deg`), and the HUD's crosshair on the aim. To
check in the headset: aim at a fixed point and turn the head; the world must not swim, and the crosshair must end
where you look. The log has "Head aim: on/off" and, every ~2 s while aiming, the error, stick and offset.
