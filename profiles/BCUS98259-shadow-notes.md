# Shadow of the Colossus (BCUS98259 v01.00, ICO & Shadow of the Colossus Collection) - findings

`Shadow.self` PPU hash `PPU-07500788ed015ad425938fbde3b857487b38397b`, TOC `0x735c60`. Runs under the same
title ID as ICO, so its VR profile is executable-specific: `bin/vr_profiles/BCUS98259.shadow.json`
(the loader tries `<TITLE_ID>.<executable>.json` first, then `<TITLE_ID>.json`; the collection menu is
`eboot`, ICO `ico`). Patches: `bin/patches/BCUS98259_patch.yml` under the SotC hash.

## VR profile (2026-09-25, desktop-verified)

- Inspector survey in the shrine: camera `c[60..63]` bare projection (`column_vectors`, A 2.449, B 4.105:
  a narrow 44 x 28 degree view), a second full view-projection block `c[64..67]` (programs a8f73076,
  6755771e, 891711ef). Near plane 0.05 -> metres, `eye_baseline` 0.064. No camera position slot, no HUD
  block in gameplay; the "Press to jump" prompt is matrix-less (program 1c908c85, c[467]) into a
  post-composite buffer, so `passthrough_hud` should box it in the headset (not verifiable on the desktop).
- Rotation audit: yaw 25/40 and pitch 35 consistent; the only gaps are beyond the widened game frustum.

## Frame rate: 90 FPS at real-time speed

- Same Bluepoint framework as ICO: vblank handler `0x319ba4`, frame time `device+0x138` =
  (interval `+0x384` - countdown `+0x378`) / refresh float at `0x736be8` (60.0, TOC+0xf88).
- Interval 2 set at two init sites (`li r9,2` at `0x31eea4` and `0x31f654`; the second is where the
  community PSN "60 FPS" patch changes a byte, 0x20 later there). Patch "Frame rate follows Vblank Rate":
  both `li r9,1`. The profile writes the effective vblank rate to `0x736be8` every frame
  (`game_refresh_rate_f32`), `max_fps` 0.
- Measured with Vblank 90 (no headset): 90 FPS; game clocks found by `memclock.py` over four dumps run at
  1.0x wall time. Unlike ICO, the game logic uses the frame time.

## Wider view

- The community Extended FOV float at `0x732894` (1.0) is the lever: at 3.0 the logged projection A goes
  2.449 -> 0.267 (about 150 x 132 degrees). Without it, the headset remap showed the game's small view
  in the middle of bright fog. On by default at 3.0 (options 1.0-4.0).

## Full Pixel Mode

- Off = 1216x684 with an overscan zoom: `tools/rotation_audit.py --fit-scale` measured k = 1.19. On =
  1280x720, k = 1.00.
- Option 0x11 in the option table (`0x10f644` read, `0x10f630` write; the saved value lives at
  `0x14db27c`). Boot reads it at `0x71568` and passes it to the mode setter `0x1e9ca0` -> `0x33b65c`
  (object `[TOC+0x124c]`: +4 mode, +8 changed); the per-frame consumer `0x33be30` then sets the display
  mode at `[TOC+0x125c]+0x60` (1 overscan, 2 full pixel) and calls the resize callback. The settings copy
  is `0x14d5dd8+0x48` (TOC-0x6568; written at `0x705cc` boot and `0x73340` options, read by the apply
  routine `0x7069c`). Found with a memory diff and `RPCS3_PPU_WATCH`.
- Forcing the leaf setter or the `+0x60` readers did not change the render size; making the option read
  as on did. Patch "Full Pixel Mode always on": `li r3,1` at `0x71568` (boot), `0x70488` (settings copy),
  `0x706bc` (apply) and `0x73324` (options toggle). Verified: 1280x720 after trying to switch it off in
  the menu, k = 1.00. Not separately verified with a save that has it off (the session's earlier toggle
  may have saved it on). The failed attempts are kept in `sotc-fullpixel-attempt.yml.txt`.

## Open

- Headset: HUD prompts in the HUD box, world scale, comfort at 90.
- Motion blur / bloom at 90 FPS (community patches exist to disable them if they smear in stereo).
