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
| 1. FG device/instance extensions, capability check and log, setting | |
| 2. Per-eye feature creation and evaluation into interpolated images (debug: show only generated frames) | |
| 3. OpenXR generated-slot queue, midpoint pose, ordered presentation | |
| 4. Simulator checks (motion, head turns, HUD), FPS and late frames at 45 -> 90 | |
| 5. Headset (Matt) | |
