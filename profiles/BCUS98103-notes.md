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

Not checked: LOD with the wider projection (objects may pick lower detail models), the aim/zoom camera, cutscenes.
