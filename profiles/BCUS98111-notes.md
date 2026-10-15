# God of War III (BCUS98111) - VR notes

Disc `God of War III (USA) (v02.00).iso` (APP_VER 01.00, VERSION 02.00), PPU hash
`PPU-4d5c51503a81a327c2a99427390a395b8dcb3767`. Decrypted ELF: `tools/re/elf/BCUS98111.elf` (`RPCS3_DUMP_ELF`). TOC
(r2) `0x52d6c8`. Community patches on (01.00): *Skip any videos with X button*, *Disable MLAA*, *Skip intro*. There is no
community frame-rate patch for 01.00.

Savestate `vrtest_gow3_gaia` (2026-10-14, mine: the opening fight on Gaia after New Game, Kratos among undead soldiers;
he dies within ~30 s without input). Saving fails at first with "HLE VDEC (video decoder) context(s) exist" (the intro
video); a few minutes into play it saves. 1.8 GB.

## Frame rate (OpenXR Simulator, 2880x2880 eyes, 300%, Vblank 60, 2026-10-14)

| | FPS | RSX thread |
|---|---|---|
| flat (render=0) | 46-48 | 19 ms/frame |
| stereo, no culling patch | 41-43 | 21-22 ms/frame |
| stereo, *Wider view* (scale ~6) | 27-31 | 23-24 ms/frame |

~3,400 draws a frame (68,564 in 20 sampled frames). Threads: three SPURS kernels at 100%, the RSX thread 88% (25% of
its samples waiting), PPU main thread 86%. RSX thread profile: `VKGSRenderVR::end` 46%, `emit_geometry` 30%, the texture
cache's temporary subresources created and destroyed every frame ~11% (`create_temporary_subresource` 5.5%,
`texture_cache::on_frame_end` freeing images 5.7%), VR per-draw work ~15% (`vr_setup_draw` 10.5%,
`bind_vr_eye_constants_pair` 7%). Below 72 flat already.

## VR profile (generated 2026-10-14, then hand-fixed)

The old experimental profile (`row_vectors` 256/260/0, `max_fps 36`, `bare_projection`) drew a white screen in the
headset. Generated in the Gaia fight: `row_vectors` `c[256]` (prepass and most scene draws), `linked_camera_blocks [260]`
(the colour pass reads `c[260..263]` only), near 0.25. Hand fixes: `c[0]` removed from `camera_blocks` (it smeared the
scene: not a camera); `screen_space.bare_projection [256]` removed (full-screen passes have the identity in `c[256]`, so
the composed frame was drawn again into the HUD box: the "inset"); `max_fps 0`.

Passes (one frame): depth prepass (target 0, `aecee6ec28b01fbe`/`5c035cb61b8cc4c5`, `c[256]`); half-res redraw
640x360 (`c3404000`); linear depth `c3aa0000` (X32 float, `e86e3ac4a0ebcbcb` from the depth buffer `c18e0000`); shadow
map 1408x1408 (`c2010000`); sun shadow mask into the light buffer `c2850000` (`41112a0418edd148`: hundreds of full-screen
triangles, fragment rebuilds the view position from the linear depth and `tc0.zw` = -NDC, then the light matrix in
fc2..fc5, shadow compare against the 1136x1042 part of the shadow map); local lights `9b51c5f6da78b8b3`; colour pass
`c11b0000` (`c[260]`) reading the light buffer; post `c0a8c000`, `c0384000`.

Open (stereo):
- **Large black areas**: the sun-shadow mask (`41112a0418edd148`) rebuilds positions for the game camera. Needs a
  depth remap for a *linear float* depth copy (the fork's remap handles Z24 depth and Z24-packed colour copies only).
- Vertical/horizontal bands at the eye edges (stretched edge pixels) once culling is widened: a pass still samples in
  the game's screen space. Not identified yet.
- HUD (health, combo counter) not in the HUD box (generator found no HUD block).

## Culling: "Wider view (VR culling)" (`bin/patches/BCUS98111_patch.yml`, 2026-10-14)

Camera object (heap, e.g. `0x321abb70`): view `+0x00`, view-projection `+0x40`, projection `+0xc0` (P00 1.9685, P11
3.4996, P22 -1.00005, P23 -1, P32 -0.500013: near 0.25, infinite far), screen matrices after. Its half-FOV tangents
(1/P00, 1/P11, ...) are copied each frame to `0x57b284` by `0x1c8c88` (read through TOC entries by the renderer and the
culling code). The projection is built at `0x239a34..0x239ccc` from the tangent vector stored at camera `+0x260` by
`0x239a8c` (`stvx v0, 0, r29`). The patch multiplies that vector by the scale word `0x68ff00` (slack between the end of
.bss at `0x68f8a0` and the heap at `0x690000`; patches can write it at boot). Profile `culling_scale_f32` (`fov_deg 28`,
`margin_deg 3`, `max 8`, `tangent`): ~6.2 straight ahead.

How it was found: memory search for the projection's tangents (`0x57b284`), a PPU interpreter write watch on it
(`0x1c8c88`), a trace of r31 there (the camera object), then a write watch on the projection (`0x239bb8`).

Game FOV changes with the camera (54 x 32 degrees here, 53.9 x 31.9 a moment later).

## 2026-10-15 overnight: working stereo and frame rate

### Profile fixes (in order found)

- **The ground vanished in stereo, replaced by the far sea:** the colour pass (`1cf30d408f10ea7f`, `80553a0f66bccea0`,
  ... into `c11b0000`) draws with depth func EQUAL (514) against the depth prepass, through `c[260..263]` holding the
  same matrix the prepass reads in `c[256..259]`. As a `linked_camera_blocks` entry `c[260]` got another transform
  than `c[256]`, so the EQUAL test failed. Fix: `camera_blocks [256, 260]`, no linked block.
- **Bands at the outer eye edges (a scaled copy), a diagonal cut in the right eye's corner, and in menus:** the final
  full-screen pass `fc50fa4f3cb724b2` (into `c0384000`) has `c[256]` = `[[1,0,0,0],[0,1,0,0],[0,0,1,1],[0,0,0,0]]`
  (w = z: a square perspective) and was taken as a camera draw. Fix: `require_camera_aspect: true` (the real camera is
  16:9). Found with probe `hide=` over the post passes (hiding it removed the bands).
- **HUD on the eye's corner:** `screen_space.orthographic_block 256` (the HUD ortho is 1/16, 1/9: a 32x18 screen) and
  the 3D health emblem `a87982423fedbeb4` (object matrix in `c[256]`, HUD ortho in `c[260]`; HUD phase only) in
  `hud_programs` with `passthrough_hud`.
- Community *Disable Motion Blur* and *Disable Depth of Field* (01.00): their passes rebuild screen positions with
  the game camera and smeared the view radially. They apply at boot only; `vrtest_gow3_gaia2` was made with them.

The sun-shadow mask (`41112a0418edd148`), which rebuilds view positions from the linear depth with game-camera
constants, looked right once the above were fixed (soldiers' shadows on the ground in both eyes); not checked for
sliding at head turns in a still frame.

### Culling patch v1.2: tangent floors per axis

The tangent vector the camera stores at `+0x260` (`0x239a8c`) holds tan x in lanes 0 and 1 (P00 = 1/lane 0; P11 comes
from lane 1 divided by the aspect). v1.0 multiplied all lanes by one scale (the larger of the two axes' needs, ~6.2 for
a 28-degree reference), widening x about twice as much as needed. v1.2: `vmaxfp v0, v0, [0x68ff00]`: lanes 0 and 1
take at least the words, which the profile writes as absolute tangents (x: `tangent_x`, `fov_deg 90`, `aspect 1`; y:
`tangent_y`, `fov_deg 58.7155` so the word is tan y x 1.7778). Straight ahead: x 1.51, y 2.77 (tan y 1.56).

| `vrtest_gow3_gaia`, stereo, 300%, VR 90 (simulator) | FPS |
|---|---|
| start of the night (v1.0 scale 6.2, two-layer copies) | 29.5 |
| + one-layer shadow-map copies (fork fd5631db8) | 34.5 |
| + separate x / y scales | 47 |
| + tangent floors (v1.2) | 52 (51.5-51.9) |
| no widening (black edges) | 74 (80 with RPCS3_VR_IMAGE_POOL_MB=14000) |

`vrtest_gow3_gaia2` (a busier fight): 42.5-42.9, 12% late.

### Where the time goes

- **Shadow-map part copies:** the light passes sample corners of many sizes of the 1408x1408 shadow map (`0xc2010000`,
  scaled to 2112x4224 by the eye shape) between cascade renders: ~300 texture-cache copies a frame (temporary log in
  `create_temporary_subresource_view_impl`, removed). They were two layers each; fork fd5631db8 makes copies of
  eye-invariant surfaces one layer. The pool still trims every frame (256 images / 4 GB): ~25% of the RSX thread
  creates and destroys them. Sampling the shadow map directly (upstream's clip path, as for clamp-to-edge textures)
  removed the copies (+14 FPS) but changed the shadows (the game's coordinates leave the corner and rely on wrap):
  reverted. A larger pool (count x4 + 14 GB) cut late frames 11% -> 3% at the same median: not kept.
- **Main thread:** 37% polling an SPU job (`usleep(30)` loop at `0x28da98`), 23% waiting for the RSX to drain its
  command buffer (`0x26d410`). Three SPURS kernels at 100%.
- **Wider view and the SPUs:** the game logs "BATCHJOB: AddJob: waiting for room in job list 3" (printed after a million
  polls at `0x2e5ca8`) with the view widened: the SPU job ring is full.

### Crash in the opening with the wider view

Fresh boot, New Game, the climb on Gaia: ~1:53 in, an access violation writing read-only memory at `0x22be6c` (after
`bl 0x20a550`: alloc 0x1808 bytes). The allocator (`0x20a440`) is a lock-free bump allocator without an overflow check
over two double-buffered 4.4 MB frame heaps (`0x466666`, set up at `0x26e9f8`/`0x26ea1c`, extents at `0x26ea48`/
`0x26ea80`). With the view widened more objects are drawn and the heap runs into the code below. Doubling the heaps
(0x8ccccc) or 1.25x (0x580000) faulted at boot (SPU access violation writing `0x3aa800`): something else depends on the
size. Patch removed. Without the wider view the opening runs. Not crashed in the Gaia fights (`gaia`, `gaia2`).

### Savestates

`vrtest_gow3_gaia` (MB/DOF on) and `vrtest_gow3_gaia2` (MB/DOF off, 2026-10-15). Saving fails while the intro video's
decoder is open; after a death and a checkpoint restart, a few minutes of play, it saves.

### Pause menu and HUD placement (2026-10-15)

The pause menu is a 3D casket drawn through a near-square menu camera (`c[256]` A 0.662, B 0.643): rejected by
`require_camera_aspect`, so it was drawn untransformed. `screen_frame_draws` `65b096c6ed0aba8c` with its 128x128
texture (the casket; in no gameplay capture) puts those frames on the fixed screen; the Power Up tip pages have no
camera draws and go there by themselves. **Matt's custom config for this game has `HUD Fixed In Front: false`** (from
the early experiments?): with it the HUD box and the fixed screen follow the head. With it on (checked with a session
override), the menu screen and the HUD stay world-fixed at yaw 25. Recommend setting it back to on.

Tried for frame rate, no gain (`gaia2`, two runs each): SPU Block Size Mega / Giga, SPU loop detection, SPU reservation
busy waiting, `camera_block_cache`. About one run in eight runs at half speed (RSX thread ~34 ms/frame) for its whole
window; not explained (VRAM 18 of 32 GB, no errors).
