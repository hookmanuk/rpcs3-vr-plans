# Uncharted: The Nathan Drake Collection (PS4): VR notes

Not RPCS3: Supermedo's Uncharted PC port (hookmanuk/uncharted_pc, the PS4 code natively, the bbport/shadPS4 Vulkan
renderer, the same lineage as the Driveclub recomp). Fork `H:\uncharted_pc`, branch `vr` from `full-release` 290ced0.
Matt's disc dump: `H:\ROMs\uncharted\CUSA02343` (EP9000-CUSA02343_00-UNCHARTEDTRILOGY, EU disc, APP_VER 01.00).
Three games in one port: U1 `eboot.bin`, U2 `big2-ps4_Shipping.elf`, U3 `big3-ps4_Shipping.elf` (camera hooks, HUD
detection and render sizes per game).

## Build

- `cd H:/uncharted_pc && env -u VULKAN_SDK bash build.sh` (MSYS2 CLANG64; ~1 min clean, `out\bb-probe.exe`).
- `VULKAN_SDK` must be unset: the machine's (1.4.341, RPCS3's) lacks VK_VALVE_shader_mixed_float_dot_product, which
  vk_instance.cpp uses; CMake then takes MSYS2's headers (1.4.363).
- The clone is `core.autocrlf=input` (LF working tree, as the index), and so is `gpu/third_party/fsr-vulkan`: build.sh
  applies `gpu/patches/fsr-vulkan/*.patch` with MSYS2's git, which failed on the CRLF checkout.
- Commit from the plain Git Bash shell, not after sourcing msys2-env.sh (MSYS2's git).
- Packaging: `bash packaging/windows/package.sh` (dist\uncharted-windows + zip). Still to add: `openxr_loader.dll`
  beside bb-probe.exe (Driveclub's stage-vr.sh took `F:\rpsc3\source\rpcs3\bin\openxr_loader.dll`) and its licence
  (packaging/windows/licenses/OpenXR-loader-Apache-2.0.txt is in).

## Stage 1: the VR layer (5613b65, 2026-10-23)

From hookmanuk/driveclub-recomp `vr` (ff03ea9): `renderer_vulkan/vr/` (vr_openxr, vr_camera, vr_stereo, vr_multiview,
vr_dev, vr_fixes, shaders), `emit_spirv_vr`, `third_party/openxr`, sirit's SpecConstantFalse, and the VR-tagged hooks
(30 upstream files, +177/-35 lines). Taken by extracting the VR-tagged hunks of the Driveclub fork's diff and applying
them 3-way; hunks that mixed in Driveclub's other work were reverted and redone by hand.

- Left out: the draw thread / pipe reads, readback hybrid, small writebacks, GDS fences, per-eye DLSS (vr_dlss,
  DriveAA/DriveMotion), object motion, the pacing credit and stall statistics, libcxx_compat.h (not needed here).
- Headset queue: Uncharted already makes a second graphics queue for its readback side queue when the GPU has no
  transfer-only family; `Vr::QueueCount(physical, family, used)` now asks for one more after the renderer's.
- Game-specific parts emptied: vr_camera `Sites` (no head tracking yet: the game shows on the flat screen), vr_fixes
  (no render/output size, no shader patches: multiview finds no main-view images and stays mono), ScreenAspect 16:9.
  vr_stereo only splits the display buffer (scene vs HUD) once `Camera::Near() > 0`, i.e. a camera hook fed a frame;
  without that gate it would clear the display buffer at the second draw after any 3+ target pass and leave the
  flat screen with the HUD only.
- Still Driveclub-specific inside the modules (inactive without a camera / BB_VR_STEREO=mv, to rework in stages 2-4):
  vr_multiview's sizes (1024x896 bloom copy, 4/15 bloom) and eye-light/scene-constant hashes, vr_stereo's 512-byte
  camera constants and Scaleform/overlay hashes, vr_dev's TAA hashes (0x403f86d4, 0xfdd72cf1), `%TEMP%\dcvr`.
- Built OK; not run yet (no game files).

## Next

1. With the dump: boot each game flat, then `BB_VR=1` with the simulator (launcher "extra environment" field takes
   `BB_VR=1 XR_RUNTIME_JSON=...`): the game on the flat screen in the headset; FPS flat and VR (DLSS off).
2. Stage 2: each game's render size (vr_fixes) and multiview (`BB_VR_STEREO=mv`): which passes are main-view, the
   scene-resolution proxies and the temporal upscaler (`vk_scene_resolution`, `vk_temporal_upscaler`) in stereo or off.
3. Stage 3: camera hooks per game (view/projection setters; the camera constants the G-buffer reads).
4. Stage 4: the HUD on its own layer (where each game's HUD starts drawing into the display buffer).
5. Stage 2 must make the render size follow BB_VR_EYE_RES (the launcher row exists; the games render 1920x1080 fixed).

## Launcher (95ed363, 2026-10-23)

- Display page, first card "VR": "Play in a VR headset (OpenXR)" (setting `vr`): `BB_VR=1`, `BB_FRAME_GEN=off`
  (`vr_environment`). Checked: flat env has no BB_VR and keeps its frame generation; screenshot of the page fine.
- Updates: `RELEASES_API` = hookmanuk/uncharted_pc's release list; `vr_release` takes the newest non-draft,
  non-prerelease tag containing `-vr`. VERSION `0.3.6-vr0.1`; tags `v<base>-vr<n>` compare by their digits
  (v0.3.6-vr1.0 > 0.3.6-vr0.1). No VR release exists yet: the check reports "no VR release yet".
- package.sh: `openxr_loader.dll` into `bin/` beside bb-probe.exe (`OPENXR_LOADER`, default RPCS3's copy).
- Matt 2026-10-23 "Add VR resolutions too": "Resolution per eye" row (`vr_eye_size`, 1080/1600/2160/2560/2880/3200/
  3584/3840/4320, default 2880) -> `BB_VR_EYE_RES` (vr_multiview's cache suffix reads it already). No effect until
  stage 2: the flat screen shows the games' 1920x1080 display buffer.
- Settings are shared with a flat install (APPDATA/uncharted-launcher); the flat launcher ignores `vr`.

## Uncharted 1 in stereo (64f62b4, 2026-10-23)

Matt: "Just get 1 working properly first." (U2/U3 untouched.)

- Test route (tools/drive.py, pad file): a test save in `out/try/user` (backed up in the session scratchpad; restored
  before each run) at the "Ambushed" checkpoint: language, Press, Start Drake's Fortune, Press, Continue, OK (Friend
  Stats), ~100 s from boot. The enemies kill Drake after ~30-60 s: check in the first seconds; the moment the load
  lands on varies between runs. Skipping the opening movie by pad (Options, down, down, cross) drops presses.
- Camera: the render camera object is image +0xa86b30 (position, quaternion, FOV 75 deg at +0x20; its view at +0x30:
  camera-to-world input +0x250..+0x280, aspect +0x290, x scale +0x294, near 0.24 +0x298, far 5000 +0x29c; outputs
  +0x10 camera to world, +0x50 view, +0x90 projection (P00 -1.3032: x mirrored), +0xd0 view-projection). The views'
  projection update is +0x2c8dd0 (calls the matrix builder +0x2c9070); the camera update calls it at +0xa7178.
  Found: projection values from the velocity pass (ps 0xf4b18264: camera-relative constants, c1 = -1.3032, 2.3168)
  -> memory scan -> the image's data -> write watch -> the builder -> xrefs (tools/vr). The image moves between runs
  (0x0af00000, 0x0ab00000, 0x0b900000): the hook finds it by its bytes.
- Hook: head x camera on the input (axes C = diag(-1, 1, -1)), the headset's FOV as symmetric aspect / x scale.
  Simulator: yaw +-20 and pitch 10 turn the rendered view the right way (roll not checked yet).
- Stereo: multiview (BB_VR_STEREO=mv) with the render size 1920x1080 for the two-layer images; the stereo capture takes
  the scene at the second display-buffer draw (vs 0xf585649d composites, the HUD follows: vs 0xfadcd6fe), the depth from
  single-target draws (U1 has no multi-target G-buffer). The display buffer is RGBA (VkFormat 43): the eye and HUD
  swapchains are made RGBA (red and blue were swapped).
- The port's temporal upscaler must be off in VR (BB_UPSCALER=off; the launcher does it): with it the presenter's
  upscaled path skips the HUD capture, and it works on one eye with jitter. The HUD layer shows (1.4 m wide, 1.1 m).
- Frame rates (simulator, 2880x2880 eyes, the checkpoint, upscaler and DLSS off): flat uncapped 218 FPS, p99 8.7 ms
  (1% low ~115); VR flat screen uncapped 215, 1% low 107; VR stereo at 90 Hz 90.0 FPS, 1% low 83-85, 0-0.44% over a
  period, 0% late; stereo uncapped 158-175 FPS, 1% low 95-100.
- Audit (BB_VR_AUDIT=1): the 2048x2048 shadow map one layer (fine), the 32x32 / 16x16 luminance chain left eye only,
  compute 0xaec539f0 writes a 0x870 buffer from the left eye that 0x8d3c1baa / 0x38d8bf05 read for both eyes.
- Open: once the right eye showed blocky orange light streaks on the burning cabin that the left eye lacked; not
  reproduced in later loads (different moments). Needs a deterministic scene (a checkpoint without enemies). TV gamma
  (Driveclub's default, on) applies to the eyes: flat Uncharted has none. Render size 1920x1080 for a ~square FOV
  (non-square pixels); BB_RENDER_RES for a square per-eye size untried. HUD size and distance to tune. Roll check.
  Matt's headset test.

## Matt's first headset test and the night after (2026-10-23/24)

Matt: "The fps needs tying to the refresh rate of the HMD. There is a lot of judder whilst turning my head. The
resolution needs to be changeable. DLSS needs to work in VR. The VR app is called Driveclub VR, it should be Uncharted
VR. This all needs optimising as much as possible. Once all that is done implement uncharted 2 & 3." Then: "keep going
all night, dont ask anything."

- Name: the OpenXR application is "Uncharted VR" (55ca3e7).
- Judder: the layer took the camera hook's latest pose while the frame shown was rendered ~6 frames earlier. Frame
  tags (55ca3e7): the hook adds k * 2e-5 (k = 1..63) to the view's near plane (+0x298); the shaders get half of it, and
  the velocity pass's float 9 (z = c9 / (depth - c8): -(n/2) f / (f - n/2)) is read where the port reads those
  constants (CameraMotion::OnVelocityConstants, a one-line hook): 1771 of 1800 frames find their pose. Reading the
  constants from guest memory at OnDraw gave later frames' data (ring reuse): use the prepared draw's copy.
- Pacing: launcher VR runs the game unpaced (BB_VBLANK_HZ=240); the adaptive cap holds one flip per headset frame from
  103% of the headset rate (was 112%), released below 93%.
- Resolution (41e4126, scripts/vr_resolution.py, run.py): loader patches (BBPATCH2) checked against eboot.elf:
  display configuration initialisers (+0x3c4d60/+0x3c5050/+0x3c5300, config +0xd5c2fc: fields +0x08 (the render size:
  without it the picture is mis-scaled), +0x18, +0x24, +0x38 sizes, +0x20/+0x2c aspects, +0x30 2560x1216, +0x40
  240x270 scaled); render target heaps (arena table +0x971d10.., 32-byte entries id/context/size/align: 0x84 at
  +0x9721d8 140 MB, 0x85 at +0x9721f8 497 MB) grown with the pixel count; the GPU context (+0x9713f8, 2988 MB,
  kAllocAppGpu: the game checks its arenas add up) and the system context (movabs +0xcb, 4.5 GB) grown by the same,
  in whole 2 MB (asserts at +0x36a430 / +0x36a8c3); BB_DMEM_MB raised. Limits: the GPU context must stay below 4 GB
  ("GPU Mem" arena size kept in 32 bits: 5028 MB became 932 MB); the spare arena 0xe (209 MB) must stay (context 7's
  arenas, 320 MB, are carved from it). 2560 runs, 2880 is short of render target memory: run.py clamps to 2560.
  The boot-time language screen is garbled at square sizes (a 1920x1080 video into a square buffer?); menus after it
  are fine. HUD and menus lay themselves out for the square canvas.
- DLSS (c886997): DLAA per eye (vr_upscale.h: the upscaler's views on the eye's layer, a DLSS feature per eye via
  bridge ABI 3 from the Driveclub fork, the result back into the layer); only DLSS in stereo. The scene detection's
  1920x1080 became Fixes::NativeSize. Bridge built with VS 2026: cmake -G "Visual Studio 18 2026" -A x64
  -DDLSS_SDK_ROOT=F:/rpsc3/source/DLSS -DVULKAN_INCLUDE=<out/vkinclude>; DLLs copied beside out/bb-probe.exe.
  Upscaling above the native size would need the port's scene proxies in stereo (not done).
- Frame rates (simulator, "Ambushed" checkpoint): 90 Hz, 2160 / 2400 / 2560 per eye: 90.0 FPS, 1% low 83-85, 0%
  late; 2160 + DLSS 90.0, 1% low 79. Uncapped 2160: 168-172 FPS (DLSS 140-145), 1% low 93-99; GPU 95% busy at 142 FPS
  (RTX 5090): GPU-bound uncapped.

## Uncharted 2 and 3, pacing, movies (2026-10-24, overnight)

- Uncharted 2 (big2-ps4_Shipping.elf, e3eecb8 / f97d48f): U1's view with fields 0x40 lower (input +0x210, aspect / x
  scale / near / far +0x250), built at image +0x3e2c50; the render views are per-frame copies from the call returning
  to +0x61194f (shadow cascades too: those have x scale 0 or near >= 1, skipped). The shaders get the near plane as it
  is (U1: half). Frames without a HUD (the train) are captured at the flip (CaptureAtFlip). Eye sizes: the same
  configuration initialisers at +0x5525da/+0x5528c8/+0x552b7e, arenas 0x84/0x85 at +0xe6bd30/+0xe6bd50, GPU context
  +0xe6af50 (2988 MB). The camera's image search no longer gives up after 3600 frames (U2's boot flips hundreds a
  second unpaced: the hook was never installed in one run).
- Uncharted 3 (big3-ps4_Shipping.elf, 8cc211c): U2's builder at +0x80a2f0 (tools/vr/view_find.py: vblendps of the
  position with three vandps rows before it), the render views from the call at +0x5b153a (tools/vr/callers.py; the
  same code around it as U2's +0x61194a). Tables in the RELRO segment: arenas 0x84 140 MB at +0x13aad20, 0x85 561 MB
  at +0x13aad40, spare 0xe; GPU context 3052 MB at +0x13a9f00 (1042 MB below the 4 GB limit: 2560 per eye is at the
  limit and runs). 1800 of 1800 frames find their rendered pose (shader near = the view's).
- Pacing (8cc211c): a flip held for the headset waited for the next 240 Hz vblank tick (0-4.2 ms after the headset's
  frame began). The vblank thread now wakes on the headset's frame while capped (Vr::WaitForHeadsetFrame, one call in
  videoout/driver.cpp; BB_VR_TOKEN_WAKE=0 is the old way). U2 + DLSS 2160 at 90 Hz, A/B: frames over a period 10-14%
  -> 3.6-4.7%, 1% low 75-77 -> 79-80, late 0% both.
- Movies (50b0153): the collection plays its movies (all prerendered cutscenes, the intros, U1's language screen)
  through compute 0xc85d9816 (NV12 to the display buffer). The game builds its luma/chroma descriptors from the
  display configuration: at a square eye size 2160x2160 pitch 2176 with the chroma at luma + 2176*2160, while the
  decoder writes 1920x1080 at pitch 1920, the chroma at + 1920*1088, in 4 MB buffers (green stripes). The decoder notes
  each frame's layout (Vr::Fixes::NoteMovieFrame, one call in videodec2_impl.cpp); at the dispatch the pair (R8 then
  R8G8 right after it, in a decoder buffer) gets the decoded layout (Fixes::FixMovieImages). The shader copies texels,
  so the movie fills the display buffer's top left: the headset shows that region on the screen at 16:9 (not stereo).
- U3's fight prompts (6179eb3): after its HUD U3 copies the display buffer out and back (0x6bda / 0x74a15). That
  second run of display draws was captured again at the flip, with the first layer still cleared for the HUD: the
  left eye black whenever a HUD showed. One capture per frame now.
- U3 test save: scratchpad savedata_backup3 (a new game's autosave: Continue goes to the pub fight, "Press [] to
  attack", the scene holds). Route: wait 50, cross x5 6 s apart.
- Frame rates (simulator, DLSS off unless named):
  - U2 train 2160: 90 Hz 90.0 FPS, 1% low 84-85, over a period 0-0.2%; DLSS 90.0, 1% low 79-80, 2.4-4.7% over.
    Uncapped: 193-195 (1% low 96-100); DLSS 152 (1% low 91-94).
  - U3 pub 2160: 90 Hz 90.0 FPS, 1% low 83, 0.4-0.7% over; uncapped 162-164 (1% low 88); DLSS uncapped 166 (1% low
    96-98). 2560 + DLSS at 90 Hz: 90.0, 1% low 76-78, 8-12% over.
- Run-ahead (2c5f96b): the game renders one frame ahead of the headset (two flips banked while capped; the headset
  shows the newest finished frame, so it no longer waits up to 2.8 ms for the GPU). 2560 + DLSS at 90 Hz, A/B x2 on
  U3: frames over a period 5.8-8.4% -> 0-0.7%, 1% low 76-80 -> 82-84; U2 0-0.7% (1% low 84-85), U1 0-2% (80-85).
  1800 of 1800 frames keep their rendered pose. BB_VR_AHEAD=0: the old way.
- U3 at 2560 (heaps at the 4 GB context limit) runs; uncapped 167 (DLSS 139), the same as 2160 without DLSS: the
  game's CPU side bounds it.
- U3's menu desert: the menu uses the gameplay view (x scale 1.303, near 0.24, far 5000; with BB_VR_HEAD=0 its input
  is identity like gameplay's), so it is head-tracked; the flat yellow lower half is ground below the game's 16:9
  frame that the headset's taller view uncovers (cosmetic, menus only). A second view passes the filter in both menu
  and gameplay (x scale 1.0, near 0.1, far 100) and is head-tracked too; nothing wrong seen from it.
- Head poses (simpose.py: 0, yaw +-20, pitch 10, roll 15): U2 train and U3 pub follow the head; U3's prompt stays in
  its world-fixed box, whole.
- Open: U3's main menu (a 3D desert) renders in stereo with a flat yellow lower half; U3 + DLSS stopped presenting
  once near a frame-dump screenshot (not again in a rerun); U1 one-off right-eye light artifact; TV gamma default; HUD
  size; head-pose checks (yaw/pitch/roll) for U2 and U3.
