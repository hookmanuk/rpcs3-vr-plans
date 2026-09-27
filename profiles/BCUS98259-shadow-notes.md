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

## 2026-09-25 (afternoon): holes, performance, world scale, HUD

- **Flashing holes / popping**: two separate causes.
  - At a one-vblank interval ("Frame rate follows Vblank Rate", same site as the PSN 60 FPS patch; the
    twin init 0x31f1b8 has no callers) the game drops objects for a frame whenever it misses its deadline.
    Community reports of flicker on the castle steps with the 60 FPS patch match. Fix: patch off; the
    profile's new `vblank_rate: 120` runs the game's own two-vblank frame at 60 FPS (`max_fps` 60).
  - SPU mesh trimming (`SPU-2801f277...`, same program as EU 1.01) drops small triangles sized for the
    PS3 resolution: missing stair/leg pieces at high resolution scales. Pappapatu's "Disable Mesh
    Trimming" copied for BCUS98259 01.00 (v1.1 to beat the community 1.0), on by default.
- **Depth readback**: the game copies its depth (c0c00000 -> 0x30800000) every frame and an SPU job
  (BP_MainCellSpursKernel3) reads it; RPCS3 made it wait for almost the whole stereo scene (6-7 ms at 600%).
  `occlusion_depth_readback` answers the read at once with far depth. Draw counts are unchanged (~1935 on
  the stairs either way; an earlier 195 vs 1700 comparison came from a run stuck in the pause menu), so
  what the job does with depth is unknown; no visible change in the headset.
- **Performance** (RTX 5090, desktop stereo, blur/bloom off): 400% holds 60; 90 FPS (180 Hz vblank) is
  limited by the main thread waiting on SPU jobs (~8 ms/frame: sys_event_flag_wait + usleep(5) polls in
  0x31b780 when the 256-byte job descriptor pool runs out). SPU Block Size Giga looked like 90 at 300%
  but that run was not in the shrine: unverified. Motion blur/bloom cost ~5 ms/frame at 600%; VR copies of
  the community disable patches are on by default. The Wider view patch changes a shared 1.0 constant
  (TOC-0x33cc, camera code 0xee438-0xee70c); frustum culling is separate from the depth readback (scale
  1.0: 965 -> 614 draws).
- **World scale**: the clip-space shear (0.0261 x 3.0) equals 64 mm only at the game's own projection
  (A 2.449); with Wider view 3.0 (A 0.267) it was ~0.6 m. New `stereo.eye_offset: "baseline"`: the eye
  offset is eye_baseline in world units from each matrix's clip-x row length.
- **HUD**: title/menu/font glyphs are vertex program f7969a024cd51baa (matrix-less, c[467]) drawn into the
  scene's final image, so `screen_space.hud_programs` boxes them. The menus depth test (GEQUAL, depth
  write) against full-screen layers; the fixed HUD box's w change broke that, fixed by vr_keep_depth in
  the vertex context (shader scales z by w'/w).
- A stuck dwm.exe (4.9 cores for 12 hours) degraded all measurements until restarted.
- Dev tools: RPCS3_VR_GPUPROF=1 (GPU ms and draws per target, RSX thread times, readback waits, flip
  waits), RPCS3_VR_GPUPROF_TARGET, RPCS3_SYSCALL_PROFILE=1; plans/tools/re/sotc_modes.ps1, perfrun.ps1,
  burst.sh, drawcounts.py.

## 2026-09-27: camera bounced into walls (Wider view patch 1.2, fork 1cb72c1f)

- Headset report: in a narrow gap the camera kept pushing into the rock and snapping back, with no input.
  Reproduced on Matt's savestate in desktop stereo; unchanged with the depth readback answered for real,
  at 60 FPS, and with VR rendering off, so not the renderer.
- Cause: the Wider view float 0x732894 (TOC-0x33cc, 1.0 -> 3.0) is read only in 0xee438-0xee710; in play
  only 0xee570 runs (read watch), feeding the main camera's FOV (0xee59c), a second 1-degree camera (+0x20)
  and a clamp. The main camera's FOV reaches the render view via 0xeea94 -> 0x1c218c (projection +0xc,
  getter 0x1c21c8). Getter readers: 0xeed68 (view info copy) and 0xea628, the camera framing: tan(fov/2) x
  distance to the target stored at +0x40/+0x44. With 150 degrees the framing logic moved the camera.
- Fix (patch 1.2): 0xea654/0xea674/0xea67c make that fov / Scale (0.5*pi/180 folded into pi/360 at
  TOC-0x6ee0); 0xee570/0xee574 (+5 other reads) give the second camera and clamp 1.0 from TOC-0x3398.
  Render projection unchanged (inspector c[60] 0.272/0.456 before and after). Proven on the savestate by
  poking the three words off (bounce, frame diffs 10-12) and on (still, ~3). Confirmed in the headset.
- Savestates keep their code: patches are not re-applied on load. New dev hook RPCS3_VR_POKE (data, or code
  under PPU Decoder: Interpreter (static)) tries a patch on a savestate; the read watch logs r3, r4, r24-r31.
  Scripts/data: scratch only (memdumps, ppcdis.py = ps3elf-style capstone listing with TOC floats).
