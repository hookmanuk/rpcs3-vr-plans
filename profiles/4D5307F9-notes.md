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
