# Ratchet & Clank Collection (BCUS98282, disc 01.00)

Added 2026-09-30. Profile `bin/vr_profiles/BCUS98282.json` (generated in Ratchet & Clank 1 on Veldin; frame-rate
fields edited). Copy in `rpcs3/vr-non-working/`. No patch. Only **Ratchet & Clank 1** was tried; R&C 2 (Going
Commando) and 3 (Up Your Arsenal) share the title ID and the profile but were not booted.

## Boot

The first boot asks (RPCS3 dialog) whether to install the disc's Digital Manual package: skip it (Escape). ~370 PPU
modules compile (~3 min). Logos, then the collection menu (R&C 1 selected: X), the R&C 1 title (Start), New Game,
a save slot, and three skippable opening cutscenes (Start) reach Veldin. `tools/re/rc_boot.ps1` does all of it.

## Frame rate (100%)

| | FPS |
|---|---|
| flat, vblank 60 | 60 |
| flat, vblank 90 | 90 (Veldin; RSX thread ~61%) |
| stereo desktop, vblank 90 | 75-80 (4,600 draws a frame, 10 right-eye batches) |

**Frame-locked.** At vblank 90 the integer frame counters run 1.5x (57 -> 86 per second) and Ratchet walks 17.9
units in a 2 s hold instead of 12.3 at 60: the game runs 1.5x fast. Four f32 1/60 constants in data
(`0x770304`, `0x770314`, `0x112c078`, `0x112c080`) set to 1/90 with `RPCS3_VR_POKE` brought the walk to 12.9 units
(real time), but other motion was not verified (a standing-still comparison was inconclusive). So the profile runs
the game at its native **60** (`max_fps 60`, `default_fps 60`) and the headset reprojects. A 90 FPS patch is the
lead for later: start from those four constants and check animation, enemies and timers.

## VR profile (generated)

`column_vectors`, camera `c[0]` (100% of depth-tested draws), HUD `c[4]`, near plane 0.1 -> metres, `eye_baseline`
0.064. Stereo and the yaw-25 audit on the title and in gameplay are clean.

## 2026-10-01: R&C 1 at the headset rate (desktop)

- **Timing:** R&C 1 (`RC1.ppu.self`, PPU-3de6ba93...) keeps constant frame times in data: block `0x770300` =
  {1.0, 1/60, 1/3600, 1/216000, 5, 1/60} (never written at run time; read by dozens of systems, found with a PPU read
  watch under the interpreter) plus 1/60 at `0x112c078`, `0x112c080` (bss). Executable profile
  `bin/vr_profiles/BCUS98282.rc1.ppu.json` drives them: `game_frame_time_f32` [0x770304, 0x770314, 0x112c078,
  0x112c080], new keys `game_frame_time_sq_f32` [0x770308] and `game_frame_time_cube_f32` [0x77030c]; `max_fps 0`.
  No patch needed.
- **Verified:** Ratchet's run speed (position `0x95db10`, per-frame `RPCS3_VR_PEEK`, `tools/re/rc_phys.sh`): 60 FPS
  6.10 u/s, 90 unpatched 9.22, 90 with the frame-time values 6.27. Scaling the leading 1.0 (`0x770300`) changed
  nothing measurable. Not verified: animation, enemies, jump arcs (the HelpDesk pop-ups eat scripted X presses).
- **Stereo frame rate:** 75-80 at Vblank 90 on Veldin (RSX thread ~5 ms of 13 ms per frame; the limit is elsewhere,
  not yet profiled).
- **Pause menu:** new profile key `screen_space.boxed_camera_programs` (`ef49d731f4b4551b`, `d032c3b0051293db`) is
  meant to put the 3D menu panels into the HUD box. Tested with the new desktop fake headset (`RPCS3_VR_FAKE_HMD=100`,
  `launch.ps1 -FakeHmd 100`): the head transform works in gameplay (wobble), but the pause-menu frames are not
  boxed and get no head motion. Unresolved.
- Boot crash at the executable switch (`vk::swapchain_WSI::init`), 1 in ~10 boots; retry.

## 2026-10-01: R&C 2 and R&C 3

Each game of the collection is its own executable, so each has an executable profile next to R&C 1's:

| | executable | timing block (1.0, 1/60, 1/3600, 1/216000, 5, 1/60) | Ratchet's position | run speed 60 / 90 raw / 90 with profile |
|---|---|---|---|---|
| R&C 1 | `RC1.ppu.self` | `0x770300` (+ bss `0x112c078`, `0x112c080`) | `0x95db10` | 6.10 / 9.22 / 6.27 u/s |
| R&C 2 | `RC2.ppu.self` (`PPU-8f729e90...`) | `0x1329038`: profile writes `0x1329040`, `0x1329050`, sq `0x1329044`, cube `0x1329048` | `0x1425790` | p50 5.9 / 8.8 / 5.9 |
| R&C 3 | `RC3.ppu.self` (`PPU-56a8d02d...`) | `0xc1de68`: `0xc1de6c`, `0xc1de7c`, sq `0xc1de70`, cube `0xc1de74` | `0xd05e60` | p50 6.1 / 9.0 / 6.2 |

(A second copy of the block's first three values sits in rodata in each, `0xb8744c` / `0x217830`: left alone.)
`tools/re/rc2_phys.sh`, `rc3_phys.sh` (savestates `rc2_aranos`, `rc3_veldin` in `bin/savestates/BCUS98282/`).

- **Stereo layout:** the generator in R&C 2 gives the same profile as R&C 1 (`column_vectors c[0]`, HUD `c[4]`,
  near 0.1 m). R&C 3 uses the same. Yaw-25 audits on Aranos (R&C 2) and Veldin (R&C 3) are coherent.
- **HUD in the headset view:** the HUD sprites (`007f5efab1d12ef7`) are matrix-less and drawn into the scene target,
  so they stayed full-size at the screen edge. All three executable profiles now have `passthrough_hud` +
  `hud_programs ["007f5efab1d12ef7"]` (checked boxed in R&C 2; classified as HUD in R&C 1 and 3).
- **Stereo frame rate (all three): 75-85 at Vblank 90.** GPU profile (`RPCS3_VR_GPUPROF=1`, R&C 3 Veldin battle):
  GPU work ~2 ms/frame, RSX thread busy 4.2 of 12.3 ms between flips (setup 1.5, vertex 1.1, textures 0.9, draw
  0.7), no hard syncs, no thread saturated, GPU at 36% in P5. So the game's CPU work and the RSX work appear to run
  in series (the game waits for the RSX before starting the next frame): flat (~2.5 ms RSX) fits in 11.1 ms, stereo
  does not, and frames miss a vblank. Lead: cut the RSX thread's per-draw cost in stereo (3,300 draws, 19 right-eye
  batches), or find the game's wait (a label poll) and check whether it can run a frame ahead.

## 2026-10-01: why stereo misses 90 (R&C 3 Veldin battle)

- Flat uncapped (Vblank 180): **150-164 FPS**. Stereo uncapped: 85-94. GPU ~14% busy (nvidia-smi), Multithreaded
  RSX no help.
- `RPCS3_PPU_SAMPLE` + `RPCS3_USLEEP_STATS`: in stereo the main thread spends **87%** of its time in a 50 us
  `sys_timer_usleep` loop at `0x96f1a8` (RC3.self) waiting until `[[0x15c6528]+8]` = the GCM control register's
  **ref** (`0x50100048`) reaches a value it set: it waits for the RSX to process its command buffer up to a
  reference, i.e. the frame is fully serial (game work, then RSX work). So the frame time is game time + RSX
  thread time, and the RSX thread's stereo cost (the right-eye replay; the GPU profile's per-category RSX times
  miss part of it, the RSX thread is ~53% of a core) pushes it past 11.1 ms. A real fix is cheaper right-eye
  submission on the RSX thread (multiview, the standing plan item), not a game patch.
- New GPU-profile fields (fork): RSX thread CPU time per frame and the VR share. R&C 3 Veldin, uncapped: flat
  RSX thread CPU **5.1 ms** of a 6.35 ms frame (the RSX thread is the bottleneck even flat); stereo **8.2 ms** of
  11.2: left-eye constants 1.9 ms + right-eye replay 2.7 ms for ~3,300 draws. Inside the eye-constant binding
  (both eyes): fill 0.23, camera classification/transform 1.76, ring upload + descriptor 0.87 ms. Getting under
  11.1 ms needs ~0.5-1 ms off the RSX thread: reuse the left eye's classification for the right eye, one upload
  for both eyes, or multiview.

## 2026-10-01: at 72 Hz, 4K per eye (pass mark 72)

- Regression states `vrtest_rc1_veldin`, `vrtest_rc2_aranos`, `vrtest_rc3_veldin_battle` (`tools/re/vrtest_states.txt`).
  At Vblank 72, 300%, walking: R&C 1 averages 66.7 (1.7% late frames), R&C 3 70.3 (frames that miss present at
  ~20 ms): neither sustains 72. R&C 2's state is a light interior (120). Uncapped R&C 3 averages ~105 but its frame
  times vary too much to hold a fixed 72.
- **Frame-counted camera behaviour (R&C 3):** standing still, the camera tips down toward Ratchet after a delay that
  shortens with the frame rate (within 0.5 s at 240 FPS, >14 s at 72), so some idle/camera timer counts frames, not
  time. Not fixed; it only matters when idle.

## Open

- **Pause menu:** its button frames are 3D panels drawn with their own perspective camera (`ef49d731f4b4551b`,
  `d032c3b0051293db`; `c[0..3]`, clip w = x - 256) over a still of the scene. They pass as camera draws and turn with
  the head while the text stays in the HUD box (`evidence/ratchet/pause-menu-audit-yaw25.png`). Needs a way to put a
  program's camera draws into the HUD box (the GT5 mechanisms need `hud_box_after_shader`).
- 90 FPS patch (above); headset run.

## 2026-10-01: RSX-thread optimisation (all three now hold 72 at 4K per eye)

- Cycle-exact RSX thread CPU per frame at 72 Hz (`RPCS3_VR_FRAMESTATS`; the old GPUPROF field used GetThreadTimes
  and undercounted by more than half): R&C 1 **13.2 ms** in stereo (66.8 FPS) vs 7.2 ms flat, R&C 3 12.2 ms. The
  RSX thread was the bottleneck, not the serial game/RSX wait alone.
- Fixed in the renderer (A/B with `tools/re/vr_ab.sh`, `evidence/vrperf/`): camera-slot lookup by binary search
  (an 8-entry table cache thrashed: ~5%); the right eye's attachment list no longer reallocated per draw; the eye
  constants' CPU scratch filled with ordinary stores (streaming stores, then read back by the classification:
  ~13%); the vertex-program hash cached for the per-draw VR checks.
- Result: R&C 1 **10.7 ms, 71.4-72.0 FPS, 0% late**; R&C 3 **9.2 ms, 72.0 FPS**. R&C 1 stays the tightest.
- R&C 2: the hangar state is 543 draws/frame (2 ms RSX). Matt made `vrtest_rc2_aranos_hall` (Aranos machinery hall,
  606 draws, 5.9 ms): sustained **120 Hz**. Outdoor R&C 2 levels (Oozla onwards) are not measured.
