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

## Head aim (branch `ccr-90beb2ea-38jbn7`, 2026-10-15 evening)

Hold L1 and the head moves the aim: the pad thread replaces the right stick with the head-to-aim error (fork
`e93ee4c9b`); `gain` added (`b3197ee21`, Uncharted 2.5, full stick at 5 degrees). Matt: *"when I move my head the
reticule moves slowly towards when I'm looking then stops when it gets there. Why is there a delay? It needs to move
faster instantly."* A stick-driven aim is limited by the game's own camera turn rate at full stick. Instant needs the
camera / aim angles written directly. Found so far: the camera matrix (right / up / forward rows, position in w) at
`0x92eb30`..`0x92eb7f`, written each frame by `0x154af0` (called from `0x164814` <- `0x1647fc` <- `0x8f818` <-
`0x4afd8`) from vectors, not angles (PPU interpreter store watch). Values that track the yaw exactly
(`0x3070364c` / `0x3078364c` in radians, offset from the matrix's yaw) are derived too: written back each frame. Next:
follow `0x164814`'s inputs to the orbit camera's yaw / pitch state, or find the stick turn-rate constant and scale it
while head aim drives.

**Direct camera, first try (fork `f1a482b45`), wrong.** It rotated the render camera's quaternion (cave after
`0x4c11f0` in `0x4b4b90`). The view turned in place (into scenery at 40 degrees, Drake out of view) and Drake kept
aiming along the game's own direction. Matt: *"when you aim straight ahead with the reticule, Nathan is looking about
45 degrees off to the right, he's not aiming where the reticule is."*

**Direct aim state (fork `df7e1fd7a`, patch "VR: Head aim (direct camera)" v3.0).** In aim mode (L1) the camera
that's drawn is the FOV-45 class (output `0x4d8870`, object `0x34c72000` in the jungle state), and its aim direction
persists from frame to frame at camera (normal controller, `0x34c70b00`) + `0x17a0` (copy at `0x34c72000+0x2a0`).
The right stick turns it through `bl 0x2b60e8` (`0x4d99f0` / `0x4d98f0`); `0x4d8cc4` resets it from two points. The
cave at `0x4d8b48` (`mr r3,r23`, per frame before `bl 0x4d7468` uses it) turns that vector by the change in running
totals the probe writes (degrees, yaw + left at `0x11eff10`, pitch + down at `0x11eff14`, applied totals at
`0x11eff18` / `0x11eff1c`, sin / cos by polynomial, pitch in the vector's vertical plane, skipped near vertical).
Simulator, jungle state, L1 held: head straight, yaw 20 right, yaw 15 left + pitch 10 up all log a head-to-aim error
of 0.00 degrees; the camera orbits Drake (he stays in frame) and the reticle sits on his gun's line.

How the state was found, since memory pokes misled for hours: most camera vectors are rebuilt every frame (pokes
vanish or never land), and the aim class `0x4c7b9c` (FOV 75, `0x34c38700`) and the normal orbit direction (+`0x12a0`,
pitch +`0x124c`, which do drive the camera outside aim mode) don't drive the aim camera. The test that worked: write a
20-degree-rotated copy of each candidate vector continuously for 0.8 s with PINE, and keep only the one that turns
`0xe9fa04` by exactly 20 degrees and stays turned.

## Shadow stripes with the wide fit, and a sharper shadow map (2026-10-16 evening)

The grid / comb pattern in the sun patches whenever the shadow-fit words (`0x7cdd88` / `8c`) are above 1: not depth
precision, not bias, not map resolution. Ruled out on the same stick turn from fresh loads of `BCUS98103_1_2`, words
fixed at 3.0 / 5.53 (`turnab.sh`, frames matched by content): 2x shadow map, D32F map, slope depth bias 2 and 20,
constant bias 3e5 (3e6 removed all shadows, so the bias did reach the hardware). Raw shadow-map dumps looked right.

The reader: the sun-shadow mask pass (vertex `fc15ec0752d20290`, fragment `135614811b7e2009`, unit 1 = the
2432x2432 shadow atlas, unit 3 = the 4-texel cascade scale/offset table). Its shader takes 4 `TEX2D_SHADOW` taps:
base UV minus a jitter `fract(wpos.yx * fc8.x) * fc19.x`, then + 2x that offset in x / y. `fc19.x` is a tap spacing in
shadow-map UV, so it is a fixed number of texels; over cascades the fit enlarged, a texel covers ~2.5x more ground
(bounding-sphere radius ratio sqrt((3 tx)^2 + (5.53 ty)^2) / sqrt(tx^2 + ty^2), tx = tan(46.7/2) x 16/9) and the
per-pixel jitter is visible as stripes. Fix in the profile: `fragment_constant_overrides` rule with `"fragment"` and
`"inverse_fit_words"` (constant 19 divided by that ratio from the live words). The 2x map (`boosted_targets`) stays
for crisper edges (frame rate unchanged, 66 vs 66 uncapped in the jungle state). Shadow Coverage default 100 %.

Shadow-map dump at fit 3 / 5.53 vs 1 / 1 (`evidence/uncharted/shadow-map-fit3-2026-10-16.png`): casters sit in a
diagonal strip of each cascade at fit 3 and fill the slice at fit 1. The strip is the headset frustum: the cascade is
a bounding sphere of the widened slice (bigger than the slice), and the game draws only the casters its own culling
(the Wider view words, the same 3 / 5.53) keeps. Not a bug. Dump decode: the two 2432x1216 targets are 7296x7296
D16/D32F raw (4 bytes a texel in the dump), each a pair of 1216-wide cascades side by side; the `RTDUMP` request file
is `%TEMP%\rpcs3-vrprofile\RTDUMP` (set by `launch.ps1`), one hex address a line.

## The rock at the wrong depth (2026-10-16 evening, fork `0957c4d57`)

Matt: the stacked flat slab behind Nathan (jungle, `BCUS98103_1_2`) stood far too far forward. Simulator shots at the
default pose, five head angles and five head positions all looked consistent at shot resolution (1 px = 3 headset px),
so the check that found it: dump both eyes' scene colour `c16d0000` and depth `c0f50000` (RTDUMP now writes the right
eye's multiview layer), block-match patches and fit disparity = a + b x depth (linear for parallel eyes and a
perspective depth buffer). The slab: +6.4 px off the line, the rest within 1 px (`scratchpad dispfit.py`, kept in the
evidence images).

Cause: c[0..3] is a per-object projection x view x model matrix. w-row length 1.0 for 2029 of 2557 depth-tested draws,
the rest 0.6 to 3.6 (scaled instances), 185 of them unevenly (x/w not the camera's 0.662). `eye_offset: "baseline"`
moved the eye by half the baseline times the x row's length, i.e. times the object's scale. Profile now
`baseline_per_w`, and the probe's per-w offset takes the projection's x scale cached from the last rigid block instead of
the draw's x/w ratio (which an uneven scale breaks). Generator updated to choose `baseline_per_w` for this pattern.

## Water reflections (2026-10-17, fork `aad83d8ec`)

Matt: reflections in the jungle river change wrongly with head turns. At yaw +20 the left eye's water had a bright grey
sheen the right eye lacked (water brightness L/R 1.41-1.70 in `c16d0000` dumps). Shadow fit, the water's forward pass
(`c9bf672b...`, cube-map reflection from c[20]) and the camera-position slot all left it; hiding vertex program
`292d56e8bfecaf63` (fragment `59c0ac681f999e51`, blended into `c16d0000`, samples ripple normal maps 0-3, `c31e0000` at
unit 12, `c07d0000` and `c16d0000`) made both eyes equal. Its shader: the reflected point r4 projected with fragment
constants 69 (u w), 73 (v w), 72 (w) and `TEX2D(12, (u, v))` into the half-resolution scene, a screen-space reflection
with the game's camera matrix. `c31e0000` cannot go to the game camera (the half-res scene also feeds the composite and
the bloom chain), so the rows are remapped per eye (`fragment_camera_rows`): the game's rows were not exactly S x the
draw's camera block (translation off, likely another frame's or the half-res camera), so the eye transform T, d is taken
from the camera block and applied as S T S^-1 F + S d.

## Whole grey beams (2026-10-17, fork `891ec5536`)

Matt's state `BCUS98103_1_7` (dark hall, scaffolding) still had whole beams grey after the projection snapping: 50523
hole pixels (`holes2.py`: normal `c07d0000` at its clear value 90,194,86,57 over depth `c0f50000` between 0 and
0xfffff0). A temporary per-draw log (eye, program, hash of the game's block and of the eye block, A, B) found 30 groups
where the same input matrix gave different outputs, only A, B and clip rows 0 / 1 differing: the depth pass
(`2fe8ebfb47d877be`) at A 0.2704 B 0.6045 and the normal pass (`f187605790940c88`, `8d089e5d4e908075`) at B 0.636, or
the other way round. Both are the beams' own blocks (non-rigid in the draw, so the cached projection was whatever the
previous rigid measurement left), and the measurements themselves came from beam blocks stretched along view axes,
which pass the orthogonality test. Fix: a rigid measurement is taken only if its aspect B / A is within 1 % of last
frame's dominant projection's; others are only counted, and a frame with none at the dominant aspect makes the most
counted off-aspect one dominant. After: 1 hole pixel at pose 0, 0 at yaw +-20 / +-40 / 90 / 180, pitch +-10 / +-15,
roll 15 (`g17test.sh` in the session scratchpad: load, `simpose.py`, RTDUMP of the three targets, `holes2.py`).

## Water reflections finished, judder, the grey river (2026-10-17 evening)

- The reflection pass (vp `292d56e8bfecaf63`, fp `59c0ac681f999e51`) reads a mirror render `c31e0000` (the scene drawn
  with the camera mirrored in the water, before the pass; RTDUMP `prog=292d56e8bfecaf63` dumps it as read: the
  end-of-frame dump shows the target's later reuse, a downsampled scene plus 72 light-shaft quads). Its lookup point is
  c65 (mirrored camera) + the reflected view ray (view vector from c52, the camera position); rows c69 / c73 / c72
  carry the mirror. Profile: rows + `from_camera` + `eye_position: 52`. Offline lookup check tools: `rk2.py`, `rk4.py`
  (session scratchpad), from FROWLOG rows and dumps.
- The river in `2_10` uses the same vertex program; a fallback water fp `ac6c346ebb880b87` (no mirror read) draws too.
  The beige river looking up was the water program missing RSX_SHADER_CONTROL_VR_FRAG_ROWS (fingerprint-cached
  control bits, fork `2b591ed79`).
- Scaled scenery judder (`1_9`): ~740 non-rigid camera draws a frame, error vs their own projection 0 still, up to
  0.7 % in a gentle sway; `scaled_camera_blocks` (197 of 198 solved per frame).
- Lighting pass `9fe5ec00ef1c6d6f` (vp `fc15ec0752d20290`): height fog from depth x (NDC x, NDC y, 1) and c13 (the
  up vector in that space: (A c13.x, B c13.y, c13.z) is unit). A per-eye remap changed brightness by 0.1 / 47: dropped.
