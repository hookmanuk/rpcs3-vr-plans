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

## Open

1. Intermittent upside-down menu (above).
2. Cockpit and replay cameras and the garage not audited.
3. Optional 8 GB data install: the game asks at every boot; declined in tests (decline with Left, then X).

## Driving the game unattended

Temporary keyboard pad from `tools/keyboard-pad-template.yml`. Decline the install with Left then X; Return
skips the intro; Right then X = Arcade; X = Single Race, difficulty, High Speed Ring, Zonda R '09, colour, load;
one more X for the list page, another X starts the race (about 20 s to load). Hold W (R2) to accelerate.
