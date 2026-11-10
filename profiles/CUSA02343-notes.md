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

- Uncharted 2 (big2-ps4_Shipping.elf, e3eecb8 / c671380): U1's view with fields 0x40 lower (input +0x210, aspect / x
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
- TV gamma off by default (66f8012): Driveclub's 2.4/2.2 power made the eyes darker than the flat game (the port's
  presenter has none); now the eye matches the flat frame (U2 train: mean 104.3 vs 104.4). BB_VR_TV_GAMMA=2.4 on.
- run.py (dc286ca): eye-size tables by executable name (a game dumped alone as eboot.bin), BB_DMEM_MB recomputed per
  game after a loadexec switch. Checked: run.py boots U3 in VR with 48 patches.
- 2880 per eye: U3 also runs out of render target memory (HeapArena::Allocate: out of memory); the 2560 clamp stays.
  The limit is the GPU context's 4 GB ("GPU Mem" allocator object built at U1 +0x36e758; its size is set at run time).
  Context 3 is exactly its arenas (U3: 0x17, 0x83 254 MB, 0x84/0x85 render targets, 0x86 1260 MB, 0x87 368, 0x88 256,
  spare 0xe 209): lending 0x86 (likely the loading heap) to the render targets is untested and risky.
- Soak: U3 2560 + DLSS at 90 Hz, 49 reports (~8 min): 90.0 FPS, 1% low 82-84, 0.1-0.6% over a period; no hang.
- U1's chapter-intro movie on the screen follows the poses as a fixed screen (yaw/pitch/roll).
- Head poses (simpose.py: 0, yaw +-20, pitch 10, roll 15): U2 train and U3 pub follow the head; U3's prompt stays in
  its world-fixed box, whole.
- Open: U3's main menu (a 3D desert) renders in stereo with a flat yellow lower half; U3 + DLSS stopped presenting
  once near a frame-dump screenshot (not again in a rerun); U1 one-off right-eye light artifact; TV gamma default; HUD
  size; head-pose checks (yaw/pitch/roll) for U2 and U3.

## community-vr: the VR work on drakolordx7's community build, eye sizes to 5120 (2026-10-24)

Matt: "create a community-vr branch from the community code, then merge your vr work on top of it and fix it", "this
needs to work at resolutions up to 5kx5k". Branch `community-vr` (local, from `origin/community` 8e84018): the 16 VR
commits cherry-picked (not a merge: that would bring full-release's history), then:
- Community overlaps: its BB_GAME_RES patches the same display configuration as the VR eye size, so VR clears it
  (launcher vr_environment, run.py before game_res). Its scene-pass size comes from Vr::Fixes::RenderSize (the eye
  size, else BB_GAME_RES, else 1920x1080). Its decoder scales movies only with BB_GAME_RES, so the VR movie fix still
  applies. bb-probe takes one --patches file: run.py vr_patches() joins the eye size's patches to the cheats'.
  The shader cache keeps the stereo suffix on both of community's cache paths.
- Eye sizes past 2560 (all in scripts/vr_resolution.py, found by bytes, checked per game):
  - HeapArena::Init keeps a 64-bit size (the owner's +0xc8 = arena +0x78 when its low half matches).
  - The "screenshoot buffer" arena (table id 0x80, 128 MB in the CPU context) holds three full-size RGBA buffers:
    grown with the eye size (and context 2, and the 4.5 GB system total). 0x81 is the arena before it.
  - Arena reservations past 4 GB: the reservation's four overloads (mov esi, r12d), the owner's virtual Allocate
    (mov ebx, esi) and HeapArena::Allocate (mov r15d, esi) cut sizes to 32 bits: a 4161 MB render target heap took
    65 MB of the GPU arena and the texture allocator began inside it ("Views into vram allocator not supported
    yet"). All three keep 64 bits; HeapArena::Allocate takes the upper half only for 1..15 (4-64 GB), as other
    callers may leave anything there.
  - Measured (tools/vr/arena_scan.py, U3 3840): heap 0x85 high water 2292 MB of 4071, 0x84 400 MB of 1016: the
    heaps' pixel-count growth (x1.02) is about twice what the game uses; kept (headroom).
- Results (simulator, RTX 5090, 90 Hz, DLSS off unless named): 2160 + DLSS: U1 90 (1% low 79-81), U2 90 (82), U3 90
  (80-81). U3 3840 90 (1% low 79-80); 4480 90 (1% low 41, 10% late); 5120 74.6 (1% low 38); U2 5120 68.6; U1 5120
  64 in gameplay. All three correct in both eyes at 5120; movies on the screen. run.py at 5120 with a cheat: 63
  writes (62 + 1), BB_GAME_RES ignored in VR.
- Launcher eye sizes 1440-5120 (2160 recommended); run.py clamps to 5120.

## Pacing, menus, tags, blur, shadows, movies (community-vr, 2026-10-24)

- Pacing as Driveclub's (recomp c5c0dc6): the output rate is the game's; the adaptive cap from the headset's refresh
  rate (XR_FB_display_refresh_rate, else the shortest predicted period: SteamVR doubles it when the app is late); one
  flip per headset frame also without a frame limit (fork 9e56486, 0ef27c5). Matt: "much better".
- 2D menus on the flat screen again: the flip capture needs a 3D frame with a scene depth (c989aa6). Frame tags read
  from the near plane (-c9 / c8 of the velocity pass), ten times wider steps: every frame finds its pose (8da3b95).
- Fork 1df5081:
  - Object motion blur (Display > Motion Blur, default "Object") smeared characters along head turns (Matt: "the
    characters all blur to the left of them, until I stop"; gone with the menu's Off). The setting: two bytes of a
    settings block (+0x1ba object, +0x1b9 camera; the options' getter U1 +0x135100), found by toggling it in the menu
    and diffing memory; the renderer's one check (U1 +0x4db75f, U2 +0x6674af, U3 +0x614b4f) becomes a jmp in VR
    (vr_resolution.py, by pattern). Eye dumps with a 20-degree head sway: characters sharp.
  - Shadows differed between the eyes (Matt: a far bigger shadow on a crate in the left eye): the cascaded shadow
    resolve (ps 0x7c219ffb, full screen) rebuilds points from the centre camera's ray, so each eye's points sat half
    the eye distance off. Its cascade rows (buffer 0: 4 x 16 floats) get a per-eye copy moved by the eye's offset
    (view x points left: the camera's axes). Sign from the axes; the 10x/30x baseline A/B could not show it (moments
    differed): Matt to check in the headset.
    2026-10-26: it never ran (see below, "Shadows per eye, for real").
  - Menus over a movie were stretched (a round button an ellipse): movies now fitted into a square canvas in a 1080p
    buffer (1408x1408, black bars; the game's movie buffers do not grow: 1920x1920 overran them), the screen at the
    canvas aspect. Cutscenes letterboxed, faces right.
  - The desktop mirror swapped red and blue (RGBA frames).
- Test setup: session.sh now sets the launcher's VR env (multiview, vblank 240, upscaler off); earlier sessions ran
  without multiview.

## Shadows per eye, for real (fork 03d66f9, 2026-10-26)

- The shadow resolve (ps 0x7c219ffb, decompiled: spirv-cross --vulkan-semantics on the cached .spv) reads the
  depth at its texture coordinate (u, v), makes z = c3 / (depth - c2) (buffer 1), and feeds (u z, v z, z, 1) to the
  rows of cascade c in buffer 2 (floats c*16 + 4..15: shadow x, y, depth); buffer 0 holds the split distances
  (floats 0, 16, 32, 48). An eye drawn with clip shift s (left +s) has u = u_centre + s / 2w, so u z = centre's + s / 2:
  the rows' translation moves by row.x x -s / 2 (left), +s / 2 (right).
- All three buffers are bound from the constant ring (the GPU command thread's copy): NoteRingBuffer now records them
  (with the ring's copy, which EyeConstants copies from), EyeBufferInfo leaves ring bindings alone.
- Test (scratchpad unc/shsweep.sh, lrroi.py, lrcmp.py): one session at Matt's boat save, SHSCALE trigger file
  switching the correction's scale between simulator shots; both eyes of the same frame compared by 16 px blocks
  matched along x (normalised correlation, blind to brightness), then the blocks' brightness ratio. A cross-run
  ground truth (eye distance 0, head moved to an eye: IPD trigger) failed: the boat rocks, the camera moves between
  shots. The log line "VR shadows per eye: applied N, skipped M" shows it ran.

## Water reflection (U1, fork c6423c9, 2026-10-29)

- Matt: "the river reflections in the jungle (walk forwards to it) looks wrong. The difference in each eye looks too
  big." The river's pixel shader (pgm f2fab535, with vs 0019120e) reads its planar reflection (image 8: a 720x720
  main-view fraction, so two layers, drawn per eye) at a projection it computes itself: (constants 155-157 + the
  reflected view direction) through the rows in constants 159-170, divided; the view direction from the camera
  position in constants 171-173 and the world position (attribute 4). Nothing there is per eye, so ScanScreenParams
  cannot move it, and each eye's reflection carried the water surface's disparity on top of its own.
- Fix: that one sample moves by the water pixel's eye shift (0.5 * vr_shift[view] * gl_FragCoord.w, multiview
  pipelines only; emit_spirv_vr.cpp ProjectiveSample). Other water with the same kind of lookup (U2, U3, other games)
  needs its (pgm, image) in BB_VR_PROJECTIVE_SAMPLES's default.
- Test: scratchpad unc/rvab.sh (fresh load of the jungle save, walk 6.5 s, head yaw 35 pitch -15, both eyes twice)
  and dispmap.py (16 px blocks matched along x). Before/after/reversed in 6-wip-games.md.

## Head aim (uncharted_pc aa9a4d1, 2026-10-30)

A stick-driven loop (the head's error as a right stick value) was too slow: the aiming camera turns at most ~45
degrees/s at full stick (1.02; 1.00 more past 1.0 in the float pad state), and a gain fast enough to close in a frame
oscillated. The aiming camera's persistent direction was found as RPCS3's was: float triples equal to the camera's
forward (`aimfind.py scan`), kept those that followed a stick turn (8 left), then rewrote each turned 20 degrees: only
camera object +0x1830 turned the camera and stayed turned. A data watch (`WATCH <addr> 4 rw`) gave its writers (update
+0xc42c0: stores at +0xc4b6f / +0xc4fdc) and readers (+0x276c9d / +0x27733e, the player's aim). The VR camera hook
writes the head's direction there at the update's entry (rsi = the camera object); what the update adds sideways is
the stick, taken into the held view so the stick still turns. The game's mouse aim (src/runtime_pad.c) is a right
stick value while aiming (direct only for the follow camera, +0x1310), so the direct write is the better path.

## U2 / U3: lights, mist, depth of field, head aim, shader cache (uncharted_pc 5a79c21, 829a57b, 2026-10-30)

Matt: "implement all relevant changes to uncharted 2 & 3 as well, all gfx fixes, performance and aiming."

- Shared shaders: the collection's three games share much of the post chain. U1's sun shadow resolve (7c219ffb) and
  character light compute (43b8ee5e) run in U2 too, so their per-eye fixes already applied there; the mist pass
  (84adaaea) and depth of field composite (3371ae8d) are in U2 and U3.
- Head-tracked views: U2/U3 build all render views through the main camera's call (+0x61194a / +0x5b153a), including
  lights' projections (U2 train wreck fire: x scale 1.7321, near 0.1, far 11) and an origin view (x scale 1, far 100).
  Only views with far >= BB_VR_MAIN_FAR_MIN (500 m) are head-tracked now. U3 logs a few far-0 main-shaped views while
  loading (skipped); in play its main view has far 5000.
- Mist (84adaaea): z = c3 / (depth - c2); density max(0, c20 z + c21) x max(0, c22 h + c23), h the world height from
  the ray (c8, c9, c10 rows, c11). c20 is multiplied by sqrt(1 + xr^2 + yr^2) (xr = c0 (2u - 1 - c70), yr = c1 (1 - 2v -
  c71); u, v from gl_FragCoord, which is declared for the shader). The sky branch (depth = 1: fixed z 1000) is left.
- Depth of field: 7b9c669b (720, CoC-weighted downsample of the scene by the R8 focus mask), the composite 3371ae8d
  mixes scene -> blur by the mask (image 2). FixedSample: that image reads 0. The blur chain still runs (cheap).
- Tools: BB_VR_RADIAL_DEPTH "pgm:term:rx:ry:ox:oy", BB_VR_FIXED_SAMPLES "pgm:image:value" (both emitted per shader;
  "VR radial depth" / "VR fixed sample" logged at emission); world-lock check scratchpad unc/wl_shots.py + worldlock.py;
  skip sweep unc/skipsweep.py (SKIP trigger per pgm, change per 4x4 cell vs a control dump).
- Shader cache: the suffix is `_mv7` for every eye size (PatchShader is empty here: nothing holds the size). A shader a
  VR fix translates carries a tag in the top byte of its stored binary version (Vr::ShaderTag), so adding or changing a
  fix retranslates only those shaders. Matt's 3584 cache was copied to the shared folder. Before, every VR fix bump and
  every eye size started an empty cache (his 3584 one had dropped from ~3000 to ~1800 entries).
- Head aim U2/U3 (statically, not yet tried in game): the class name is registered with a factory (U1 +0xbff30, U2
  +0x187830, U3 +0x1352c0; U2's second copy of the string "CameraControlZoom" at +0xb4a38e is the registration one);
  each factory's constructor stores the vtable (U1 +0x9648e0, U2 +0xe085e0, U3 +0x13686c0). U1's update is slot 19
  (+0xc42c0: result rdi, this rsi, input rdx). U2 splits it: slot 28 +0x18cef0 the location (U1's shape) and slot 29
  +0x18c9a0 (this rdi, input rsi) turning +0x1f30 with the helper +0x334220 (this+0x160, input+0x54, &dir, &dir2
  +0x1f40), as U1 turns +0x1830 with +0x2764c0. U3 keeps U1's shape (slot 36 +0x135950) with the pair at
  +0x11e0 / +0x11f0 (U2's +0x1ec8 / +0x1ed0 / +0x1f90 location fields are U3's +0x1170 / +0x1180 / +0x1240).
  camera-aim-override-direction (U2 native +0x3f9230) only writes globals (+0xeb7a60, mode +0xeb7a9c = 2) that U2's
  camera manager does not act on: not used.

## Quest 3 stalls, pacing, menu state (vr-0.3, 2026-11-06)

- Reports: an RTX 3070 (1440 per eye, 80 Hz, Quest 3, Virtual Desktop, VDXR and SteamVR) and an RTX 4090 (2880, 120 Hz, likely a
  Quest 3, unconfirmed). Logs with BB_FRAME_STATS=1: shader compiles 0 in nearly every report; the game finishes 63-84
  frames a second (4090: 70-77) and the headset shows 18-54 (25-52). Longest waits on the headset's path 0.5-1.5 s, in the
  copy's fence on VDXR ("command buffer") and in xrReleaseSwapchainImage / xrEndFrame on SteamVR, while the game's slowest
  frame stays 25-58 ms: the GPU is not hung. Matt's headset at 5120 per eye, unable to hold the rate: 58 finished, 58
  shown, longest wait 0.0 ms. The 5090 on the simulator GPU-bound (94 of 120 Hz): 0.1 ms. Not the driver (Matt).
- The adaptive cap's loop: the runtime halves, one flip per headset frame gives 40, 40 < 0.95 x 80 uncaps, the game runs at
  93-130, 1.12 x 80 caps again: 8-28 flips a run. Not the whole story: the 4090 never reached its cap (134) and stalls too.
- Fix (bd7b41e): one flip per headset frame always (no rate test), a flip allowed anyway after 100 ms, movies exempt.
  BB_VR_CAP=adaptive the old cap, 0 none. BB_VR_STALL_LOG=<ms> logs slow steps of the loop. uncharted-debug.bat ships them.
  SteamVR, U1: 1440 90.0 flips / 90.0 headset, 5120 about 58 FPS (Frame stats) as before. Not run on a Quest; half-rate
  recovery not exercised. If stalls remain: BB_VR_SHARED_QUEUE=1 (copies on the game's queue) is the next test.
- Menu state (d2e9b86): U2 object image +0xf2e350, state +0x1014 (0 play and loading, 3 opening, 12 open, 5 closing; found by
  diffing the data segment across title, menu, pause and play; the game tests it at +0x249851). U1 +0xabb148, +0x794 (the
  same writes, not run). +0x1038 is a per-frame flag, cleared at +0x2a51de: do not read it. U3: U2's code patterns do not
  match; find it by the same diff.
- The launcher's Copy VR report said "does not know this game version" on every copy: it misled a user whose version was fine.
  CUSA02344 (another dump, SHA dc017b45...) works through the code patterns, with 18 VR patches against 02343's 49: why not
  checked (no dump here).

## U2 "jumping world": the frame rate, and the lens skip (uncharted_pc 4dbcacb, 2026-11-08)

Matt 2026-11-03 (U2, main menu Continue): "Turning HMD left or right shows jumping world. I suspect this is steamVR
frame pacing issue."

- Not the head pose: U2 calls the projection builder five times a frame for the player view (one fresh, four on views
  already turned), each with a new frame tag; all five take the same head (BB_VR_CALLLOG, a 25 degree simulated head
  sweep: 0 of 620 frames on more than one head), and every play frame finds its tag.
- The frame rate: his cliff save (copy in H:/uc_tests/u2user), eye 3584, SteamVR on his headset: 76 FPS, 1% low 43,
  41 frames reprojected a second (vrstats), at times a 45 Hz period. Eye 3200: 87.7, 3.4 reprojected. GPU 96% busy,
  13.0 ms a frame (BB_GPU_PROFILE): the tiled light compute 43b8ee5e 2.8 ms (both eyes), the half-size pass 53ae53fd
  0.7, the main pass 0.7, the depth tiled into guest memory 0.45, the stencil upload 0.24. The 346 one-group skinning
  dispatches (cs 8f067540, "2.4 ms") are inflated by the profiler's own timestamps; skipping them live hung the GPU.
- 43b8ee5e (BB_PATCH_SHADERS experiments, simulator 144 Hz uncapped, Matt's save; baseline 84.8 FPS twice): skipped
  113; no lights 109.3; light culling only (tile light-count heat map) 109.2: nearly every tile holds the fire's
  light, and the per-pixel shading of that one light is the 2.6 ms. Cookie texture fetch replaced 90.4 (0.4 ms);
  `precise` removed 88.1; spirv-opt -O 84.6; glslang round trip of the decompiled shader 87.3 (0.3 ms better than the
  port's own SPIR-V, cause unknown). The inner loops are the game's own waterfalls with each v_movrels / v_movreld
  emulated by 24 selects (VMovRelSHelper); not changed.
- The lens skip: SteamVR's hidden area on his headset (logged by PGR4: 108 vertices) is a circle of radius 1.035 in a
  2.07 square of view tangents (21.8% hidden); the port renders +-1.1155 wide (the eyes' overscan): 27% of each eye's
  pixels are never shown. Prototype (patched 43b8ee5e, tiles outside skipped): 87.3 -> 92.2 uncapped. Built in: the
  mask from XR_KHR_visibility_mask, the radius against the headset's field of view, push data vr_lens / vr_lens_size,
  listed computes return per workgroup, listed fragment shaders discard in stereo draws that write no depth. Same-boot
  A/B on his headset (tools/uncharted/lensab.sh, dev trigger LENS): reprojected a second off 44.4 / 44.5, computes
  19.9 / 13.6, both 11.6 / 0.6; again computes 18.9 / 8.1 / 20.1, both 0.1 / 8.0 / 3.9. Adding the depth-testing
  passes (b70e7012, a428f66d, f7e7ba7e, 9f8b18cc, 0bae6524, 8b447ab6, 31ff3be2) showed no gain: reverted.
  Eye dumps off / on / off (lenseyes.sh, lenscheck.py): inside the circle the on frame is within the scene's own
  change; the skipped area starts past 1.05. U1 jungle renders normally with it. The desktop window shows the left
  eye whole: an arc of last frame's mist at its edges.
- Left: some 15 s windows still miss (worst frame 22 ms, xrWaitFrame up to 20 ms late, the runtime pattern PGR4
  showed). Not run in U3; U3 shares 84adaaea and 3371ae8d.
- Tools (plans/tools/uncharted): sess.sh (GAME=u1|u2, RUNTIME=steamvr, ROUTE, HOLD, SESSION_ENV), steamfps.sh,
  lensab.sh, lenseyes.sh + lenscheck.py, patchab.sh (a replacement SPIR-V, fresh GPU cache), skipab.sh, simsweep.py,
  callspread.py. Saves: H:/uc_tests/u1user (his jungle), u2user (his cliff).

## U2 shadows, menus in all three, U3 on the headset (uncharted_pc 5e838f4, 2026-11-08)

- U2 ground shadows by the fire (Matt 2026-10-30 / 11-03, "flicker on and off", "capture multiple frames at once"):
  not seen on the current build. Flash ring (tools/uncharted/ringrun.sh: BB_VR_FLASH_RING=1, 768 px an eye, 300
  frames, 3.3 s; flashring.py) at his cliff save, SteamVR still and the simulator during a 25 degree head sweep: the
  only one-frame changes are the flames themselves (the wreck's windows, the fire, bushes), in both eyes alike. The
  fire-lit ground in front of the wreck over 300 frames: mean 135.6 / 136.1 (left / right), std 1.6 (the flames'
  flicker), biggest frame-to-frame step 2.4 levels; ground beside it std 0.2. Needs his look; if it shows, his F10 + F9
  ring.
- The fire's light texture in 43b8ee5e is a guest 2D array sampled as 2D (a cube face selected by hand, the face index
  in the LOD argument, as the game's own code has it): its VR view keeps one layer, so both eyes read the same layer.
  Not a cause.
- Menus from the game's menu state, all three checked on the simulator (pause, resume, pause and back out): U1 (+0xabb8dc)
  and U2 (+0xf2f364) switch to the flat screen and back each time, no switch in 2+ minutes of play. U3's field found:
  image +0x1441ac8 (object +0x1441ac0, state +8; menudiff.py snapshots of the image in pause and play, poll.py through a
  whole session: 12 title and menus, 7 / 6 between menus, 0 loading and play, 3 / 12 / 5 pause), located by its one
  test "lea rax; cmp dword [rax+8], 0; setne" (5e838f4). The image base moves between boots (0xb200000-0xbc00000);
  the port re-executes when it switches to the game, so attach memory tools after that.
- U3 pub, eye 3584, his headset: 87.7 FPS, 3.0 reprojected a second, 4% over a period, 1% low 44.8. GPU 11.7 ms
  profiled with 2.9 ms of it idle between submissions: not GPU-bound; the misses are whole periods, as U2's leftovers.
- Tools: ringrun.sh, menudiff.py, poll.py; steamfps.sh takes GAME / ROUTE / START. U3 save copy: H:/uc_tests/u3user
  (route: wait 50, cross x5 6 s apart).

## U2 fire shadows per eye (uncharted_pc b580ecc, 2026-11-08)

- Matt (F10 + F9 ring at the fire, then): "the shadows are just below the fire, grey patches that flicker on and off per
  frame", "they also vary per eye", "take 10 dumps, as close as possible". His 768 px ring (384 an eye, a 9:1 linear
  blit) could not show them; ten full-size dumps of both eyes (dev trigger EYES, about 2 s apart) did: hard grey shadow
  blades of the timbers on the fire-lit snow in the left eye only.
- Reproduced at his cliff save after one walk leg (`hold ly=0 lx=40` 2.5 s). A 1024 px ring of 120 frames: on in 97, off
  on every third frame three times in each 16-frame cycle. Eye distance (dev trigger IPD): 0 both eyes identical, none;
  0.2 m a wider blade; -0.2 (temporary build) still the left eye only.
- Knobs that did nothing: the light compute's eye correction (LIGHTEYE), the sun resolve's (SHSCALE), per-eye light data
  off, AO forced to 1 (patched 12ed77bf), the fire cube's layer pinned, the 64x1 depth row per eye (built, reverted),
  skips of the motion blur (19367542) and of the full-screen passes. One-dump skips misled: the blades switch with the
  frame, so each condition needs several dumps (wedge.py scores them: right minus left over the blade, about 5 on, -0.5
  off); BB_SHADER_DEBUG_FILE skips match pixel and compute shaders only (the dev SKIP trigger takes vertex shaders).
- Found by dumping the material pass's inputs per eye (TEXDUMP now writes both layers, texview.py): the blades are in
  the light buffer 118b100000 before the material pass (vs 9e3c1074) reads it. The draw log (DRAWLOG) gave its writers:
  vs 1bf62085 with pgm a74ece03 and f4a633e3, lights drawn as geometry. Their pixel shaders rebuild the point from
  gl_FragCoord: ray c12 u + c14, c13 v + c15, z = c9 / (depth - c8), world rows c16, c20, c24: U1's torch layout.
- Fix: both in BB_VR_EYE_RAY_PS's default (`a74ece03:0:14:16;f4a633e3:0:14:16`). At 0.2 m the left eye's edge is soft
  again, as the right eye's and the eye-distance-0 picture; at his distance 0 of 10 dumps show blades (9 of 10 before).
  "VR light rays per eye: pgm 0xa74ece03 applied ..." in the log shows it runs.
- Tools (plans/tools/uncharted): eyeburst.sh (N full-size dumps; PATCH_SPV, KEEP), skipeyes.sh (REP, PRE), trigeyes.sh
  (a dev trigger swept, PRE), texsweep.sh (TEXDUMP per knob step, PATCH_SPV), wedge.py, texview.py. Patched shaders: the
  cached SPIR-V decompiled (spirv-cross --vulkan-semantics), edited, glslangValidator -V --target-env vulkan1.3; 43b8ee5e
  needs its shared struct declared (uint _m0[132]) and its two 64-bit shared reads as 32-bit pairs.

## U2 wedges still flashing on the headset (uncharted_pc 8541a15, 2026-11-09)

- Matt (headset, after b580ecc): "the grey triangles are still there and still flashing in u2". His last_run log: "VR
  multiview: eye clip shift" switching 0.029582 / 0.031868 every few lines (200 logged, the cap); simulator runs log one.
- Cause: both camera hooks set g_rendered = g_head (the headset's field of view) and wrote the overscanned tangents
  (+0.08 a side) later; the headset thread's SetShift(LastRendered) between them took the narrower view: 2.232 / 2.072
  = 1.077, the two values' ratio. A shift changing between a frame's passes is what left one-frame grey shards before
  (SetShift's comment). Now published whole under the lock. The simulator never hit the gap, so only his log can show it.

## U2 shadow streaks from the frame tag (uncharted_pc 8247f9a, 1cc71d1, 2026-11-09)

- After 8541a15, Matt: "still not fixed ... many parts of the screen, in both eyes, flickering all the time".
- His headset through SteamVR (he said to use it), cliff save after one walk leg, eye 2160, ringtrig.sh (one session, dev
  triggers, a 300-frame ring each) and /h/uc_tests/ringcmp.py (p90 of the frame-to-frame change per pixel; % over 10):
  base 1.8, lens skip off 2.1, per-eye lights off 2.6, eye distance 0 2.5: long streaks fanning from the fire over the
  snow and Nate's shadow flicker in all. Flat (BB_VR=0, ffmpeg gdigrab of the window): no streaks at all.
- BB_VR_NEAR_STEP=0 (no frame tags): 1.16 / 1.40, streaks gone; control on the same build 1.85 / 2.01, back. The tag moves
  each frame's near by k x 2e-4 (k 1..16); some pass reads depth with another frame's (or the untagged) near.
- Step 2e-6: gone (1.14-1.20) but U1 missed every tag (its near reads back ~5e-7 off, tags 1e-6 apart in its shader
  term). 2e-5: U2 1.23, tags found in play in U1, U2 (match ages as at 2e-4), U3. BB_VR_TAGLOG prints found / missed.

## U2 after the tag fix: one pose and tag a frame (uncharted_pc eb2f4ff, 2026-11-09)

- Matt: "you fixed 95% of the flicker now ... The shadow still flickers a bit, image 1 & 2, you can see the rock on the
  right has more shadow in 1 than 2." and "image 3 you can see black marks in the snow, they differ per eye too much".
- BB_VR_NEARLOG: the light passes' near advanced 5 tags a frame: U2 builds the player's view ~5 times a frame and each
  call took a new tag and the newest head pose. Now a frame's calls share the first's (the later calls see the camera
  the handler wrote). Tags found in play as before. No difference measurable on his headset at two spots (flat-area
  flicker, ringflat.py); BB_VR_FRAME_LATCH=0 for A/B.
- His images 1/2 spot (route: one walk leg, forward 8 s, then right+forward 3 s: the tree over the fire): the frame
  changes are sub-pixel image motion (tracking noise) and the fire. The flat game there (gdigrab of the window) flickers
  the snow rocks right of the fire with the fire: the rock's shadow there is the game's animated firelight.
- Image 3 (blue streaks strong in the left eye, weak in the right): not reproduced. Simulator and headset dumps under the
  wreck (eyematch.py block match) agree between the eyes; f4a633e3 (the fire light from inside its volume) rebuilds the
  point as a74ece03 does (c12-c15 ray, rows c16/c20/c24), specular view vector from the centre camera c4-c6 (small).
  Needs his location. A GPU page fault (device lost) once at the start of play (run before it fine; retry fine).

## Shader preparation ported from Mevlock's lists (uncharted_pc f3de55f, 2026-11-09)

- Found published: Mevlock/uncharted_pc-dev (GPL-2.0) ships shaders/<game>_variants.txt, _keys.txt, _compute_keys.txt and
  shader_locations_<title>[_ver].txt (inputs and state, no code; recorded by walking every checkpoint): U1 2222 variants /
  1783 keys, U2 4006 / 4055, U3 12958 / 9793. Their docs/SHADER_PREPARATION.md has the design and measurements.
- Ported (not merged): translator hooks (t_sharp_override in resource.h, t_translation_replay in info.h and
  fetch_shader.cpp), list readers, location index, RuntimeInfoFromRegisters, BuildListedVariant (CompileModule split into
  TranslateModule), the renumbering and key remap. Here the listed variants build before warm_done (no claims or race),
  and the first launch with a list (marker prepared_<list> in the cache) holds the game until every pipeline is built too.
  Skipped: their page/overlay, freeze, async compute, GPL, scans without an index. Lines of their own kinds (ultrawide
  squeeze, split layouts) are skipped; their Bindings has a 4th word (descriptor set): taken when 0.
- Their BufferSpecialization::coherent is bit 30 of the first word (spare here): without it the list-built computes lacked
  OpDecorate Coherent (11 of 286 differed); with it all 286 shaders of a U2 session match play-translated ones byte for byte.
- Game version 1.00 here: index shader_locations_CUSA02343.txt (the _102 is 1.02); the launcher passes every index of the
  title and the port keeps the one whose sampled locations read back. BB_APP0_DIR is set by probe.c.
- U2 opening, simulator, empty cache: 61 pipelines built in play (436 ms) -> 2 (4 ms); first launch held 17-24 s.
  U1 chapter 1 (hub: left once, cross; Chapters 3 down; cross, cross, 3 down, cross), simulator eye 2160, 240 Hz, empty
  cache, 34 s intro cutscene (60 FPS both) then 16 s of play: without the lists 39 pipelines built (1786 ms), frames of 871,
  451, 137, 122, 57 ms, play 1% low 67-78, late up to 0.78%; with them 0 built, only the two chapter-load frames (461, 102
  ms, in both runs), play 1% low 79-83, late 0%; first launch held 11.9 s.
  U3 chapter 1 (chroute u3 1 now goes straight to Start Chapter: the list's first cross opened and closed it), empty
  cache: without the lists 67 pipelines built entering the chapter (2973 ms, a 1129 ms frame), none after; with them 0
  built, frames up to 94 ms later on (69, 65, 50, 93: not compiles; the no-list run had 81 and 79); first launch held 84 s
  with a cold driver cache, 69 s and 14 s on reruns (the driver's own disk cache). Its vulkan_driver.vkc 184 MB (7 MB
  without): the first prepared launch now saves it before releasing the game (507 ms).

## Shipping a pipeline recipe instead of a shader cache (2026-11-09)

- Releases ship no cache (package.sh stages a fresh folder): every player gets the first-run stutter. The port already preloads
  every recorded pipeline at launch (StartWarmUp: Matt's 1459 of 1462 in 445 ms). U2 opening, simulator (coldwarm.sh): empty
  cache 61 pipelines built in play, 436 ms, worst play frame 156 ms; the same run warm 0 (preload 107 ms), loading frames only.
- Legal (Matt asked): .spv = Naughty Dog's shaders translated, not shippable. .key = hashes and render state. .meta (read the
  writer, RegisterShaderMeta): specialization (state), Info (resources, user-data mask, hash), our own SRT walker x86, and
  flattened_ud_buf, a snapshot of the draw's constants (game data, no code): to blank before shipping.
- Size of the known recipes (keys + metas, zip -9): Matt's main cache 1463 pipelines 4.39 MB; all three of his caches merged
  3969 files 5.16 MB.
- Match proven: the program id is the shader's own 64-bit hash from its OrbShdr footer (regs_shader.h GetParams). Dev
  BB_DUMP_GCN_RAW=dir dumps the code translated; pakindex.py indexes every footer (270206 footers in 4218 files, 34002 unique
  shaders: u1data 3453, u2data 8677, u3data 23056, 667 shared); pakmatch.py: all 287 shaders of a U2 run found under their hash,
  every copy (25266) byte-identical. The recipe can name a pak, offset and length; the player's own files supply the code.
- Translation needs draw state (runtime info, specialization), so the files alone cannot build everything: the recipe covers what
  has been recorded (2146 of 34002 shaders seen so far); chapter starts add more (not measured).

## U2 blue snow marks: deferred decals per eye (2026-11-09)

- Matt: "the dark snow is further moved apart per eye than the brown rocks next to it". The spot: through the gap under the
  carriage until the camera changes (crates, pillar, rocks); a dozen scripted walks never reached it (the path varies), so he
  stood there and I worked on his live session (dev triggers EYES, DRAWLOG, SKIP=vs): one sweep of 20 groups found vs f7dd5989 /
  pgm 71165e3f, blended.
- The pixel shader rebuilds x = z (c63 u + c65) and subtracts an interpolated origin (input 6). The eye's offset s / P00 stays in.
  Measured with the decal on minus off, rocks masked, in the blocks where the marks are: off -22 px vs snow -100; 0.8: 16.5 px
  from the snow, 0.9: 7.5, 1.0: 1. Earlier "the eyes match" readings were wrong: whole-picture matching and windows dominated by
  rocks; Matt's eye was right. Fix: the origin's x + s c[ray] / 2 in the pixel shader (BB_VR_EYE_DECAL_PS "pgm:input:ray").
- Search (tools: /h/uc_tests/scan2.py, scan3.py, SSA taint over spirv-cross output of the 2146 cached shaders): z from depth
  multiplied by a screen ray. New: decals b1386ddc:5:105, 75132665:5:101; light layout 14e3079b, 6aed7ebb (BB_VR_EYE_RAY_PS). Not
  seen in a run yet. Left: computes 12ed77bf (AO) and 38d8bf05: relative positions only, as far as read.

## U2 / U3 head aim in play (uncharted_pc 16db135, 2026-11-09)

- Getting to a fight: the test user H:/uc_tests/u2fight (a copy of the chapter-unlocked saves, every chapter selectable in
  all three games; save_editor.py describe). Routes in plans/tools/uncharted: U2 /h/uc_tests/u2ch6.route (Options, Game:
  hints off; Chapters, 6 - Desperate Times, Start Chapter), U3 u3ch6.route (6 - The Chateau). In the Chapters screen a
  right press opens the chapter carousel; cross picks, then down x3 to Start Chapter. sess.sh takes UCUSER=u2fight.
  U2 chapter 5 (Urban Warfare, the save's Continue) stops in the run-and-gun tutorial freeze: no camera updates run.
- Finding the per-frame aim update: BB_GUEST_HOOKS=<lo>-<hi> counts every function with a frame-pointer prologue in the
  range (a report every 2 s); calls while L2 is held against not. U2 (0x150000-0x190000): CameraControlZoom's factory
  +0x187830 once per aim, slots 28/29 (+0x18cef0 / +0x18c9a0) 90 a second while aiming. U3 (0x133000-0x13c000; the wider
  0x128000-0x148000 hung the boot): slot 36 (+0x135950) once per aim, slot 37 (+0x1356b0, this in rdi) every frame.
  U3 writes +0x11e0 in slot 36, slot 40 (+0x13c230, a quaternion turn: likely the platform's) and +0x138e2e.
- U2 also has CameraControlAiming (factory +0x1588c0, vtable +0xe05e10, slot 28 +0x1593d0: a level direction +0x170 and
  the pitch in degrees +0x1230): not used by the L2 aim (hooked, never ran).
- Result (simulator, head 0 then 20 degrees left during the aim): engaged for the whole aim in both, the aim camera on
  the gaze (0.00), the reticle 20 degrees off the body view. Zoom x scale U2 2.414, U3 1.921.

## U2 frame cost at 3584, more (2026-11-09)

- Profile (BB_GPU_PROFILE, Matt's cliff, simulator, eye 3584): 13.6 ms a frame, 72.7 FPS uncapped. Tiled light 43b8ee5e
  3.1, the one-group skinning dispatches 8f067540 "2.3" (346 a frame, inflated by the profiler), the half-size pass
  53ae53fd 0.82 (199 draws), the main pass 0.73, depth tiled 0.37, the composite 3371ae8d 0.36, stencil upload 0.26,
  then many under 0.35. Nothing big left to cut at 25.7 million pixels a frame; the lens skip is in.
- 43b8ee5e's v_movrels select chains (VMovRelSHelper, 24 selects each) are only the light-mask word reads (4 sites),
  not the shading: not worth changing.
- NoContraction off in pixel and compute shaders (dev switch, fresh cache each side, contractab.sh): run 1 off 13.7 /
  on 14.1 ms, run 2 off 14.3 / on 14.1; the control drifted more than the difference. Reverted (not committed).
- So U2 at 3584 holds about 72 on the 5090 (GPU-bound); at 90 Hz it reprojects. Matt's options: a 72 or 80 Hz headset
  rate for U2, or eye 3200 (87.7 FPS on his headset, 3.4 reprojected a second).
- U3 volumetric beam (0a8f4f44): chapter 11's start (As Above, So Below: a rooftop) shows no shafts; skipping the beam live
  changes nothing there. Still needs a scene with strong shafts.
- Water: neither U2 nor U3 loads U1's river shader (f2fab535); no water scene found at chapter starts (U2 chapter 3
  start is jungle without water). Not checked.
