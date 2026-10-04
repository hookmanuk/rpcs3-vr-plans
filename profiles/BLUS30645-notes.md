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
