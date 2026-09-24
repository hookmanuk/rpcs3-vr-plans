# ICO (BCUS98259 v01.00, ICO & Shadow of the Colossus Collection) - findings

`ICO.self` PPU hash `PPU-9a604c56796a32bf86ff037b682b0a744eb6a0dd`, TOC base `0x4cfeb0`. The disc boots a
collection launcher first (`PPU-2d008284...`); ICO.self loads after picking ICO. Patches are not applied
when a savestate is restored, so test patches from a fresh boot.

## VR profile (2026-09-23)

`rpcs3/bin/vr_profiles/BCUS98259.json`.

- Camera block `c[60..63]`, `column_vectors`. It is a bare projection (the view is applied in other
  constants): rows `(1.386,0,0,0) (0,-2.464,0,0) (0,0,-7.6e-6,2.0) (0,0,1,0)`. Both layouts pass the camera
  test equally; the generator now breaks the tie by the w row's unit length.
- No camera position (a bare projection's eye point is the origin; c[3] matched only as a (0,0,0,1)
  constant and moving it per eye corrupted shaders). No HUD block found.
- 3D renders to a 1216x688 target (`0xc1410000`), not the 1280x720 output; the final draw (#197) scales
  `0xc1e60000` onto the display buffer `0xc0840000`.
- Renderer fixes needed (`VKGSRender::vr_mirror_blit`): the frame is bounced through main memory
  (`0xc1410000/0xc1780000 -> 0x30900000 -> 0xc1e60000/0xc1af0000`, 1024+192 columns) for SPU MLAA, and the
  depth buffer is halved by a scaled blit (`0xc0f70000 -> 0xc12e0000`). Both are now mirrored for the
  right eye.
- Enable the community patch "Disable MLAA": with MLAA the left eye comes back from the SPUs at native
  1216x688 (resolution scaling lost), the right eye does not.

## Frame rate (open)

- Device object `*(*(TOC-0x3a40))`. Vblank handler `0x16e5c0` -> `0x16e4cc`: counts down `+0x378`; on flip,
  frame time `+0x138` = (`+0x384` interval - countdown) / 60.0 (float at `0x4cc47c`), then
  `cellGcmSetFlipImmediate`. Interval `+0x384` = 2, set at `0x171a70`/`0x172250`.
- Patch `BCUS98259-patch.yml` (interval 1 at `0x16e580`/`0x16e5b4`, refresh float at `0x4cc47c`) gives
  90 FPS at Vblank 90 but the game runs 3x fast: the frame time at `+0x138` does not drive game speed.
  Installed but disabled.
- Game logic is PS2 threads emulated on fibers. Actors call `WaitFrames(n)` (`0x10e6a0`), which calls
  `SleepThread` (`0xa7b44`, via `0x15cccc`) n times; thread table at `*(TOC-0x61a0)+8`, 256 x 0x58.
- The emulated vsync thread (`0x27c80` loop in `0x27bcc`) counts vsyncs and every `[0x4d1dd8+4]` (= 2)
  starts a game frame (wakes `+0x610c`), and wakes threads at `+0x617c`, `+0x61ec` (thread 6) and
  `+0x625c`. `0x4d1dd8` is a global system struct referenced from ~85 TOC slots.
- Main draw loop `0xd4d4c` (13 display-list kicks through GS register writes `0x315b4`), then
  `0xcedec` -> end of frame `0x44810` -> present `0x16fba4`/`0x16fa1c`.

Dev hooks added for this (environment variables):
- `RPCS3_DUMP_ELF=<path>`: write the decrypted executable at boot (disassemble with capstone, PPC64 BE).
- `RPCS3_CALLSTACK_AT=<hex>`: log the call stack of every 30th `sys_timer_usleep` made from that address.
- `RPCS3_PPU_TRACE=<hex>,<hex>,...`: trace breakpoints that log each distinct call stack and continue.
  Needs `PPU Decoder: Interpreter (static)` in the game's config.

## Headset session (2026-09-24)

- **Units are centimetres**, not metres: Ico stands ~1073 units from the camera and fills ~17% of the
  image height (vertical tan 0.406), i.e. ~152 units tall; the near plane is 2 units. `eye_baseline` is
  now 6.4 (was 0.064), which scales head translation 100x (leaning moved the camera 1 mm, so SteamVR
  shifted the image and the next frame snapped it back).
- **Full pixel mode must be on for VR** (now forced by the patch "Full Pixel Mode always on", see below). With it off, the final image is zoomed ~16%
  against the game's projection (an overscan zoom), so the world swims on head turns. Measured with the
  audit through the headset remap: `rotation_audit.py --fit-scale` k = 1.17 off, 1.00 on. The 3D draws'
  viewport is normal (1.0, logged); an earlier guess of a 1360x768 viewport was wrong (the ratio
  matched by coincidence). `camera_probe::undo_viewport` stays: it compensates games that do set a
  non-standard viewport and is a no-op here.
- **Pipeline** (inspector capture of a gameplay frame): scene double-buffered in 0xc1410000/0xc1780000
  (each frame draws one, composites the other); stencil shadow volumes of people/doors into a half-res
  depth 0xc12e0000 (draws 176-182), mask to 0xc2f91000 (183), blurred via 0xc2a80000 (184-185),
  multiplied onto the scene (186); a previous-frame scene blend (191) and glow chain.
- Profile options added for it: `current_frame_copies` (copy this frame's scene, not last frame's) and
  `screen_space.passthrough_hud` (pause menu draws 199-203: matrix-less quads with 1024x512 UI atlases
  into the finished frame 0xc1af0000).
- Renderer work this surfaced (generic): per-frame pose ids and pose stamps on render targets
  (declared pose = the displayed buffer's), feedback reads of older-pose full-screen targets re-projected
  per pixel (homography in a spare TIU slot), passes with no traced inputs stamp their output current.

## Culling / wider view (2026-09-24)

The game culls to its own camera frustum (70-90 degrees wide, 44 tall), so in the headset whole objects
are missing outside the TV frame (skybox or black showing through).

- ICO.self keeps the PS2 SDK camera model: camera setup `0xd364c` computes the screen distance `scrz`
  (param block `[TOC-0x583c]+0x1c`, stored at `0xd37a8`/`0xd37e8`) as `... / 640.0 / 100 / 100`
  (640.0 at `0x4ca6d0`, TOC slot -0x57e0, read only at `0xd3730`). `0xd3174` (called twice) builds the
  view-screen matrix, the view-clip matrix used for culling (`sceVu0ViewClipMatrix`-style, x/y scale
  from `scrz`) and the RSX projection at `0xc7e580`, which `0x30c1c` copies into the per-display-list
  matrices (first at `0x7018e0`, stride 0x90; the loop at `0xd49c0` covers 13 lists).
- Patch "Wider view (VR culling)" (`BCUS98259-patch.yml`, in `bin/patches/BCUS98259_patch.yml`, enabled at
  3.0): raises the 640.0 divisor, so `scrz` shrinks and tan(FOV/2) grows by the chosen factor in both
  axes, for rendering and culling alike. The VR renderer remaps from the measured game projection, so the
  headset image keeps its scale (without VR the TV picture becomes a wide-angle view).
  Verified: projection `A` 1.3858 -> 0.4619 at 3.0; yaw-40 audit through a 90-degree frustum shows a wall
  section that is black without the patch (`plans/evidence/ico/wider-view-yaw40-before-after.png`).
  Frame rate unchanged at 30 in the cage hall (100% scale). At 3.0 the game frustum is ~130 x 101 degrees.
- The projection's far plane is 262144 (`0x4ca6f0`, near 2), so depth is not what limits draw distance;
  any distance pop-in comes from per-object culling or LOD, not found yet.
- **Correction:** the "camera records" (fov/cot/tan/aspect/near/far, 70 degrees, far 15000) found in
  `dump/MEM.3` belong to Shadow of the Colossus (that dump's code ends at 0xf00000; ICO.self's at
  0x14f0000). ICO has no such record.

Dev tools added: `RPCS3_PPU_WATCH=<addr>,<len>,<code start>,<code end>[,<gate addr>,<gate word>]` logs
each store instruction that writes a range (PPU interpreter only; ICO gate `16e580,801f0384` waits for
ICO.self behind the launcher). `plans/tools/re/ico_boot.ps1` boots to New Game with the key hook,
`ico_ab.sh SCALE OUT` runs the yaw audit at a patch value, `ico_scale.py` sets the value.
Savestates do not work for ICO: boot fresh.
- 2026-09-24 headset: at 3.0 culling still showed looking up and down (the game's vertical FOV is the
  narrow one). Options up to 40.0 added (20.0: ~176 x 166 degrees in gameplay); set to 20.0 for a test.
  A frustum cannot cover directions more than 90 degrees from the game camera's forward axis, so
  if the gaps remain, the next step is to disable the cull test itself (the code reading the view-clip matrix).

## Flames (pre-projected sprites), 2026-09-24

Torch and stick flames were drawn away from their source (on a wall instead of the stick tip). They use
vertex program `46c0e502317ab819` (12 draws per frame into the scene, constants c11, c17, c467 only):
`pos = in_pos.xyz, w = c467.x (1)`, i.e. the CPU already projected them into the game's NDC (PS2 GS-style
sprites); the program also derives a scene-depth UV and linear depth from `in_pos` (soft particles).
The VR renderer rotates and remaps camera draws, not these, so with the x20 wider view the offset was large.

Fix (generic, renderer): profile `screen_space.preprojected_programs` lists such programs by ucode hash.
Each eye's latest camera block is cached as the game wrote it (B) and as drawn for that eye (B_eye);
a listed program's draw gets `B^-1 * B_eye` in its vertex context's viewport matrix (the HUD-box
mechanism), which maps a game clip-space point to the eye's exactly, head position and eye offset
included. Confirmed in the headset. Known limit: the soft-particle depth lookup still uses the game-view
UV. Evidence: `plans/evidence/ico/flames-before.png`, `flames-preprojected-fixed.png`.
- The first build also sent non-depth-tested / non-scene draws of that program through the eye transform;
  with the lit stick in hand the pause menu then showed doubled at two sizes, flashing. Now only draws with
  depth test into a camera target take it (`VKDraw.cpp`, log line "VR: pre-projected program ... ->"
  records each distinct target/depth/HUD case). Menu confirmed fine in the headset afterwards.

## Full Pixel Mode forced on (2026-09-24)

Found by diffing memory dumps with the option OFF / ON / OFF. The options menu flag is `0x4d1dd8+0x38`
(toggled at `0x21008`, shown at `0x20d38`, loaded from the save at `0x14e190`); both then call `0x329c0` ->
setter `0x18ec48`, which writes the requested mode to object `0xc34270`+0x10. The per-frame check at
`0x18eca0` applies it when it differs from +0x14 (applied). Patch "Full Pixel Mode always on" makes that
check and the getter (`0x18ec58`) read 1 and the menu show ON. Verified on a fresh boot with a save that
has it OFF: requested 0, applied 1. The old advice to switch it on by hand is no longer needed.
