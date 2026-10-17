# Midnight Club: Los Angeles Complete Edition (BLUS30442, disc 01.06)

Started 2026-10-17. **Stopped at step 1: stereo below 72 FPS** (see the end). Files: `bin/vr_profiles/BLUS30442.json`,
`bin/patches/BLUS30442_patch.yml` (tracked copies in `rpcs3/vr-non-working/`). PPU hash
`PPU-9d8f7464991444526c6f9ca001dc1eb061fe367b`.

## Setup

- Community patches (`patch.yml`, Complete Edition disc 01.06): **Enable Deltatime** (runs at any frame rate at the
  right speed; raise the vblank for more than 30) and **Disable Motion Blur** (the blur smeared the whole picture in
  stereo). Both enabled in `config/patch_config.yml`. A savestate keeps the code it was made with: the state below was
  made after enabling both (an earlier one without the blur patch was deleted).
- Savestate `bin/savestates/BLUS30442/mc_freeroam.SAVESTAT.zst`: free roam in Hollywood, parked on a pavement, made
  from a disc boot (title, Start, autosave). 2.1 GB. The new save game it created is the only one for this game.
- Controls on the keyboard pad: throttle is the **right stick up** (`T`), reverse right stick down (`G`); R2 (`W`)
  turns the camera; Up opens the map. After a few seconds without input the game switches to an idle camera
  (pavement-level shots), so tests must keep driving.

## Frame rate (DLSS off)

| Mode | Vblank / rate | FPS | Notes |
|---|---|---|---|
| Flat | 60 | 30 | the game draws every 2nd vblank |
| Flat | 120 | 60 (1% low 35-57) | |
| Flat | 240 | 85-98, 1% low 52-82 | RSX thread ~10.5 ms = the frame: RSX-thread bound |
| Stereo, 300%, no culling patch | Unlimited | 64-100 | broken picture (scene ends at the game's frustum) |
| Stereo, 300%, no patch, `camera_block_cache` | Unlimited | 75-90 (one drive) | |
| Stereo, 300%, culling patch, words 0 (control) | Unlimited | **69.8**, 1% low 55, RSX 14.6 ms (20 s drive) | same route as below |
| Stereo, 300%, culling patch, views 100/100 | Unlimited | **60.8**, 1% low 49, RSX 16.5 ms | picture complete at all poses |
| Stereo, 300%, culling patch, views 60/80 | Unlimited | 63.1, 1% low 51, RSX 16.1 ms | |
| same, Multithreaded RSX | Unlimited | 57.6 | no help |

`rsx_sample.py rsx::thread` while driving shows ordinary per-draw work (driver calls, FIFO, copies, the eye transform):
nothing to cut. The stereo RSX thread is ~1.5x flat's; the game draws ~3000 draws a frame in town.

## Profile (generated, then edited)

Generator (driving, vblank 240): `row_vectors` `c[8]` (97% of depth-tested scene draws), camera position `c[15]`,
HUD `c[8]` with `hud_box_after_shader`, near plane 0.1 (metres, `eye_baseline` 0.064), scene rendered at 960x704
(`camera_target_aspect` 1.3636), `baseline_per_w` (1845 scaled objects), max_fps 80. Added: `camera_block_cache`
(+~15 FPS), `culling_scale_f32` on the patch's two words (absolute tangents, fov_deg 90 / aspect 1, options
horizontal_view / vertical_view). Candidates the generator logged and not yet looked at: depth-reading camera draws
`6c4b44c41756c4b9`, `c7628bf0a6f97bc7`, `e22111c01de7af88`, `f399d5670e9e3129`, `f77f4dfeccd5eba2`; screen passes
`ae484e86c7e97794`, `ebf08436f0254874`, `ec508c2628e474e8`, `fb2d64e87d8b9174`.

## Culling patch ("Wider view (VR culling)" 1.2)

The camera's viewport record (FOV degrees at +0x2b8, aspect +0x2bc, near, far, then tan(vfov/2) +0x2c8 and
tan(hfov/2) +0x2cc; 960x704 at +0x2b0/+0x2b4) is set by `0x5364d0` and built by `0x536358`: `bl 0x21ba0` (tan) gives
f1 = tan(fov/2), f31 = the horizontal/vertical factor, then the tangents, the projection (+0x1c0 / +0x1d4) and the
frustum (`bl 0x535a68`). The game FOV is 25 degrees parked and grows with speed (~40). The patch's cave at the `nop`
after the tan call raises ty and tx to two words (`0xe9ef04` / `0xe9ef00`, zeros after the data segment, never
written by the game) for viewports at least 960 wide. Two findings on the way:

- The render thread rebuilds the record only when its dirty byte (+0x2f0) is set (`0x5367c8`), so parked the
  floors never applied: `0x5367d4` `bne` -> `b`, rebuilt every frame.
- A 960x704-only check left the main thread's copy of the record (which the city's detail culling reads) narrow: the
  near streets showed the low-detail city mesh (blurred blocks). Width >= 960 floors both; the 220x220 minimap and
  256x256 reflection views keep the game's projection.

How it was found: `findpair.py 2.5373 4.5107` (hundreds of matrix copies), `findvals` for tan(vfov/2) found the record
(`0xc882a8`, a copy); its readers (RWATCH) only read near/far; write watch on the FOV -> the copy at `0x13d680` from
r12+0x2b8; `G_TRACE=13d64c G_REGS=r12` -> source records `0x301ea630` / `0x301ebe00`; write watches on those -> setter
`0x5364d8` and builder `0x536420`. Data constants holding 25.0 (`0xb411b0`, `0xb8c478`, `0xc845a8`, `0xc8aad8`) do not
drive the FOV.

## Pictures (simulator, 300%)

With the patch at views 100/100: the street, pavement, walls and buildings complete at yaw 0, -20, +20, pitch 10, roll
15; stereo matched; HUD (minimap, speedometer) in its box beside the car. Remaining: distant palm-tree impostors float
as dark blobs at the horizon; a blurred prop very near the camera (probably the game's near depth of field); not yet
checked: menus, cutscenes, the map screen.

## Next (if the frame rate is solved)

The RSX thread is the limit (stereo 14.6 ms with the game's own culling). Ideas not tried: fewer draws (LOD /
draw-distance words, pedestrian and traffic density), `min_scalable_dimension` only helps the GPU. Then: menus and
cutscenes, the depth-reading passes, a vrtest state.
