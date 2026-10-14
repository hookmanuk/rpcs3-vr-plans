# DLSS Frame Generation in VR (branch `framegen`)

Started 2026-10-13 at Matt's request: NVIDIA DLSS Frame Generation (NGX DLSS-G, Vulkan) inside the fork, so a game
that holds 45 FPS shows 90 new frames a second in the headset. OFXR-Bridge's native DLSS-G cannot do it for RPCS3: it
captures DLSS "guides" only by hooking D3D12 NGX calls (`NVSDK_NGX_D3D12_EvaluateFeature`), and its guide publication
API takes D3D12 resources and an OptiScaler identity (status "No DLSS guides from this game yet").

Branch `framegen` of `rpcs3/` (from `openxr` 0eb6a05f5). Fork files only, as for DLSS: a new `VK/VKFrameGen.{h,cpp}`
(added through `buildfiles/msvc/dlss.props`), calls from the DLSS context and the OpenXR frame thread.

## What the SDK gives (DLSS SDK 310.9.1, `F:\rpsc3\source\DLSS`)

- `nvsdk_ngx_helpers_dlssg_vk.h`: `NGX_VK_CREATE_DLSSG`, `NGX_VK_EVALUATE_DLSSG`; runtime `nvngx_dlssg.dll` (lib rel/dev).
- Guide: `DLSS-FG Programming Guide.pdf` (text: session scratchpad `dlssg_guide.txt`). RTX 40+ (MFG RTX 50+).
- Support: after init, capability parameters `NVSDK_NGX_Parameter_FrameGeneration_Available`,
  `NVSDK_NGX_DLSSG_Parameter_MultiFrameCountMax`; before init `NVSDK_NGX_VULKAN_GetFeatureRequirements` and
  `..._GetFeatureDevice/InstanceExtensionRequirements` with `NVSDK_NGX_Feature_FrameGeneration` (= 11).
- Create: output (backbuffer) width/height and format, render width/height (DLSS input size); one feature per eye.
- Evaluate (once per real frame for 2x): inputs backbuffer (final colour, the image that would be presented), depth
  (hardware depth, `depthInverted` flag), motion vectors (current to previous, pixels, `mvecScale`), optional HUD-less
  colour and UI; output interpolated frame (same size and format as the backbuffer). Engine data: `reset`,
  clip-to-prev-clip and back, view-to-clip and back, camera position / up / right / forward, near / far, FOV, aspect.
  Costs ~1.1-1.7 ms per evaluation on a 5090 (1080p-4K).

## Design

1. **Inputs come from the DLSS context** (`VKDLSS`), so Frame Generation needs DLSS (any NGX mode, DLAA included) on at
   boot: per eye it already has the resolved motion vectors (RG32F, UV units) and depth (R32F, 1 - window depth) at
   render size, the DLSS output, the HUD-less image (the HUD outside DLSS) and a camera matrix history per eye.
2. **Evaluate at the VR flip**, after DLSS and the HUD composite, before `publish_eyes`: per eye, backbuffer = the final
   eye image, HUD-less = the DLSS output before the HUD composite, depth / motion = DLSS's inputs. Output: an
   interpolated image per eye (frame N - 0.5). The first frame after a reset (boot, fixed-screen switch, history reset)
   generates nothing.
3. **Present in order on the OpenXR frame thread**: per game frame, the generated pair, then the real pair, on
   consecutive headset frames. Today the thread shows only the newest committed slot (a second commit in one flip would
   replace the generated one), so `VKOpenXR` gets a pending generated slot: `commit_eyes` for the generated pair with a
   pose halfway between the previous and current real frames (slerp orientation, lerp eye positions), the real pair
   committed behind it; the thread presents the generated slot first and the real one on the next `xrWaitFrame`
   without waiting for a new commit. Slots grow from 3 to 5. Latency: +1 headset frame (11 ms at 90 Hz).
4. **Game rate**: the game runs at half the headset rate (VR Frame Rate 45 at 90 Hz); the headset sees 90.
5. **Setting**: Video > VR > DLSS Frame Generation (Off / 2x; MFG later), read at boot (NGX's FG extensions and the
   features), shown only with DLSS available; home menu live toggle once the boot path works.

## Stages

| Stage | Status |
|---|---|
| 1. FG device/instance extensions, capability check and log, setting | done (`c07a78a9a`): setting `Video/VR/DLSS Frame Generation (experimental)` (config file only, no UI yet) or `RPCS3_DLSSG=1`; NGX on Vulkan accepts it (5090: up to 5 generated frames) |
| 2. Per-eye feature creation and evaluation into interpolated images (debug: show only generated frames) | done; `RPCS3_DLSSG_ONLY=1` shows only generated frames (`68a137d28`) |
| 3. OpenXR generated-slot queue, midpoint pose, ordered presentation | done; the frame thread logs "N of M headset frames showed a generated pair" every 5 s |
| 4. Simulator checks (motion, head turns, HUD), FPS and late frames at 45 -> 90 | partly, see below; head turns with simpose not yet checked |
| 5. Headset (Matt) | Uncharted 2026-10-13: "looks like it might work", but the game's own rate is too low for 90 |

## Simulator results (2026-10-13, VR Frame Rate 45, DLSS on, 16 s windows)

| Game (state) | Game FPS FG off -> on | Headset frames generated | Generated frames |
|---|---|---|---|
| Uncharted (`BCUS98103_1_0` combat, 300%, Performance E) | 45.0 -> 43.4 median (dips to 37) | 216 of 433 per 5 s (~87 Hz) | coherent in a camera spin; clouds/sky smeared, a faint mast ghost in the right eye |
| MotorStorm PR (`vrtest_mspr_race`, 350%, Quality) | 45.0 -> 45.0 | 225 of 450 (90 Hz) | car and track fine; HUD timer blurred (no HUD-less input yet). Race-start brightness pulses are the game's (control run the same) |
| Journey (`vrtest_journey_dune`, 300%, Quality) | 45.0 -> 44.9 | ~2x (static scene) | identical to the real frame when still |
| Jak 3 (`vrtest_jak3_spargus`, 300%, Quality) | 44.9 -> 44.8 | 224 of 448 | clean (lava blobs, platforms) |
| Killzone 2 (`vrtest_kz2_carrier`) | 45 | none | DLSS never finds the scene's camera draws ("camera draws 0"), so no FG input: a DLSS issue |

FG needs a game that holds 45 solidly: a dip below 45 leaves a headset frame without a new picture. Matt's configs for
MotorStorm, Journey and the Jak collection were set to Frame Rate 45 + DLSS Quality + FG for him to try (backups
`config_<ID>.yml.pre-framegen.bak`); Uncharted's has FG on top of its own settings.

Next: HUD-less input (`hud_pre`) so HUDs stop smearing; head-turn check of the midpoint pose; 3x (MFG) after Matt's 2x
verdict; a UI setting.

## 2026-10-13 evening: pacing, ghosting (fork ef6e9d0cc, 9edb53d07, 2c9ad1325)

- **Pacing** (Matt, GT5: no longer 90 when the frame time rose): the frame thread waited for each commit and then for the
  flip's GPU work (render, DLSS, DLSS-G x2), so any game frame whose GPU work ran past one headset frame lost a headset
  frame. Now, while frame generation is active, it runs every headset frame and never waits: a queue (3 deep) holds the
  generated and real pairs in order, the oldest is shown once its fence has signalled, otherwise the last frame again
  (no acquire: the runtime keeps the last released image). MotorStorm: 225 generated + 226 real per 5 s, 0 repeats.
- **`motionVectorsInvalidValue` was 0**: every still pixel counted as invalid. Now FLT_MAX.
- **Ghosting on MotorStorm's car in motion (gone when paused)**: the motion debug view shows the car with the world's
  motion (it should be ~0 under the chase camera): its vertices are not moved by the matrices the DLSS context tracks
  (built on the SPU). DLSS-G with every vector marked invalid (its own motion estimate) was "much better" (Matt,
  headset) and is the default; `RPCS3_DLSSG_MV=game` or `%TEMP%/rpcs3-vrprofile/DLSSG_MV_GAME` (`bin/dlssg_mv_game.cmd` /
  `dlssg_mv_own.cmd`, live) give the game's vectors back. Possible later: game vectors where a depth check says the
  pixel is static world, invalid only on objects that move by themselves.
- Dev: `RPCS3_DLSSG_ONLY=2` puts the left eye's generated frame left and its real frame right (one capture compares them).
- Open: random "black shadow" flashes (Matt) not found in captures yet; HUD smear (no HUD-less input).

## 2026-10-13 night: hybrid motion, settings, half rate (fork a78002bb4)

- DLSS-G's own estimate ghosted every car on head turns (Matt); the game's vectors ghosted his car. **Hybrid** (default):
  the motion image's coverage channel carries each draw's depth ratio k = R's w / p's w (0 = not covered); a check pass
  (`dlss_framegen_check_pass`, VKDLSS) marks a vector invalid where last frame's depth at p + mv is not what a static
  point would have had (1 - z ~ n / w; tolerance 4 %, `RPCS3_DLSSG_DEPTH_TOLERANCE`). Matt: "looks good".
- Settings: VR > **DLSS Frame Generation (experimental)** (checkbox, at boot) and **DLSS Frame Generation Motion**
  (Hybrid / Game; live, also in the home menu). Dev switches remain (`RPCS3_DLSSG_MV=hybrid|own|game`, files).
- While frame generation runs, the game renders at **half the VR Frame Rate** (90 -> 45; Unlimited -> half the headset
  refresh), from the first DLSS-G feature on (`rsx::vr::set_framegen_active`). Matt's frame-gen configs moved 45 -> 90.
- MotorStorm's random black ground patches (Matt: with DLSS on, also without frame generation): DLSS's jitter (gone with
  `RPCS3_DLSS_JITTER_SCALE=0`). New profile key `dlss_jitter` (0..1), 0 for BCUS98155. The pass that breaks under jitter is
  not identified (blocky edges: likely a low-resolution pass upsampled against depth).

## 2026-10-13 late: settings live, HUD at the halfway pose, sharpening (fork 64edf9fc4 .. b2d9dcea1)

- **Live on/off**: the setting was read once per RPCS3 run (unticking did nothing until a restart). The context and its
  Vulkan extensions now exist whenever DLSS is on at boot; the checkbox (settings tab and home menu) works live, and
  turning it or DLSS off puts the game back at the full VR rate.
- Head-turn fallback to the game's vectors (7696ca2db) tried and reverted: Matt, hybrid is better all round.
- **HUD**: DLSS-G's HUD-less input kept the world-fixed HUD box in place on head turns (worse). Now DLSS-G generates
  from DLSS's output before the HUD composite, and the frame's HUD is composited onto each generated eye through the
  rotation homography from the frame's pose to the halfway pose (`render_pose_halfway_homography`). Matt: "great".
- **DLSS Sharpening** (VR, 0..100, default 0, live): RCAS on each fresh DLSS output before the HUD and frame generation,
  at 4x the FSR CAS slider's strength (0..-2 stops). The CAS slider never reached the headset (desktop FSR only).
- Crash found on the way: a new image copied into before any layout change returned to UNDEFINED ("Attempted to
  transition to an invalid layout"); new images now get a layout first.

Status: stages 1-4 done on the simulator; Matt's headset: MotorStorm 45 -> 90 good, GT5 "sort of works" (fixed pacing
since). Open: 3x (MFG), cost measurements (sharpening ~0.2 ms estimated, DLSS-G per eye), merge into openxr.

## Parked (Matt, 2026-10-14): external OpenXR frame-generation layers (OFXR)

OFXR halves the app's rate through `xrWaitFrame` (a doubled `predictedDisplayPeriod`). Only our OpenXR frame thread waits
there; the game's rate comes from the frame limiter (Unlimited: `XR_FB_display_refresh_rate`, else the configured vblank), so
the game keeps 90 and Matt sets 45 by hand. We ignore the predicted period on purpose (`VKOpenXR.cpp`: SteamVR halves it
whenever the app runs late, and following it spirals the game down). Possible fix, not started: an opt-in VR Frame Rate choice
that follows the predicted period, smoothed and snapped to exact divisors of the refresh. Nothing to send to the OFXR dev.

## 2026-10-14: GT5 cars smeared on head turns (fork, DLSS motion)

Matt (headset, SteamVR mirror, Motion Smoothing off): with frame generation the cars smeared on head turns, more the faster,
even paused; the background stayed sharp. Cause: draws that fall back on "the camera's motion" (the most common motion among
paired draws) lost the head turn. The main view's motions split by float rounding into several votes and the rear-view mirror
(~290 draws in a 448x86 inset with its own camera) won; and GT5's cars (vertex data rebuilt every frame, shared meshes, triangle
counts changing with the view) fell back for half their draws or paired with another car by draw order.
Fix: votes merge motions within 0.2 % and come only from draws covering a quarter of the target; profile `dlss_pair_nearest`
(GT5) pairs an address miss with the previous matrix nearest to where this frame's camera motion puts it.

How it was found (tools): `tools/re/headturn.py` (simulator real head pose with a neck pivot), `RPCS3_DLSSG_ONLY=2` (the left
eye's generated frame next to its real frame, full-size capture: showed the smear in our output), `RPCS3_DLSS_SEQ` with motion
vectors and `mvcheck.py`/`mvcheck2.py` (block motion vs vectors, the latter coarse-to-fine for +-192 px), and the decisive one:
dev `RPCS3_DLSS_STATIC_CHECK=1` (paused scene: every draw's motion must equal the camera's; per program, by pairing kind, plus
the vote clusters). Car draws wrong after the fix: 0 of ~50,500. Sonic (same-run A/B of the vote): no regression (62 vs 72 bad
blocks a frame).

Tried as the default for every game (Matt: "Add it as default with an opt out if it works well"): same-run A/B
(`RPCS3_DLSS_PAIR=alt`, nearest on even frames, draw order on odd; `tools/re/mvcheck.py` + `parity3.py`, 300 %, throttle and a
+-8 deg head sweep): Sonic 76.8 vs 44.3 bad blocks a frame, MotorStorm 105.2 vs 104.8, SEGA Rally 356.1 vs 337.7. Worse or no
better outside GT5: `dlss_pair_nearest` stays a per-game key (GT5). The vote fix (main view only, merged motions) is generic.

## 2026-10-14: rate conversion, 60 -> 90 (Matt's request)

**Rule.** Frame generation on and a VR Frame Rate below the headset's refresh (60 on 90 Hz): the game keeps that rate
(`rsx::vr::framegen_rate_conversion`; at or above the refresh the old 1/multiplier rule applies). The refresh comes from
`XR_FB_display_refresh_rate` or, without it (SteamVR, the simulator), the shortest `predictedDisplayPeriod` over 2 s
(`set_headset_cadence`, used only here). Ratio game : display reduced (60:90 = 2:3); one pair's frames lie on a 1/display grid,
so display - 1 generated frames per pair must fit DLSS-G (3x: RTX 50) and our two outputs, else no conversion.

**Schedule** (`framegen_on_flip`): headset frame j shows game moment j * game / display, counted from the flip count (not
from when the flips came). 60 -> 90 alternates "the 2/3 frame" and "the 1/3 frame, then the real frame"; every other real
frame is committed (its pose feeds the next generated frames) but not queued (`commit_eyes(..., shown=false)`). Each
generated pair is declared at its own phase (pose slerp and HUD homography at index / 3).

**DLSS-G multi-frame needs every index every frame.** Measured with the new dev dump `RPCS3_DLSSG_PHASE` (file request
"x y w h flips": the left eye's real input and each evaluated index as raw RGBA8) and `tools/re/fgphase.py` (block matching
against r(n-2), r(n-1), r(n); t = 0 at the last real frame, 1 at this one), MotorStorm `vrtest_mspr_race` driving, 60 FPS:

| Calls per flip | 1/3 frame t | 2/3 frame t |
|---|---|---|
| only the index shown (2 / 1 alternating) | -0.30 | -0.70 |
| same + `DLSSG.BackbufferFrameID` | -0.30 | -0.70 |
| 1..index shown (1 / 1+2 alternating) | -0.31, index 1 on "1+2" flips -1.3 | -0.67 |
| **1 and 2 every flip (shipped)** | **+0.33** | **+0.67** |
| control: 2x at VR 90 (game 45) | +0.50 | |

Only the constant call pattern gives frames between the last real frame and this one. Cost: 4 evaluations per game frame
(2 per eye), versus 2 for the sparse attempt (which held 60 but showed wrong frames).

**Results, simulator 90 Hz, Matt's MotorStorm config (DLSS Performance, Hybrid), RSX thread ms/frame median:**

| Setting | FPS | headset frames generated / repeated per 5 s | RSX ms |
|---|---|---|---|
| 300 % (eyes 3840x4320), FG off, VR 60 | 60.0 | - | 10.9 |
| 300 %, rate conversion (4 evaluations) | 51-58 | 253-300 / 2-70 of 451 | 17.0 |
| 200 % (eyes 3200x2880), rate conversion | 60.0 | 300-301 / 0-1 of 451 | 13.2 |
| 300 %, 2x at VR 90 (game 45, 2 evaluations) | 45.0 | 225 / 0 | 14.9 |

Each DLSS-G evaluation at 3840x4320 costs ~1.5 ms (13.8 ms with 2, 17.0 with 4, 10.9 with none), so at 300 % the four push
a 10.9 ms frame past 16.7 ms although the game alone reaches 72+. At 200 % it holds 60 -> 90 with no repeats. Open: Matt's
headset check; head turns (simpose) and HUD at the 1/3 and 2/3 poses; a game dropping below 60 (repeats, no re-phasing).

Cost is GPU (2026-10-14, 300 %, VR 60, `nvidia-smi` utilisation while driving + `RPCS3_VR_GPUPROF`): frame generation off
64 % (max 75 %), 60 FPS; rate conversion 94 % (max 97 %), 55-57 FPS. The RSX thread's CPU time rises (13 -> 19 ms/frame), all of
it in the "textures" bucket (2.2 -> 8.5-11.4 ms): the thread waiting on a saturated GPU, not CPU work (the same calls at 200 %
hold 60).

## 2026-10-14: NVIDIA's Frame Generation "Preset C" (FG Lite)

NVIDIA App beta (2026-10-13): Frame Generation Preset C, "a faster and lighter algorithm" (up to 35 % on an RTX 5060), set in
the App's DLSS Override > Model Presets. Not in our SDK (1.5 headers: presets only for Super Resolution / Ray Reconstruction).
The App downloaded `ProgramData\NVIDIA\NGX\models\dlssg\versions\20318480\files\160_E658700.bin` (2026-10-13 21:29): an
`nvngx_dlssg.dll` 310.9.16 "nvapp_override" build with a new kernel `Kernel_BlendCandidatesFGLite` and
`EndpointConfiguration::ApplyRenderPreset`. Copied over `bin\nvngx_dlssg.dll` it loads and runs in RPCS3 (same FPS, no preset).
- How the preset is chosen: not an NGX parameter. Setting `DLSSG.LiteCandidateBlendingEnabled` as one changed nothing (removed);
  that name sits with the DLL's registry overrides (`EndpointConfiguration::ReadRegkeys`, HKLM `...\Global\NGXCore`). The
  preset ID most likely comes from driver profile key `0x10E41DF1` (read by `DLSSGDRSKeys`, both builds; 310.9.1 logs
  "Preset ID", "Preset A/B selected" there), which the App writes. RPCS3 has no driver profile (`drsProfileName` empty).
- Both routes (driver profile, HKLM) need admin; untested. To try: 310.9.16 DLL in bin, then Preset C via the App's Global
  Settings or `0x10E41DF1` = 3 on an rpcs3.exe profile (Profile Inspector), and check with `RPCS3_NGX_LOG=1` for
  "Applying settings for render preset". Copy the DLL after the last build: `buildfiles/msvc/dlss.props` (CopyDlssRuntime)
  copies the SDK's `libWindows_x86_64el
vngx_dlss*.dll` into bin after every build (it put 310.9.1 back here).
