# Project Gotham Racing 4 (Xbox 360 4D5307F9): PCVR port on ReGPU

Matt's fork of zer0ducksgiven/PGR4-ReGPU: `H:\PGR4-ReGPU`, branch `vr` (local, not pushed). A XenonRecomp port on ReGPU
(D3D12, vendored in `thirdparty/ReGPU`). Not RPCS3.

## Build and run

- Inputs: `H:\ROMs\pgr4` (the disc ISO and Title Update #2, `TU_16L61VP_0000004000000.00000000000G1`, sha256 9980cf82...d9b8:
  the recompile config, jump tables and hooks are at the updated addresses, so the update is required). Extracted to
  `game\` and `out\tu2`; `sh tools/recomp.sh` makes `out\ppc`.
- Local SDKs (git-ignored): `thirdparty\sdl3` (3.4.20 VC), `thirdparty\ffmpeg` (BtbN n8.1 LGPL shared, the same DLL versions
  upstream ships), `thirdparty\fidelityfx` (copied from `H:\uncharted_pc\gpu\third_party\fsr-vulkan\upstream\ffx-2.3.0`).
- Compiler: clang 20.1.8 at `H:\tools`. `plans/tools/pgr4/env.cmd ninja -C H:\PGR4-ReGPU\build\rel pgr4` (from PowerShell's
  `cmd /c`: Bash with MSYS2_ARG_CONV_EXCL leaves `//c` as is and cmd hangs). `build\tools` was configured from a small wrapper
  CMake project (`add_subdirectory(thirdparty/XenonRecomp xenonrecomp)`) because the root CMake refuses an empty `out\ppc`.

## Test tools (`plans/tools/pgr4`)

- `pg.sh start|stop|<regpuctl command>`: the debug server, with the test user folder `H:\PGR4-ReGPU\out\testuser` (never Matt's
  `E:\Documents\pgr4`; his profile is backed up in `H:\backups\pgr4-profiles-*`). The log is `thirdparty\ReGPU\out\live.log`.
- `vrrace.sh EYE [NAME=VALUE...]`: VR on the OpenXR Simulator, driven to the St Petersburg race grid (Arcade, chapter 1, event 1).
  `flatrace.sh RES`: the same flat. `SIMXR_HZ=240` shows the headroom above the simulator's 90 Hz.
- `vrperf.py SECONDS LABEL`: average FPS, 1% low, into `perf.log`. `sweep.sh`: a list of configurations.
- `tintfind.py X Y`: which pixel shader draws a pixel. `eyecmp.py`: left against right of every resolved image after a capture.
- `tweaks.py OUT`: dumps the game's named settings. `strxref.py`, `objxref.py`, `ppcdis.py`: strings, statics and functions in `out\ppc`.

## How the VR works

- `thirdparty/ReGPU/src/vr/vr.cpp`: OpenXR on the game's D3D12 device (`REGPU_VR=1`, `REGPU_VR_EYE=WxH`). Loader DLL beside the exe.
- One pass, both eyes: EDRAM surfaces have two layers; a stereo draw has 2 instances, the vertex shader writes
  `SV_RenderTargetArrayIndex` = instance and multiplies its **final clip position** by the eye's matrix (`hlsl.cpp VrPatch`). Game
  shaders are untouched. FXC SM 5.1 can do this (no SV_ViewID there).
- Eye matrix = eye projection x head pose x inverse(game projection), the game's projection read per draw from its view-projection
  in c4-c7 (`vr::ProjectionFromViewProjection`). z keeps the draw's own near and far. Zoom with speed is cancelled by this.
- Stereo passes: pitch 1280 always; others once a draw samples a stereo resolve (the bloom chain); pitch <= 128 stay one image, read
  from the left eye (exposure must agree between the eyes). Resolves keep a right-eye twin; `tbias.y` holds both descriptors.
- Flat draws (w = 1) that don't sample the frame go to the HUD box (`vr::HudMatrix`, 2 m away, 2.4 m wide), scissor as clip distances.
- Game side: `src/hooks/vr.cpp`. `sub_822C0638(camera)` is each camera's vertical field of view (`PGR4_VR_FOV` scales it).

## Game facts found

- The executable keeps its developers' **named settings**: 2466 objects (bool `kind 1`, int 2, float 3), value at +32, at fixed
  addresses. Listed by `tweaks.py`. `Camera.Shake.Enable` 82C94460 (read by sub_827DD588), `Camera.PassingShake.Enable` 82AB4638
  (sub_824BA960), `Camera.Chase.SlideTiltEnable` 82C941FC, `Wheel.DrivingEffects.*` 82A81F08.. 82A928FC.
- Strings: file offset - 0x3000 + 0x82000000 in `out/tu2/default_tu2.xex`.
- Camera: `sub_822C2410` builds the projection (camera +432/+436 near/far, +440 aspect), `sub_82322480` sets the matrices,
  `sub_824DC5E8` loops the viewports (stride 21008). Main-view projection in the race: sx 1.0003, sy 1.7783 (90 x 59 degrees), near 0.05,
  reversed depth. Game units are metres. A view struct sits at 4013DA50 (forward, right, up, eye).
- Force feedback: `sub_823105F0(wheel, six floats)` writes the effects from `Wheel.DrivingEffects.Feedback.*`, fed by `sub_822DCB18`
  (zeros unless car+7573 bit 0x40 is set and 0x80 clear and a global allows it), physics in `sub_822E2880`.

## HUD and menus: how the game draws them (found 2026-11-07)

- After the final composite (vs e0b5be1feb70ac93, ps 4c40a956f32770b5) the HUD draws on the main surface: vs 380113a5f8092891,
  a6311cf11f1d88eb, da7f034395da2cd9 (fonts, icons), positioned through a projection with no view in c4-c7.
- Menu panels are drawn off screen on another EDRAM base (colour 5002D0), resolved (159EA000, 15D82000), then brought onto the
  frame by one full-screen draw of vs 380113a5 sampling that 1280x720 image. So: only base 0 goes in the box, and a HUD draw sampling a
  frame-sized image goes in whole. A plain full-screen quad (a fade, the pause dim) stays over the whole view.
- vs 9862cfa7a2bc20ec ps 8c8b535864c59f02 through a 4x view (pitch 640, vte 300) is both the clears (no blend) and panel shading (blended).
  The menus clear their red backdrop this way: a pitch test alone missed it (red in the left eye, black in the right).
- Flat draws in the HUD box: `vr::HudMatrix`, 2 m away, 3.2 m wide (REGPU_VR_HUD_DIST, _WIDTH, _DOWN).

- Cone Sprint (Arcade, chapter 2, event 3, Las Vegas): the gate pillars and cones are 3D objects; "Cone Gate", points and the star are flat HUD. All HUD draws have the
  depth test off (depthctl 00700764). The rev counter is drawn translucent: a cone or barrier shows through it, flat and VR alike (compared on the barrier).

- Occlusion queries in a race: 4 a frame, vs 8edac5ea1aa54d06 on the mono 320x180 pass (colour 2800B8, depth 0), from the game's camera, so they do not depend on the eyes.
  The colour-mask-0 draws of vs 2fe309ee (scissor 16x16) are not queries.

- Panel glass (vs c8c72c62732db4c1 ps b52fda521e70fc9d): samples the frame, panel contents already on it, at the flat screen position it computes into o[2]. `VrRewriteShader` sets o[2] from the eye's final position.
- A panel's scissor (the car list 91,139-415,532): clip distances on the frame; the flat game's wide-screen scissor mapping must not run in VR (it left host scissor -756..540).
- 3D medals in panels: vs d4f0a3c4018247c9 (off-screen layer), d0cb4228ca25ff92 (on the frame), in REGPU_VR_HUD_VS. They draw through a camera on the heap (4003E7xx), which the frustum shaping must leave alone. The world's cameras are static: 82AB61A0 (main view) and 82ADF240. Shaping only 82C91D00 or only 82ADF240 brought the black road bars back: 82C91D00 is the camera whose world matrix turns, not the one whose projection is built.
- Flat against VR, every menu screen: `tools/pgr4/menus.sh`; head poses: `poses.sh`; a panel's draws: `hudlist.py`; barrier and sparks: `crash.sh`.

## Particles

- Tyre smoke: vs 246d1432b64841aa, ps 701118197155dbca: soft particles. The vertex shader hands its clip position on (o[1] = clip x c224)
  and the pixel shader reads the scene depth there. `VrPatch` makes any such output use the eye's clip position (VrEyeClip).
- b42215dae1817893 reads depth in the vertex shader (t17), patched in `VrRewriteShader` (src/hooks/vr.cpp).
- A resolved image's right-eye copy is made only if a draw read it in the last 120 frames (`rightRead`). The front buffer has no reader
  among the draws: `RendererOnSwapImpl` marks it. (Forgetting that left the right eye up to 2 s old.)

## Force feedback

- The game's setup (sub_82310F60, state 3) continues only when SetEffect's overlapped result says 4 effects were taken. The port
  reported 0, so it set the effects up again every frame with zero inputs. Fixed in `kernel/wheel_ff.cpp`.
- Now sub_822DCB18 passes real physics to sub_823105F0. Blocks: 1 a sine (word 11 magnitude 0-255, word 14 period in ms: chatter, rough
  ground, rumble strips); 2 and 3 springs centred on the slide (outer one negative coefficient, loss of grip); 4 friction by grip.
- `input/wheel.cpp` plays all of them. Tested with PGR4_FAKE_WHEEL=1 PGR4_WHEEL_FF_TRACE=1 PGR4_WHEEL_FF_WORDS=1 (the values change with
  the car), **not on a real wheel**.

Audit for a real wheel, code only (`input/wheel.cpp`, needs a wheel to run; the fake wheel stops above SDL): the thread runs every 2 ms and holds the device's lock across SDL calls, and many drivers wait for each USB write. Conditions now go out only on a felt change (centre 0.5%, coefficients and saturations 1%), vibrations and conditions at most about 120 a second; a refused effect is asked for every 5 s, not every pass; a type the wheel lacks is logged once; `sine` added to the features logged at start. Look for these in the log on a real wheel: `wheel: force feedback:`, `was refused` (the negative outer spring is the likely one), `has no effect of the game's type`.

## Screen shake

Settings `screen_shake` (launcher switch, PGR4_SCREEN_SHAKE). Proved with Camera.Shake.UseCustom and a large custom amount: direction
roughness 0.08-0.09 with Enable on, 0.0001-0.007 off.

## Frame budget (measurements in `plans/tools/pgr4/perf.log`, DLSS off, simulator, race grid / driving)

- Flat 5120x3240 (same pixels as VR 2880 x2): 137 / 200 FPS. VR 2880 per eye, 240 Hz simulator: 84 / 126. VR 5120 per eye: 65 / 84.
- VR 800x800 per eye: GPU still 10.3 ms on the grid: most of the frame does not scale with pixels.
- Grid, by eye size at 240 Hz: 800 10.3 ms, 1600 10.6, 2880 11.9, 5120 14.1: about 10 ms fixed and 0.08 ms per million pixels.
- 3.5 million vertices a frame (both eyes), 4750 draws: not vertex throughput. The second instance costs 1.5-2.5 ms at 800 per eye. The game alone
  (REGPU_NO_RENDER) reaches 339 FPS, GPU busy 96% even at 800 per eye: per-draw command cost, about 2 us a draw. Flat 720p has the same 7.65 ms.
- No effect: fetch bounds, submit cadence (128, 2048), 7 draw workers. Off-screen pass scale: 3 to 1.5 gives 64 to 70 FPS on the grid.
- The simulator's xrEndFrame costs 1.5-2 ms and spikes to 17-29 ms, which is its 1% lows: pacing needs SteamVR (headset off on 2026-11-06).
- Mirror window: on is faster than off on the simulator (74 against 60 FPS at 5120, not understood): stays on, REGPU_VR_NO_MIRROR=1.

### Frame pacing, real headset (2026-11-07). Supersedes the null headset figures below

**Measure on the real headset through SteamVR with `vrstats.exe` (SteamVR's own account).** On the null headset every frame reads as reprojected, even at 800 per eye with the GPU idle, its compositor runs at about 100 Hz whatever it is set to, and 5120 read 97-100 FPS against 75-88 on the real headset.

What was wrong, measured: xrWaitFrame/xrEndFrame ran on the renderer's thread, so xrEndFrame came before the GPU had finished; the runtime shared the game's queue and its waits held each frame's GPU work back to 7 ms into the frame; the game's thread ran free against the headset, so runs settled in a good or bad phase by chance. SteamVR switched the app's period between 11, 22, 33 and 55 ms.

Wrong turns, all mine: blaming SteamVR's compositor for the 15-19 ms frames (Windows' GPU counters: vrcompositor 0.3%, SteamVR's own figure 0.76 ms; Matt said so first); a game limit at the headset's rate removed (right) and then patches for early submission, a separate queue and a token one at a time, one lucky 10 s window read as fixed. Matt: "We have made VR mods for uncharted and burnout that frame pace perfectly, use those as a guide." Porting their loop whole fixed it at once.

The loop (`vr/vr.cpp` FrameLoop): own thread and queue; xrWaitFrame, LocateViews, token (VdSwap waits for it, 50 ms limit); WaitForGameFrame until the GPU has finished a newer frame (100 ms limit); xrBeginFrame; copy on the headset's queue; xrEndFrame with the pose the frame was drawn with. The renderer only publishes: `SnapshotViews`, `BeginPublish`, `Publish`. A fence wake must be checked again: a stale one left a repeat every few frames (Tokyo: 28-46 repeats in 5 s).

At 5120 the limit is real GPU work: 490 W, 84-91% busy, about 12.5 ms. Road 1.15 ms, walls 0.94, full-screen composite pass about 2.7. Mirror window off: no gain on the real headset (78.5/77.0 against 80.4/80.8). Not tried: hidden area mask, now measurable on the real headset (pixels are about 3.5 ms of the frame, so about 0.6 ms expected).

### Real SteamVR without a headset (2026-11-07): `plans/tools/pgr4/nullvr.sh`, `nullsweep.sh`

SteamVR's null headset, with a private config folder (VR_CONFIG_PATH), so Steam's own settings stay untouched. Real compositor and frame pacing, no optics
(its view is 90 degrees square, narrower than a real headset, so a real headset draws more). Quirks: a cold SteamVR opens room setup, which ends the OpenXR session
(state 8, the game exits): nullvr.sh lets that happen, closes it, starts again. Once the start hung in runtime init at frame 0, with SteamVR just restarted.

- 90 Hz, 2880 per eye, grid: 90.0 FPS by the runtime's count, xrEndFrame 0.45 ms.
- 90 Hz, 4096: grid 79.4, driving 88.2. 90 Hz, 5120: grid 74.5, driving 82.9, both with p50 about 11.2 ms: most frames make 90 Hz and the rest wait for the next slot (22 ms).
  That wait is the "spike" in xrEndFrame: a frame over the slot, not a hitch of its own. GPU time at 5120 is 13.2 ms: 2-3 ms short of 90 Hz on the grid.
- GPU at 5120 grid: 81-91% busy but only 286-306 W: the geometry front end limits it, not shading.
- Mirror off is slower here too (60 against 72 live, GPU time 16.4 against 13.2): not understood; left on.

### Where the fixed cost goes (St Petersburg grid, 800 per eye, REGPU_GPU_SHADERS=1 REGPU_NO_DRAW_WORKERS=1; these markers crash with workers on)

- Same top shaders at 800 and 5120 with the same times: 882d1487 (building walls, red in the tint test) 2.0 ms, 705 draws, 795k vertices; d9c8f878 (columns, stands) 1.7 ms, 293 draws, 917k;
  553a8f3b (the crowd) 1.7 ms, 568 draws, only 116k vertices; 142ded03 0.7; f676e896 0.6. Vertices counted with both instances (`drawstats` now lists them).
- Top five vertex shaders with `r.pos = 0` (draws and vertex work stay, nothing rasterised): GPU 10.3 to 4.8 ms, 88 to 154 FPS. So this is neither draw submission nor vertex shading.
- Flat colour in their pixel shaders: no change, so not pixel shading. Depth test off: no change. REGPU_VR_ONE_EYE halves them, so the cost is per instance.
- Coverage draws in occlusion queries off: no change. Interpolators limited to 8 of 16 (hlsl signature): 97-99 against 96-97 FPS, no real change: not attributes.
- Grid against driving at 800: GPU 9.7 against 5.3 ms: the stands and crowd at the start line are half the frame.
- SV_ClipDistance0 off for every draw: 97-100 against 97 FPS on the grid, none driving: no gain, reverted. REGPU_SUBMIT_DRAWS 1024 on SteamVR at 144 Hz: 77.7 against 72.7-76.9 grid: within noise. Off-screen scale 1.5 on SteamVR: no gain.

### The answer: vertex data across PCIe (`nvidia-smi dmon -s tu`, the rxpci column)

The GPU was reading **22 GB/s, about 200 MB a frame, from system memory** on the grid: guest memory is mapped to the GPU in place ("zero copy"), and both eyes read every vertex. That is why the cost ignored resolution
and pixel shaders, and why the GPU sat at half power. Culling with `r.pos = 0` hid it, and the "per-draw" reading above was this too.

`renderer.cpp` VideoNeeds, VR only (REGPU_NO_VIDEO_VERTICES=1 turns it off; REGPU_VIDEO_VERTICES=1 turns it on flat): a 512 MB copy of guest memory in video memory, gphys reads that. rxpci 22 to 7 GB/s.
5120 at 144 Hz: grid 76 to 99, Vegas driving 79 to 98-100 (null headset's cap about 100). 90 Hz: 88.5 / 88.8. Flat: 128 to 134 grid, 185 to 202 driving (opt-in: it isn't needed there).

- **Don't track this by hash.** First version: a buffer copied once, recopied when its hash changed. Scrolling through cars and back gave exploded geometry: cars are streamed into a pool, a model loaded back hashes as before, while the copy holds the car loaded since.
  Now a CPU mirror of the copy (`g_videoMirror`) is compared byte for byte, and writing over bytes another buffer covers sends that buffer back to be compared. Test: `tools/pgr4/stale.sh` (flat against VR).
- After the copy the GPU really is shading: 490 W, 84-91% busy, rxpci 4-5 GB/s, GPU time 10-11 ms, the road the largest item (1.07 ms, crowd 0.26). Off-screen scale 2: 89.1 against 88.8. Mirror off: worse (87.2, 16.7% late).
- Pacing: `xrWaitFrame` took 0.02 ms at 90 Hz: the game's limiter (VdSwap, a CPU timer) set the rate, a second clock against the runtime's. With it out of the way (limit 360, the default in VR; REGPU_VR_HZ sets another) the null headset gives 97-99 FPS at 5120 and the simulator 90.0 at 90 Hz, 72.0 at 72 Hz. Game time follows the clock: same speeds at the same moments.
- REGPU_VR_TRACE=1 logs length/xrEndFrame/xrWaitFrame per frame; `tools/pgr4/latecheck.py` reads it, `nulllate.sh` runs it. Late frames at 5120: 18/9/4, 19/13/0, 26/18/0: xrEndFrame, GPU contended near its limit.
- The 15-19 ms frames at 5120 (REGPU_GPU_PASSES=1 REGPU_GPU_LONG=13 logs each long frame's passes): one arbitrary pass grows by 7-9 ms (the final resolve 9.5 against 0.7, a 2.7 ms pass 11.8). Looks like another process taking the GPU, most likely SteamVR's compositor: frames of 16 ms or more, SteamVR 366, simulator 85 (no compositor process), and no such single block on the simulator. Not proved, no view inside SteamVR. Simulator at 90 Hz, 5120: 90.0 sustained. Off-screen scale 3, 2, 1.5: all 90.0, mean GPU span 10.6-10.7 ms, stays 3.
- Not done, can't be measured here: hidden area mask (XR_KHR_visibility_mask; no real lens on the null headset; about 20% of the pixels on a real one).
- Constants in video memory (copied before the frame): crowd unchanged, 1.69 ms, not worth it. The D3D12 Agility SDK 1.616 loads but reports GPU upload heaps unsupported on this Windows (22631): no resizable-BAR ring.
- A failed resource creation looks like success: the first run of the fix had `CreateCommittedResource` fail on the guest resource's desc and fell back silently, and an A/B of it measured nothing (flat "no change"). Check the log line `vertex data in video memory`.

### What makes up the frame at 5120, and what came out of it (2026-11-07, real headset unless it says simulator)

How to look: `REGPU_GPU_SHADERS=1 REGPU_NO_DRAW_WORKERS=1` for per-shader times, `tools/pgr4/passlist.py LOG` for the frame in order from a `pg.sh capture` trace, `tools/pgr4/hmdscale.sh` for one figure per size. Uncapped figures: simulator with SIMXR_HZ=240. "GPU time" in the perf line is the frame period when capped, not the GPU's busy time: at 2560 it read 11 ms with the GPU 46% busy.

- Busy time against size: 2560 about 5.1 ms, 5120 about 11.9 ms: about 2.8 ms fixed, the rest follows the pixels. Shadow and reflection passes barely register: nothing large to cache there.
- Whole frame at 2x2 shading (RSSetShadingRate, a test, reverted): scene draws only 77 -> 92 FPS, all main view draws 107 (simulator). So a foveated version of it would not reach 90 on its own: about 9 ms is not pixel shading (copies, depth and colour writes, fixed cost).
- **Early depth:** 2628 of about 3000 depth-writing draws have the alpha test off (`tools/pgr4/alphastats.py`), and every translated shader still carries it as a discard, which stops depth being written early. A variant (`EarlyDepthVariant`, pipeline flag 0x400, not in the manifest, built in the background with the plain pipeline drawing until then) serves 68% of them. Grid 74-81 -> 82-88, reprojected 39-48 -> 7-25; driving unchanged. REGPU_NO_EARLY_DEPTH=1 off, REGPU_EARLY_DEPTH=1 on flat too.
- **Motion blur:** ps 7a9187ce7e737c35, vs e0b5be1feb70ac93, right after the scene's tiles are resolved: rebuilds position from depth, velocity from pc154-157, then up to 14 fetches a pixel along it (alpha below 1, the cars: a 5-tap soften instead). It also writes the resolved depth into depth base 2D0 for the passes after it. 3.2 ms by the markers. Off in VR (`VrRewriteShader`): driving 77.9 -> 91.2 FPS uncapped. Setting motion_blur, PGR4_MOTION_BLUR; flat always has it. Real headset: grid 90.0, 0.0; driving 86-89.
- **The restore draw** (the blur draw with no blur) still cost 1.5 ms: `KeptScene` in renderer.cpp. Shader tagged `Host::kShaderPutsSceneBack`. Once one has been seen, the frame's clearing resolves of the scene keep their clears back until the frame's last clearing resolve (0x300, depth 2D0), the draw is skipped, and depth 3C0 stands in for 2D0 on wide passes. A frame without the draw after all keeps its scene for one frame. `g_zeroedEdramBase` must stay the register's base: the minimap relies on it. The two colour resolves before it (0D9B0000, 0DE60000) had no other reader (a later full resolve rewrites 0D9B0000) and are skipped too. The depth resolves stay: draw b64841aa/7155dbca reads 0E0E0000. Uncapped driving 92 -> 100-102. REGPU_NO_KEEP_SCENE=1 off.
- Left as they are: front buffer resolve 0.78 ms (the 8-bit conversion), eye copy 0.26 ms (not worth touching the ported frame loop).
- Slow frames: 192 frames over 13 ms in 15 s against 12.1 reprojected a second: reprojection while driving is those frames, not a pacing fault. No single pass grows.
- Budget at this point: main scene pass by far the largest. Not tried yet: lens mask (rejects with early depth now), smaller colour format (RGBA16F target, 8 bytes a pixel; the alpha may no longer be needed with the blur off).

Reading mistakes worth keeping: I called the 3.2 ms draw a plain restore before reading its shader (it is the blur), and blamed the blur patch for missing road markings. Alternating stripes of plain and patched output within one frame settled that one in one run: the band ran through both. `test-1`-style shots from different boots compare the boots too.

### Second round of Matt's test, 2026-11-07: what they were

Tools: `rec100.py` (the game's window, every distinct frame, no sync with the game), `flashstrict.py` / `flashtop.py` (one-frame flashes, close up), `flashab.sh` (a count per configuration), `bounce.py` / `dashtest.sh` (cockpit against camera), `dlgposes.sh`, `carposes.sh`, `headmove.py` (the simulator's head moving).

- **Find flicker with many real frames.** Matt: "Just record 100 frames and you'll see it in some of them." Shots through the debug server hid it for a long time. A crash looked like the trigger only because of when I happened to look.
- **Stray triangles:** one vertex of the dashboard's top, thrown up over the windscreen for one frame. The translated vertex shader decided "2D" per vertex by w being 1 (within 1e-4): w is the distance from the camera, the dash is a metre away. Flat barely shows it; VR skips the eye's matrix for that vertex. Exactly 1.0 was not enough: with world coordinates in the hundreds, w falls on coarse steps and still hit 1.0 about every 150 frames. Now also: if the shader reads a camera matrix (c4-c7 or c20-c23) with a view in it, it is 3D (VrPatch). No flash of this kind in 2 x 294 real-headset frames afterwards, head still.
- **Cars' shaders:** c0-c3 is the part's transform to the world, c20-c23 the camera's view-projection (the same as c4-c7).
- **Cockpit bounce:** not the shake settings, and not Camera.Dash.HeadAmount (0.25: no change at 0). The body moves on its suspension against a steadier camera. `VrSeatLock` in renderer.cpp: the body is the part transform most draws of a frame share; a slow average (2 s) is the seat; the view moves by the difference. The car's own draws use this frame's figure, the world last frame's. On only with the camera 0.05-1.3 m from the body's origin, 45 frames running. The game's world is left-handed: no cross products when re-orthonormalising (that dropped the lock after 30 frames, every time). Cockpit vertical range 12-97 px -> 0-5 px of 800. View moved about 6 mm on average, 40-46 at most. screen_shake=1 turns it off with the shake; REGPU_VR_NO_SEAT_LOCK=1.
- **Menu flicker:** the menus' 2D layers draw with depth test and write on (dc 00700766) at one depth, passing "greater or equal" by being equal; rotated into the box they round differently. `VrHudLayerNoDepth`: no depth for them (not the 3D medals, REGPU_VR_HUD_3D_VS; also the glass and 2 more, REGPU_VR_HUD_LAYER_VS). REGPU_VR_HUD_KEEP_DEPTH=1. Crest and arrow cut up at small head poses without it.
- **Dialog:** text is drawn, the frame resolved, then the glass (ps b52fda521e70fc9d) shows the resolved frame through its partly transparent surface. Its place on the frame came from the vertices; interpolated across a panel seen at an angle it isn't the pixel's own, so the copy slid and squashed against the real text. Now from SV_Position. REGPU_VR_GLASS_INTERPOLATED=1. Part of the glass was also missing at strong turns: clipped where the tilted panel left the depth range (not a depth fight: depth off did not help). Layers without depth now have z = w/2.
- Frame rate after all this, real headset, 5120, St Petersburg, third-person view: grid 90.0 / 0.0 twice; driving 90.0 / 0.1 and 88.9 / 3.3.
- False trails: one-row coloured dashes came from the simulator's window scaling (not in the game's window). "Cold cache" did not explain the missing road markings. Flash counts include moving scenery and HUD popups: look at the frames.

### Third round of Matt's test, 2026-11-07

- **Cockpit bounce, second go:** the first seat lock moved the view, so the world took the bounce instead ("still a lot of bouncing"). Now only the car's own draws move (shaders reading `(vc[20].`): the body exactly, its other parts by last frame's figure. Vertical movement of the dash against the camera: 12-97 px to 0-2 px of 800 (`bounce.py`, `dashtest.sh`).
- **Start-light glow moving with the head:** not a HUD sprite or a cube reflection. The car's glass (ps 97bbba1372ecfd4c) samples the resolved frame through itself (t11, 0D9B0000), by a clip position its vertex shader hands on unchanged (`v = max(rN.xyzw, rN.xyzw); o[`). It stayed the game camera's, so it read another part of the eye's image. VrPatch now passes that through `VrEyeClip`.
- **Race intro bands smeared:** the bands reach the screen corners with some vertices only, and the "full-screen quad stays over the whole view" rule stretched those out to the eye's corners. Any textured layer goes in the box whole (flag 2048).
- **Glass tint missing at an angle (depth clipping, not depth fighting):** a 2D layer without depth has z = w/2 in the box.
- **Rear-view mirrors white:** a 424x96 3D view through its own viewport (212,48 +212,-48), in the top left corner of colour base 0, pitch 1280, resolved to 10F7C000 (448x96), drawn on the car by ps 5a31243492041c37. As a pitch-1280 pass it went through the eye's matrices and landed elsewhere, leaving only sky in the corner copied out. `vrSmallView` in renderer.cpp: viewport smaller than the screen on both axes on a wide pass, not a HUD shader: one instance, no eye matrix, resolved as one image. REGPU_VR_SMALL_VIEW_STEREO=1 reverts. It also drops the second eye's cost of about 400 draws.
- Tools: `tintghost.py` (which shader changes a box of the picture), `tintcrop.py` (montage of that box per shader), `tintfind.py`, `mirrortest.sh`.

### 1% lows, 2026-11-07 (Matt: "They are the most important measure in VR")

My earlier "Grid holds 90; driving 88.9-89.9 with a few over-budget frames" was wrong: the same runs had 1% lows of 45-57 FPS and worst frames of 21-30 ms. Report the 1% low, worst frame and reprojected/s with every number.

All in-car, St Petersburg, 5120, real headset, 15 s windows:

| Change | Grid 1% low | Driving 1% low | Driving worst | Driving reprojected/s |
|---|---|---|---|---|
| Before, SteamVR auto throttling on | 55-85 | 44-45 | 28-38 ms | 4-13 |
| Matt turned SteamVR auto throttling off | 55 or 80 (see below) | 66-79 | 28-38 ms | 0.3-0.9 |
| + lens mask (no lock) | 80-83 | 75-77 | 25-37 ms | 0.3 |

Build 469a201 (lens mask, real clear), real headset, 5120, SteamVR auto throttling off, 15 s windows. Game-side 1% low / worst / SteamVR reprojected a second (doubled, mispresented of about 975 frames seen):

| Scene | Grid | Driving |
|---|---|---|
| St Petersburg chase | 80.1 / 14.9 ms / 0.4 | 76.3 / 39.0 ms / 0.5 (0, 0) |
| St Petersburg in-car | 79.1 / 17.1 ms / 0.5 | 75.4 / 35.0 ms / 0.5 (1, 4) |
| Tokyo night rain in-car | 81.5 / 13.2 ms / 0.0 | 56.3 / 35.2 ms / 1.7 (6, 16) |
| Tokyo night rain chase | 78.1 / 20.0 ms / 0.1 | 73.0 / 27.6 ms / 0.2 |
| Las Vegas cone sprint in-car | 74.6 / 17.2 ms / 0.1 | 58.7 / 34.9 ms / 1.0 (0, 2) |
| Las Vegas cone sprint chase | 79.3 / 14.8 ms / 0.4 | 56.2 / 34.1 ms / 0.7 (2, 5) |

Remaining hitches (40 s of St Petersburg driving, REGPU_VR_TRACE): 6 frames over 20 ms. The token is on time, the frame reaches its swap late (up to 18.6 ms after it): heavier stretches (draws a frame 1,700 -> 3,400, renderer 4 -> 8 ms). Not file reads (1 of 11 near one; NVMe). Locking the busy threads to their own cores: no difference over 4 pairs (an earlier "4 of 4" did not hold).

**Road markings, lit windows (fixed, a2ad111).** The dashes and the white edge band in St Petersburg, and the lit windows in Tokyo, are coplanar draws on the road or building ("greater or equal", same depth). Each translated shader is compiled on its own; through the eye's matrix (its depth row mixes in x and y) they came out a hair from the surface under them, so they were drawn or lost depending on the build. Early depth flipped them: St Petersburg lost every dash with it (bisected to one draw, #1020, vs cc6a3b68bbe23a30 ps 4e612461995aade5, the markings), Tokyo gained its windows. The "first run after the shaders changed" pattern was the early variant being ready or not. Fix: `precise` on the clip position and the eye's matrix in VrPatch. Early depth on and off then give the same picture (0 pixels differ in both cities, against 5605 and 90046) and St Petersburg matches flat. Frame rate unchanged (driving 0.5 and 1.1 reprojected/s). Ruled out on the way: the polygon offset (a multiplier from 0 to 64 changed nothing), the camera's field of view, the textures (same set as flat). Tools: `marktest.sh`, `earlyab.sh` + `eadiff.py`, `earlybisect.py` (needs a build with REGPU_EARLY_RANGE).

**What the remaining misses are not** (Tokyo night rain, in-car, driving, 30 s windows, real headset):
- Not GPU throughput: the whole frame at 2x2 shading (a test only) finished the GPU about 2 ms earlier and gave 0.3 and 1.2 reprojected/s against 0.3 and 0.6 without. So more GPU savings won't move the 1% low; the lens mask is kept for the headroom and power.
- Not thread priority: the game's swapping thread and the command processor at ABOVE_NORMAL: 0.1, 0.3, 1.0 reprojected/s against 0.9, 0.3, 0.8. Reverted.
- Of 41 late headset frames in one Tokyo run, 20 were the game's own frame reaching its swap after the token, 9 the GPU finishing late, 6 the command processor late. The game thread's time in slow frames is spread over ordinary game code; keyboard polling (about 20 GetAsyncKeyState a poll) is about 0.25 ms of it.
- Upload hashing: two 221,760-byte ranges (B53248B0, B52EE62C in the in-car view) are hashed in full about 235 times a frame each, about 100 MB a frame on the grid. REGPU_UPLOAD_SAMPLED=1 (unsafe, a measure only) took the renderer from 11.4-12.0 to 9.1-9.9 ms a frame. A safe version (hash in full at the first use in a frame, reuse while never seen changing within a frame) never took its reuse path, so those ranges change between draws or are used across threads; reverted. Not pursued further.
- The same settings give 0.1 to 1.7 reprojected/s from run to run: misses come in episodes. Compare with several runs each way.

- **SteamVR auto throttling** was most of it: one late frame then held xrWaitFrame at 22 ms for about 21 frames, with the game's frame already finished before the token. Other players will have this setting on: tell them, or find a way to ask for it.
- **Real clear:** ps 8c8b535864c59f02 vs 9862cfa7a2bc20ec, a full-surface rectangle right after the mirror, colour and depth in its vertices. `VrClearRect`, REGPU_VR_CLEAR_VS/PS, REGPU_VR_DRAWN_CLEARS=1 reverts. Same picture on a frozen race against a control (only the pause menu's animated highlight differs). Gain small: median frame 0.03-0.15 ms. **It does not move the 1% low: commit 1206092's "grid 54-56 to 82-83" was wrong**, those runs fell in the two grid modes below by chance. A retest with the same number of runs each way read the same.
- **Grid modes:** the grid's game-side 1% low is either about 55 or about 80, the same for a whole boot, on identical settings, scene and draw count. In the low mode there are 130-145 frames over 14 ms in 24 s, in the high mode 7. It comes in clusters over time and also appears free-running. Cause not found. Not thread placement: the same ideal processors gave both modes; a lock gave 5 of 6 high, then with no lock 4 of 4 were high as well.
- **The game-side 1% low overstates what is shown.** `vrperf.py` uses swap-to-swap times, which jitter (12 ms then 10 ms). At the same moment: grid game-side 1% low 81, SteamVR 0.3 reprojected/s, 0 of 778 frames doubled or mispresented; driving 75, 0.3, 0 doubled, 1 mispresented of 974. (`vrstats` sees about 65 of the 90 frames a second.) Quote both. 0.3/s is still a missed frame about every 3 s, and the isolated 25-37 ms hitches are real.
- **Lens mask:** XR_KHR_visibility_mask, 108 vertices an eye, 21.8% of the eye on Matt's headset. `VrLensMaskStamp`, nearest depth right after the frame's clear and again after the next tile's depth clear (without that the mask stopped at row 480 of 720). REGPU_VR_NO_LENS_MASK=1. Game-side 1% low +2 grid, +1.4 driving, but GPU power on the same scene, flipped live: 389 W against 420 W, so about 8% of real GPU work. Exposure unchanged (centre mean 34.340 against 34.341). The corners keep the clear colour (grey): ask Matt to look for it at the edge in fast head turns. The simulator gives no mask, so check it on SteamVR.
- **Free running:** with the headset switched off SteamVR stops pacing (xrWaitFrame 0 ms, `vrstats` shows presents = dropped = reprojected = about 190). Don't take pacing numbers then; they do show the headroom: 105-111 FPS at 5120, median 9.1 ms.
- **Long "passes" in REGPU_GPU_PASSES are mostly the GPU waiting for work**, not GPU cost (REGPU_GPU_LONG now prints the times lists reached the queue). A 42 ms pass was a gap between lists.
- **Tried, no gain, reverted or left off:** REGPU_SUBMIT_DRAWS 64/256 (64 worse on the grid); Debug.WaitForFence off (0x82A80B5C; the game's own wait after Present, about 6 ms a frame, but something else blocks in its place); waiting for the token after D3D's kick instead of in VdSwap (D3D kicks after VdSwap, sub_826CE8C0, so a finished frame waits unsent; moving the wait gave 1% lows of 56-61 against 76-78, so I reverted it. The frame's idle wait before the token, about 6.5 ms, absorbs small stalls of the game).
- The rear-view mirror's old stereo path is not faster than the one-image path. Seat lock off: 88.4/89.9 against 86.8/88.4 average before Matt's setting, two pairs, not settled.
- Tools: `simfps.sh` (simulator uncapped, SIMXR_HZ), `ppcfn.py` (a recompiled function's PowerPC), INCAR=1 and NOFENCE=1 in `hmdtest.sh`.
