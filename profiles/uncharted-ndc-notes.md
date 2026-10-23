# Uncharted: The Nathan Drake Collection (PS4): VR notes

Not RPCS3: Supermedo's Uncharted PC port (hookmanuk/uncharted_pc, the PS4 code natively, the bbport/shadPS4 Vulkan
renderer, the same lineage as the Driveclub recomp). Fork `H:\uncharted_pc`, branch `vr` from `full-release` 290ced0.
Title ID and version: from Matt's disc dump (pending, 2026-10-23); rename this file to `<TITLE_ID>-notes.md` then.
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
5. Launcher: a VR card (eye size, as Driveclub's), and the auto-update (RELEASES_API = Supermedo/uncharted_pc) must not
   replace a VR build with a flat release.
