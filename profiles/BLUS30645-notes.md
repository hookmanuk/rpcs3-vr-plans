# Dragon Age II (BLUS30645) - VR notes

Disc 01.01 (`Dragon Age II (USA) (En,Fr,De,Es,It,Pl,Ru).iso`), PPU hashes `PPU-0f7889a598e8ca9a8ceaa52c918c2d1a7d24f4c0`,
`PPU-11ec63a93da423eaad5414266148c7a3db0f7823`. First boot installs data. Route: `tools/re/da2_boot.sh` (New Game,
Male Warrior, X through the prologue to the first fight on the mountain, ~4 min). Savestate `da2_fight0` (the
tutorial fight, "Mighty Blow" tip). Savestates need **Compatible Savestate Mode** (set in Matt's custom config).

## Frame rate

Uncapped: 75-90 FPS flat at Vblank 120 in the fight. Real time: three memory dumps at Vblank 120 (86 FPS) show the
game's clocks at rate 1.0 (`memclock.py`: 358 of 693 clock-like floats). No frame-rate patch needed.

## VR profile

Generated in the fight: `row_vectors` `c[256, 269, 263, 271]` (rigid, `require_camera_aspect`: camera blocks overlap),
`clip_space_scene_draws` (78% coverage), per-object WVP (`baseline_per_w`), HUD `c[260]`, near 0.075 = metres;
then `max_fps 0`, `default_fps 0`. Simulator: stereo and HUD box right straight, turned 25 and pitched 25; no culling
seen in the open mountain scene (no Wider view patch yet; DA:O's camera code is the place to start).

## Frame rate in VR (OpenXR Simulator, 300%, `da2_fight0`, no input)

| 72 Hz | 90 Hz |
|---|---|
| 70.6 / 70.1 FPS, 1.2 / 2.3% late | 75.6 FPS, 18% late |

**Fails 72** (just). Not rendering: the RSX thread's 12 ms is mostly waiting (`RPCS3_RSX_SAMPLE`: 26% sleep, 26%
`nv406e::semaphore_acquire`), so the game's PPU/SPU work limits it (flat is the same ~80 FPS). The tutorial fight is
busy (a dozen enemies, fire); measure a town scene (Kirkwall) before deciding.

**Not stereo: the game hitches flat too.** `da2_fight0` flat (probe render=0) at a fixed Vblank: 60 Hz 59.0 FPS, 1.69%
late; 72 Hz 70.7, 1.77% late; 90 Hz 86.6, 3.9% late; the late frames are exactly two vblanks (1% low = half the
rate), so some frames simply take longer than a vblank whatever the renderer does (stereo 72: 70.1-70.6). CPU settings
tried, no better: SPU loop detection + SPURS threads 6 (69.2), RPCS3 thread scheduler (68.9); SPU Block Size Mega
did not run. So DA II needs a quieter scene to pass 72, or the hitch found (PPU sampling of a doubled frame).

## Unchecked

Kirkwall, cutscenes, the generator's deferred candidates (`181f214b007bab9c`, `9383cb6078b54701`).

## Head poses on the OpenXR Simulator (real head pose, 2026-10-05)

Straight, yaw +-20, pitch +-10, roll 15 (`posecheck.sh`, `vrtest_da2_fight`). **Found:** the HUD (tooltip, portrait, ability wheel, target name) stayed on the face. Dragon Age: Origins' program hashes don't apply (DA2's Scaleform programs differ). **Fixed:** `passthrough_hud` with `hud_programs` `fb607f82e6910e72`, `2fb564a1e6dc9ad1`, `f7fb6105c0d5ebac`, `2f3922b03a474047` (inspector capture: draws 627-683 of 685, all `c[0..1]` 2D; `4dd42ea0e6add336` just before them passes positions through untransformed and is left out). Probe `why=` takes one hash at a time. Before `evidence/headpose-2026-10-05/pc_da2b_sheet.png`, after `evidence/headpose-2026-10-05/pc_da2c_sheet.png`.

## Frame-rate lead (generator readback log, 2026-10-05)

The updated generator logs two 1280x720x4 sections (`0x33000000` and `0xc0f70000`, `0x384000` bytes) read back every
frame in the tutorial fight, each waiting for the GPU (Write/Read Color Buffers are off). `0xc0f70000` is the target of the
frame's last draw (`1c7935c330cbbbd8`, after the HUD). If the game never reads them, `skip_readback_sections` would
remove a GPU wait per frame from a game that misses 72 by 1-2 FPS; if its SPUs read the frame (post-processing,
pause-screen capture), it can't be skipped. **Checked 2026-10-05: no.** The read comes from the game's SPU job thread (`EclipseGameSPUCellSpursKernel3`: the game uses the frame), and skipping both made no difference anyway: 70.5 FPS / 1.59% late without, 70.5 / 2.12% with (`evidence/vrtest/2026-10-05-1134-da2base`, `-1135-da2skip`). Reverted.


## 2026-10-07: 72 Hz re-measured (after the DWM fix)

`vrtest_da2_fight` at VR 72, 300%, 30-45 s settle, no input: baseline 71.0-71.3 FPS, 0.17-1.05% late; SPU Block Size
Mega 71.0-71.7, 0.35-0.87%; Sleep Timers Accuracy All Timers 71.1-71.4; Multithreaded RSX 71.5 / 0.70%. All within
noise of each other: **right at the 72 bar** (roughly half the runs pass both criteria). Where the time goes:
- `Eclipse::Update` (the game thread, 85% of a core) spends ~45% in a `usleep(30)` poll at `0x2998d8` waiting for an SPU
  job (`[r30+0xc]`, stacks through `0x3c8948`/`0x8c5000`); the SPURS kernels run 42-74%.
- The RSX thread is 12.2 ms of a 13.9 ms frame (flat at Vblank 120 it is 95% busy and the game settles on two vblanks,
  66 FPS): `region_intersects_cache` 9.4%, nv3089 `image_in` / `scaled_image_from_memory` / blit / `upload_scaled_image`
  ~23% together (the game blits images from main memory every frame), the VR per-draw work ~6%.
Next: what the per-frame nv3089 blits are (sizes, sources) and whether they repeat identical data.

## Fixed 2026-10-07: both eyes showed the same scene (fork 7c91de0b5)

A disparity check on a simulator shot (`parallax.py`, `vrtest_da2_fight`) gave 0 px for every region (hills, rocks,
characters, ground) with match score 1.0: both eyes showed the identical scene; only the sky differed. The frame (inspector
blit notes after the scene's last draw): blit main `0x33000000` -> `0xc0f70000` (the previous frame's copy, which the
SPUs read: the generator's per-frame readback), then blit the scene target -> `0x33000000`; bloom and the composite read
`0xc0f70000`, the HUD goes on top. Main memory holds one eye. Fix: `texture_redirects` now also redirect blits, and
`"to": "camera"` picks this frame's scene target, because the game alternates two (`0xc03c0000` / `0xc0000000`; a fixed
target, or "the target last copied into the buffer", read the other one, which by then holds the finished frame, and
the image fed back into itself to white). After: far rocks -162 px, characters -166..-170 px at every pose, no white
frames; VR 72: 71.5-71.6 FPS, 0.5-0.7% late (passes; was 71.0-71.7, 0.2-1.05%). The SPU pass on the copy (bloom input?) is
skipped in VR; the scene looks the same as flat at a glance. `0x33000000` is the same after a fresh boot.
