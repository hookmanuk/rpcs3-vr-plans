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

## Open issues (need the headset or code)

1. **Rear-view mirror content turns with the head** (looking up shows sky in the mirror). It is a
   sub-viewport draw in the main target, not an off-aspect target, so `game_camera_target_widths` cannot
   exclude it (tried 512, the 512x128 target is unrelated, no change). Needs a viewport-based rule in
   `rsx_camera_probe.cpp` (draws with a viewport smaller than the target keep the game camera).
2. **HUD in the headset box:** unverified. The desktop side-by-side view has no HUD box, so it cannot show
   the difference. If the HUD or menus fill the whole headset view, try `output_aspect_tolerance: 0.08` (so the
   2048x1080 final target counts as output aspect) plus `screen_space.orthographic_block: 0`. That loads and
   runs on the desktop (audit unchanged) but is not validated against the headset.
3. Cockpit and replay cameras, menus and the garage were not audited.
4. Optional 8 GB data install: the game asks at every boot; declined in tests (decline with Left, then X).
5. Earlier freezes at boot disappeared after Matt changed his settings; the cause was not identified.

## Driving the game unattended

Temporary keyboard pad from `tools/keyboard-pad-template.yml`. Decline the install with Left then X; Return
skips the intro; Right then X = Arcade; X = Single Race, difficulty, High Speed Ring, Zonda R '09, colour, load;
one more X for the list page, another X starts the race (about 20 s to load). Hold W (R2) to accelerate.
