# Journey (NPUA70218, from Journey Collector's Edition BCUS98377)

Added 2026-10-07 (Matt: new game, at 90 FPS). The disc (`Journey Collector's Edition (USA).iso`, BCUS98377) is a launcher
whose games install from PKGs in `PS3_EXTRA` (the launcher only says "install from the XMB"): D000 flOw (NPUA80001),
D001 Flower (NPUA80083, the same package as the PSN release), D002 Journey (NPUA70218), D003-D005 the game-jam bonus
games Grave Diggers (NPUA80788), Duke War!! (NPUA80789), Nostril Shot (NPUA80790). All installed with
`rpcs3.exe --installpkg` (the dialog's Install clicked through UI Automation). Journey installs as APP_VER **02.00**.
Profile `bin/vr_profiles/NPUA70218.json`, patch file `bin/patches/NPUA70218_patch.yml`. No community patches for the
game itself (the community *Disable SPU MLAA - Multiple titles (01)* lists Journey).
Executable `PPU-2f01eb0b8ebbe638ee68b65798911b615168dcb4`; decrypted copy `tools/re/elf/NPUA70218.elf` (+ `.imports`).
PhyreEngine, EDGE post on the SPUs (`edgepost-mlaa-task`, `Edge/PostTask.spu.elf`).

## Boot

Epilepsy warning, save notice, Santa Monica logo; title ("New Journey") at ~40 s; Start; the opening (shooting star,
the traveller rises) ~70 s; gameplay on the first dune with the tilt prompt. Savestate `vrtest_journey_dune`
(= `NPUA70218_1_1`, mine): made after a fresh boot with the MLAA patch, so the SPU MLAA image in it is already patched.
The traveller does not walk from this state with the keyboard pad (the opening waits for the camera/tilt input).

## Frame rate: "Unlocked frame rate (follows Vblank Rate)"

- Native 30: the GCM vblank handler (`0x2c8358`, OPD `0x70eb98`, registered at `0x2c775c`) releases the flip every
  `[0xe986d8]` vblanks (2). The patch loads 1 (`0x2c835c`: `li r3, 1`). The same PhyreEngine handler as Flower.
- Game time is measured: memory dumps at Vblank 120 show the game clocks (f32 `0x9c4a6c`, f64 `0x9c82f0`..) at 1.0x.
- **SPU-bound flat: ~65-67 FPS at any Vblank Rate** (120 and 240 alike; resolution scale, Multithreaded RSX, thread
  scheduler, Clocks scale, SPU loop detection, GETLLAR spin, Accurate SPU Reservations: no effect). The RSX thread
  waits for commands (`run_FIFO` SwitchToThread); the main thread waits ~65% of its time in two `usleep(30)` polls
  (`0xb7a98` on a frame-slot semaphore at obj+0x7c4300, `0x128800` on a job counter); the six SPURS kernels run JIT
  code ~80% of the time. Not a time-based cap (Clocks scale 50/200 unchanged).
- *Disable SPU MLAA (VR)* (the community patch's two SPU instructions, keyed to SPU hash `9001b44f...`, `Apply To
  Savestates` does not reach SPU images: test from a fresh boot): gameplay 65-67 -> **70-71** flat. SPU Block Size Mega:
  +2 more (68 alone).
- Shortening the EDGE post threads' 1 ms poll sleeps (`0x1d1258`, test) changed nothing: reverted.

## VR profile

Generated on the dune (`column_vectors c[256]`, `require_rigid_camera`, `require_camera_aspect`,
`camera_slots_read_directly`, camera position `c[467]`, metres). Hand fixes:
- `view_y_down` removed (as Flower: the scene renders y-down into an offscreen target; with it pitch and roll were
  inverted on the simulator). Checked: yaw +20 moves the world right, pitch +10 down, roll 15 clockwise.
- `texture_redirects`: the post chain reads the final image back to main memory for the SPUs and composites from there:
  `0xcda20000` (1280x720 render target) -> SPU -> `0x36d35f80` (draw sampling it into the display buffer), and a
  640x360 buffer `0xcd780000` -> `0x36894f80` (sampled at the start of the next frame's post chain). Main memory holds
  one eye, so both are redirected to their render targets per eye. Addresses checked identical after a fresh boot.
- `late_readback_lengths [3686400, 921600]`: those two readbacks were waited for every frame (generator log); late, the
  VR rate rose to 72 (`skip_readback_sections` measured the same: kept late, which leaves the game's data intact).
- `passthrough_hud` + `hud_programs ["052bab32c11814c6"]`: the 2D overlay (title text, tilt prompt) in the HUD box.
- `max_fps 0`.

## Culling: "Wider view (VR culling)"

The dunes are drawn as tiles chosen against the camera's field of view; turning the head showed their edge (a jagged
border, sky colour beyond). Widening only the projection (constant pi/180 at `0x256eb4`, used by the projection builder
`0x256f90`) did not help: the tiles stayed, drawn smaller. The camera's field-of-view setter (`0x1ddbc`, vertical
degrees at obj+0xf4, called each frame from `0x20028` with `[r31+0x50]`) feeds every reader; the patch scales f1 there
(cave `0x6d1600` in the code segment's tail, min(FOV x Scale, 150 degrees)). Found with `findproj3.py` (projection
matrices in live memory: P11 = 1.7778 x P00) and a PPU write watch on the projection (`0x3020ccc0`, builder
`0x257004`). Scale 2.0 still showed the edge at yaw +20 (left side); **2.5 (default)** fills straight, yaw +-20, pitch
+-10 and roll 15. The frame rate is unchanged (72.0 at 72 with 2.0 and 2.5).

## Frame rate in VR (OpenXR Simulator, 300%, `vrtest_journey_dune`, holding forward)

| Vblank | Result |
|---|---|
| 72 | **72.0 FPS, 0% late** (SPU Block Size Mega; 71.8 / 0.17% late without it) |
| 90 | 75.2 FPS (the game's SPU-bound ceiling) |

Sustained: **72 Hz**. 90 needs the SPU load cut (unknown SPU programs `scr` x3, `cor`; EDGE post).

## Open

- 90 Hz: SPU-bound at ~75 in VR, ~70 flat (with MLAA off). The SPU jobs `scr`/`cor` are the game's own.
- Only the first dune seen in VR; later levels (sand surfing, the underground, snow) and cutscenes unchecked; the
  traveller's scarf/glyph glow effects and the other traveller unchecked.
- One run at Wider view 2.5 drew no frame at all after loading the savestate (threads parked in waits); the retry and
  the pose runs were fine. Watch for it.
- Headset run.
