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

## 2026-10-08: 72 Hz on a clean CPU (after the miner removal)

`vrtest_da2_fight` at VR 72: 67.5-69.0 FPS, 4.3-6.7% late (fails); flat (render=0) the same, 69.0 / 4.35%, and 74.7
uncapped at vblank 120. So the 2026-10-07 pass (71.5) was helped by the miner keeping the CPU awake. A/B: 4 idle-priority
busy threads 71.2 / 1.05%; Processor idle disable 71.4 / 0.88% (passes); Minimum processor state 100% 68.8 (no help).
RPCS3 settings: Sleep Timers All/As Host 68.6-68.7, RPCS3 Scheduler 66.9, Multithreaded RSX 68.4, SPU reservation
busy waiting 70.3 / 2.5%, both 69.9. Game-side CPU bound near 72 with wake-up latency on top; no fix found.

## Parked (Matt, 2026-10-08)

Corrupted graphics and poor performance. Parked with The Darkness, Anarchy Reigns and X-Men Origins.

## 2026-10-15 overnight: frame rate at 90 and graphics check

`vrtest_da2_fight`, VR 90, 300%, 2880x2880 eyes (simulator), fork fd5631db8: **86-88 FPS, 2-4.6% late**, RSX thread
10.3 ms/frame. Uncapped at Vblank 120 it settles on two vblanks (62 FPS).
- RSX thread (sampled): 37% `nv406e::semaphore_acquire`, 20% `SwitchToThread`, 8% lock waits: it waits on the game.
- `Eclipse::Update` (PPU sampler): 40-43% at `0x2998e0` (the `usleep(30)` SPU-job poll), 8% at `0x46289c`.
- Frame log: late frames (exactly two vblanks) scattered, gaps 1-146 frames, no period.
- A/B at 90 (two runs each, alternating): SPU Reservation Busy Waiting on 86.1 / 87.2 vs 85.9 / 86.4; Usleep Time
  Addend -25 86.9 / 87.5 vs 87.1 / 88.2. Noise. Nothing kept.

Graphics: L2 (radial menu) pauses the fight with the scene visible: a frozen frame compared flat vs stereo shows both
eyes alike and like the flat image (the shadow streak differences seen in moving shots were motion). Playing on from
the fight (scripted attacks, ~5 min) reached a conversation once: the dialogue camera is close to the faces, so in the
headset they are huge and near, with the dialogue wheel small on the face. A fix would be `screen_frame_draws` (the
conversation on the fixed screen) with a draw that only conversations make; the scripted play did not reach a
conversation a second time, so no savestate or capture yet.

## 2026-10-15: black sky after a fresh boot (found, not fixed)

Fresh boot from the disc on the simulator (VR on, 300%, Vblank 90), New Game, X/Return through the opening (the
Cassandra cutscene: her face fills the view; some shots of it go to the fixed screen, others not), into Varric's
prologue fight: **the sky is black in stereo**, a jagged white band at the horizon; flat (probe render=0) the same frame
has clouds and the sun (`evidence/da2/blacksky_freshboot_vr_vs_flat.png`). It is missing in the scene targets
themselves (`c03c0000`, `c0000000`, `c0f70000` dumps: `blacksky_scene_targets.png`), and stayed for minutes (not shader
warm-up). The sky is `8d9f0acc423270eb` (one draw, 2457 vertices; clip = rows x, y, w, w of camera block `c[271]`, so it
sits on the far plane; depth test LEQUAL, no depth write); hiding it in flat darkens the sky region (147 -> 15),
hiding the depth-prepass programs in stereo changes nothing. Its constants are identical to the fight state's, where
the sky renders. **A savestate made in the black-sky session (`vrtest_da2_blacksky`) renders the sky correctly after a
fresh load**, so the cause is session state from the boot path (the opening cutscene's fixed-screen frames? a pipeline
built then?), not the frame. Probably Matt's "corrupted graphics" (10-08). Next: reproduce from a fresh boot with
`RPCS3_VR_NO_INVARIANT` / multiview off, and log the sky draw's pipeline and depth state per eye.

Same fresh-boot sessions also show **Bethany's hair off her head**: she looks bald and the hair floats as a dark blob
near the ground beside her (`evidence/da2/freshboot_hair_floating_blacksky.png`); in the savestate-loaded fight
Hawke's hair sits on his head. (The bald look in the 10-14 conversation shot came from a session loaded from
`vrtest_da2_fight`, so the hair may also break there; not seen in a still frame yet.)

Ruled out for the black sky (each a fresh boot through the opening, ~6 min, or a live change in that session): the
cinematic fixed screen (`Cinematic Scenes: Full Quality`: still black), multiview (`RPCS3_VR_MULTIVIEW=0`: still
black), probe profile state (forced profile reload: still black), `clip_space_scene_draws` off, dropping `c[269]` from
`camera_blocks`, `require_camera_aspect` off, switching stereo off and on (render=0 -> 1). The probe's `why=` shows
the sky draw as a camera draw with no slots changed in both the good and the bad session. What a fresh boot has and a
savestate load does not: the main menu (a 3D background) and the cutscene before the fight, so the next suspects are
texture-cache or surface state from those (a sky texture address that held a render target earlier?).

Depth at the black sky (fresh boot, 2026-10-15 04:33): a dump of the depth buffer `0xc0780000` (Z24, 1920x2160 eye)
reads **1.0 at the sky pixels** (cleared to far) and 0.95 on the ground, so the sky (z = w, LEQUAL) does not fail on
the depth buffer: its own depth after the eye mapping must leave the clip range (z/w just above 1, clipped at the far
plane). Suspect: state the probe keeps across the session (for example the last camera block used to map
pre-projected draws, `m_vr_last_block`, or the projection learned from earlier cameras) set by the main menu's 3D
background before the first gameplay frame; a savestate load starts without it.
