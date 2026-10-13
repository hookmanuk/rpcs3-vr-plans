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

## 2026-10-08: both eyes show the same scene

`eyesame.py` on the 2026-10-04 regression shot: best shift 0, residual 2.5 (only the HUD differs). An inspector frame
(`vrtest_kz2_carrier`, 1000 draws): the scene is drawn into `0xc07b0000`, then the last three draws (HUD, `e47548c5`,
`4d6a8c2b`, `d7bb3f7c`) go straight into the display buffer `0xc0010000`, sampling main-memory textures (`0x31d2e300`
160x90, `0x31a7d200` 640x360). No blit or draw copies the scene into the display buffer: it gets there outside the draw
stream, most likely the SPU post chain (Write/Read Color Buffers: the left eye's scene read back to memory, processed
on the SPUs, written into the display buffer). So both eyes show the left eye's post-processed image. A fix needs the
display buffer per eye: present the scene target (`0xc07b0000`) per eye and redraw the HUD on it (the SPU post effects
would be lost in VR, as in Puppeteer), or a new "display_redirect" profile key. Not done: Killzone 2 is also below 72 Hz.

## 2026-10-13: performance recheck (Matt)

`vr1pct.sh` on `vrtest_kz2_carrier`, 300%, OpenXR Simulator, walking (Vblank = 2 x rate: `vblanks_per_frame 2`):
- **72 Hz now holds: 72.0 avg, 0.00% late** (Vblank 144; was 63 on 2026-10-04 before the RSX-thread and multiview work).
- 90 Hz: 84.6 (fails; needs 89.1).
- Where 90 goes (Vblank 180, `RPCS3_RSX_SAMPLE=2`, `RPCS3_VR_GPUPROF=1`): draws are cheap (~320 draws, 1.3 ms of the
  RSX thread's 11.3 ms); 59% of the RSX thread waited in `get_occlusion_query_result` (ZCULL sync from the game's
  semaphore releases). With `zcull_relaxed_sync` those waits vanish but the frame rate stays 84.9: the RSX thread then
  idles waiting for the game. Per-thread CPU: PPU main thread 88%, the low-priority SPURS kernel 89%, other SPU kernels
  ~47%: the game's own PPU/SPU work is the limit (flat it peaked at 86-89 too). Guest blocked in readbacks 0.7 ms/frame.
- Settings A/B at Vblank 180 (run-to-run spread ~84-88): **SPU Block Size Mega 86.4-88.4 (kept: set in
  `config_BCUS98116.yml`)**; Accurate SPU Reservations off 85.7 (noise); Sleep Timers As Host 80.9 (worse); SPU loop
  detection 83.7 (worse); `zcull_relaxed_sync` 84.9 (no gain, reverted: it can change flares).
- With Mega: 72 Hz 72.0 / 0.00% late; 90 Hz 86.4. Combat (Corinth River) still unmeasured.

## 2026-10-13: shared eye image fixed (SPU post layer hidden)

By now the scene itself is per eye; the shared part was the SPU post layer. Draw `e47548c5` (last draws into the
display buffer, `vrtest_kz2_carrier`) adds, premultiplied (`ONE, ONE_MINUS_SRC_ALPHA`), over the sharp per-eye scene:
`tex1` `0x31a7d200` 640x360 (the SPUs' motion blur / depth of field / sun haze, alpha = blur amount), `tex0`
`0x31d2e300` 160x90 (bloom, `* c1`) and `tex2` 128x128 grain: `rgb = tex1 + tex0.rgb*c1 + (tex2.x + c0)*tex0.a`,
`a = tex1.a`. The SPUs build both from main-memory copies of the left eye (`0x3199c200` 640x360, `0x31c77600`
320x180), so the right eye showed the left eye's blurred image as a ghost (two antennas, the sun haze in the left
eye's place: `evidence/killzone2/shared-eye-2026-10-13/before-ghost.jpg`).

- Tried: `texture_redirects` to those per-eye main-memory targets (main-memory `to` support written for it). Stereo
  clean, but the image washed out (mean luminance 124 vs 76): the copies are the SPU job's inputs, not
  premultiplied, so the whole scene is added twice. Reverted the code (it fixed nothing).
- Kept: `hidden_draws` for `e47548c5` with texture 0 160x90. Both eyes clean and alike (`before-top-after-bottom.jpg`),
  also at yaw -20/+20 and pitch 10 / roll 15 on the simulator. Lost in VR: the motion blur and depth of field (both
  unwanted in a headset anyway), the sun haze/bloom and grain; image ~13% darker in the bright test view. `"hidden":
  false` brings it back (with the ghost). Next draw `4d6a8c2b` (lens flare sprites) only binds the layer, never reads it.
- 72 Hz with it: 72.0 avg, 0.00% late, 1% low 63.6 (Vblank 144, 300%, walking).
- A real per-eye fix would reproject the left eye's layer to the right eye by depth: not done.
