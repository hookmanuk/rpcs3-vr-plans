# Ridge Racer 7 (BCAS20001 v01.00, Asia, En/Ja) - findings

`EBOOT` PPU hash `PPU-de2b587bf99874b3fe390329ef4f18150e4f853f`. Profile `bin/vr_profiles/BCAS20001.json` is the
in-emulator generator's output, unedited (2026-09-25). Not yet checked in the headset (SteamVR was off).

## Rendering

- Camera `c[4]` (row_vectors), covering 97% of depth-tested scene draws; a second block `c[0]` (10 draws,
  a camera-space banner such as the countdown) gives `bare_projection`.
- The scene renders at **1408x768** into `0xc0880000`, is composited to 1280x720 (`0x50110000`), and the
  race HUD is then drawn back into `0xc0880000` at 1280x720.
- **HUD**: program `f78118c010d9eba2`, matrix-less (reads only `c[467]`, positions already in screen space),
  no depth test, 6-vertex quads, ~75 per frame. Generator: `passthrough_hud` + `hud_programs`.
- **Units are metres**: the player car's body puts the camera at (0, 1.97, 5.74) in car space (chase camera
  5.7 m back, 2 m up) and its wheels at x = +-0.8 (1.6 m track). Near plane 0.3. `eye_baseline` 0.064.

## Frame rate

- Native 60 FPS, one frame per vblank.
- **The simulation is frame-locked**: at a 90 Hz vblank the lap timer ran 1.49x wall time (24.48 s of game
  time in 16.41 s), and the lap timer counts frames (1:55.450 = 6927 frames at 1/60). Patching all 21 static
  1/60 floats in the data segment (0x4af520..0x4d767c) to 1/90 changed nothing (still 1.49x): the step is not
  one constant. Real 90 FPS would need the physics and logic re-timed; not attempted.
- So the profile keeps `max_fps 60`: in the headset the game renders at 60 and the headset reprojects to its
  own rate (90 Hz head tracking), as for ICO at 30.

## Benchmark (desktop stereo, Resolution Scale 300%, RTX 5090, 2026-09-25)

| Vblank | FPS (mean / min) | Notes |
|---|---|---|
| 90 | 88.5-89.5 / 82 | holds 90 |
| 144 | 139.8 / 114 (load) | 7.0 ms/frame between flips; RSX thread busy 0.6 ms; ~310 draws; no readback stalls |

Stereo at 3x resolution has ample headroom for 90; no performance work needed.

## Open

- **Screenshot crash in a headset session without a profile**: on first boot (no profile) with SteamVR
  running, the screenshot hook crashed the NVIDIA driver (`nvoglv64.dll`, access violation) and then hit
  `ensure(current_queue_family ...)` in `vk::image::push_layout` (`image.cpp:227`) during the screenshot.
  Fine with `-NoHeadset` and with a profile and no headset session. Suspect the OpenXR publish path leaving
  the display image owned by another queue family (the XR queue) before the screenshot copy.
- Headset check: HUD box, `bare_projection` banner, world scale, menus.
- Boot script used for tests: title -> Start x several (logos, Xevious loader, attract) -> Arcade (Down x3) ->
  Single Race -> Rave City Riverfront -> Normal -> machine -> Start Race.
