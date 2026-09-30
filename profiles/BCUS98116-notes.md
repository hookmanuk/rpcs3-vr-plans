# Killzone 2 (BCUS98116, v01.01 per the profile generator)

Added 2026-09-30. Profile `bin/vr_profiles/BCUS98116.json` (generated, then frame-rate fields edited). No patch.
Config `custom_configs/config_BCUS98116.yml`. **First pass only**: desktop stereo, one yaw audit, headset-path
frame rate. Not played in the headset.

## Config

- **Write Color Buffers and Read Color Buffers on.** Without them the loading screens (built from the last frame
  in memory) are garbage and the game appears stuck on them.
- Vblank 60 flat (the game flips every second vblank: 30 FPS). With VR on, the profile sets the vblank.

## Frame rate and performance (9800X3D + RTX 5090, 100%)

| | FPS | limit |
|---|---|---|
| flat, vblank 60 (native) | 30 | RSX waits on the game 72% of the time |
| flat, vblank 180 (carrier walk) | 86-89 | RSX thread ~85% busy |
| stereo, desktop path, vblank 180 | 90 (looking at a wall) | |
| stereo, headset path (headset FOV) | ~60 | RSX thread saturated |

The game is **real-time**: at ~87 FPS, 3,755 clock-like floats advance 1.0/s (memory dumps, `tools/re/memclock.py`),
e.g. level time and f64 clocks near 110 s. No speed patch is needed; only the vblank.

Profile: `vblanks_per_frame 2`, `max_fps 0` (any rate up to the headset's), `default_fps 45` (vblank 90, the
headset reprojects). 60 or 90 can be picked with VR Frame Rate but will not hold in combat. Fork d12f50a6e: with
`max_fps 0` the headset-rate branch now multiplies by `vblanks_per_frame` (it gave 45 on a 90 Hz headset).

## VR profile (generated in the carrier walk)

`row_vectors`, camera `c[0, 5, 1]` (base varies per program: `require_camera_aspect`), `linked_camera_blocks [25]`
(previous-frame matrix for motion vectors), HUD `c[8]`, near plane 0.25 → metres, `eye_baseline` 0.064, no camera
position. 85% of depth-tested draws covered; 7 programs uncovered (not yet classified).

Yaw-25 audit (`evidence/killzone2/audit-yaw25.png`): the carrier turns with the head; haze on the left edge is
geometry culled outside the game's frustum (expected). A translucent slab in the rotated eye is unexplained.

## Open

- Classify the 7 uncovered programs; pitch audit; combat scene (Corinth River landing) for coverage and frame rate.
- HUD `c[8]` unchecked (the carrier walk has no HUD).
- An RSX-thread hang once (1 of 5 boots, stereo audit run): spinning in `VKGSRender::get_occlusion_query_result`
  under `rsx::thread::sync` from `nv406e::semaphore_release`, from ~1 s after the level loaded. Log kept as
  `%TEMP%\rpcs3-vrprofile\kz2_query_hang1.log`. Not reproduced since.
- Movies at the raised vblank: the intro was skipped every time; check whether `video_vblank_rate: 60` is needed
  (Killzone HD needed it).

## Driving it unattended

Keyboard pad from `tools/keyboard-pad-template.yml` plus right stick A/D/R/F into `input_configs/BCUS98116/`
(deleted after the session). First boot: language (X), gamma (X), then the intro can be skipped with X.
New Campaign's intro cutscene cannot be skipped (~4 min). With a campaign save, `tools/re/kz2_boot.ps1
[-Headset] [-Probe render=1] [-Audit 25]` reaches the carrier walk (Continue).
