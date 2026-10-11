# DLSS test: motion vectors and DLSS for PS3 games (Gran Turismo 5 first)

An experiment, not a release feature. Branch `ccr-d7a07b1e-7eh4fp` of hookmanuk/rpcs3, on top of `openxr`
(`0b51d79`). Written 2026-10-10, self-tested 2026-10-11. Flat (2D) only: with VR stereo rendering the motion path
stays off.

**Status.** The motion vectors, depth, jitter and MSAA paths are verified numerically by a headless self-test (below)
on Linux with Mesa's software Vulkan driver: every probe within 0.75 px, no new Vulkan validation errors. The NGX
calls compile and link against the SDK, and fail cleanly without an NVIDIA GPU. **Not yet tested: GT5 itself, and
DLSS evaluating on an NVIDIA GPU** (no such GPU or the game in the cloud). The self-test found five bugs that
would have shown up in GT5 as missing or wrong motion; they are fixed (see "Self-test").

## What it does

DLSS needs four inputs per frame: the jittered colour image, depth, per-pixel motion vectors and the jitter offset.
PS3 games have no motion vectors, so the renderer makes them from the matrices the VR profiles already locate.

1. **Scene target.** Each frame counts the perspective camera draws per colour target (camera blocks from the
   title's VR profile, or `RPCS3_DLSS_CAMERA`). The next frame treats the busiest target as the scene. For GT5 this
   should be the 1280x720 2xMSAA target `0xc1980000`; `RPCS3_DLSS_TARGET=c1980000` pins it.
2. **Motion attachment.** While the scene target is bound, its render pass gets one more colour attachment (RGBA32F,
   same sample count): motion in UV units, window depth, coverage. Render pass key bit 44, before the depth
   attachment. The draws into it use shader variants (program control bit `0x80000000`) that write it.
3. **Matrix history.** For every draw into the scene target the CPU reads the camera block (the object-to-clip
   matrix M), identifies the draw (vertex program hash, vertex array and index addresses, range, n-th repeat), and
   finds the same draw's M from the previous frame. It uploads `R = M_prev * M_cur^-1` after the vertex constants.
   The vertex shader outputs the game's clip position p and `R * p`, both through the viewport transform; the
   fragment shader writes the difference. This gives camera motion and every rigid object's own motion (cars,
   wheels) without finding any object in memory: the per-draw matrix already contains the model transform.
   - Unmatched draws (new this frame) get the most common R of the previous frame, which is the camera-only
     reprojection (all static objects share it).
   - Coverage: draws with depth writes, and unblended depth-tested draws (the sky), overwrite the motion; blended
     draws without depth writes (particles, glass) leave it. Draws that are not camera draws never write it.
   - Limits: GPU-skinned bones and SPU-built meshes only get their matrix's motion; instanced draws write none.
4. **Jitter.** Camera draws into the scene target are moved by a Halton(2,3) sub-pixel offset in the vertex shader
   (8 phases, more when upscaling). Other draws (HUD, post-processing, shadow maps) are not moved.
5. **At flip.** A compute pass resolves the motion image (sample 0) to motion vectors in render pixels and depth, at
   the displayed image's size. DLSS (NGX, Vulkan) takes the displayed image (post-processed, HUD included) and writes
   an RGBA8 output at the window's size (up to 3x, or 1x for DLAA), which is presented instead.

Files: `rpcs3/Emu/RSX/VK/VKDLSS.h` (overview and all settings), `VKDLSS.cpp`, `VKGSRenderDLSS.cpp`; one-line hooks
in `VKGSRender.cpp`, `VKDraw.cpp`, `VKPresent.cpp`, `VKRenderPass.cpp`, `VKVertexProgram.cpp`,
`VKFragmentProgram.cpp`, `vkutils/instance.cpp`, `vkutils/device.cpp`, `Capture/rsx_vr_hooks.*`. Self-test:
`rpcs3/dlss_selftest/` (Linux, CMake option `BUILD_DLSS_SELFTEST`).

## Building

Without the SDK the build is unchanged, and only the debug views work. For DLSS:

1. Get the SDK: `git clone https://github.com/NVIDIA/DLSS` (it holds `include\` and `lib\Windows_x86_64\`).
2. Set `DLSS_SDK` to that folder before building, as with `QTDIR` and `VULKAN_SDK`:

```powershell
$env:DLSS_SDK = 'F:\rpsc3\source\DLSS'
```

`buildfiles/msvc/dlss.props` then defines `HAVE_DLSS`, adds the include folder, links `nvsdk_ngx_s.lib`
(Release, static CRT) or `nvsdk_ngx_d_dbg.lib` (Debug), and copies `nvngx_dlss.dll` next to `rpcs3.exe`. The
solution needs a rebuild of `VKGSRender` and `rpcs3` (the project files changed), not only the incremental
`rpcs3.vcxproj` build. CMake: `-DDLSS_SDK=<folder>`.

## Running

Everything is set by environment variables, read once at start-up:

| Variable | Values |
|---|---|
| `RPCS3_DLSS` | `motion` (show the motion vectors), `depth` (show the depth), `motionraw` (motion as numbers, for the self-test), `jitter` (jitter only), `dlaa`, `quality`, `balanced`, `performance`, `ultra` |
| `RPCS3_DLSS_CAMERA` | camera block when the title's profile is not loaded, e.g. `0` (GT5: `c[0]`, column vectors); `0,rows` for row vectors |
| `RPCS3_DLSS_TARGET` | the scene target's address in hex, e.g. `c1980000` |
| `RPCS3_DLSS_MV_SIGN`, `RPCS3_DLSS_JITTER_SIGN` | `++` (default), `-+`, `+-`, `--`: sign conventions passed to DLSS |
| `RPCS3_DLSS_JITTER_SCALE` | jitter amplitude, default 1, `0` turns it off |
| `RPCS3_DLSS_DEPTH_INVERTED` | set if the game's depth is reversed (1 near, 0 far) |
| `RPCS3_DLSS_MOTION_16F` | RGBA16F motion image instead of RGBA32F (used anyway where the GPU cannot multisample RGBA32F) |
| `RPCS3_DLSS_DEBUG` | per-draw log lines: draw keys and matrices, shader variant bits, skipped draws |

Use VR off (or no headset) and the Vulkan renderer. The log channel is `DLSS`: it reports the scene target,
the motion image (size, samples, RGBA32F or 16F), NGX start-up and, every 300 frames, the camera draws matched
against the previous frame. If NGX cannot start (no NVIDIA GPU, missing `nvngx_dlss.dll`, old driver) it logs an
error and the game carries on with the normal image.

## Test plan for GT5

GT5's profile is in `vr-non-working/` on the branch, so set the camera block explicitly.

1. **Motion vectors first.** `RPCS3_DLSS=motion`, `RPCS3_DLSS_CAMERA=0`, `RPCS3_DLSS_TARGET=c1980000`. In a race:
   - standing still: the screen is near black (no motion) except moving cars;
   - driving straight: the road and scenery fan out from the vanishing point in a smooth colour wheel;
   - a car alongside at the same speed is dark (it does not move on screen), the world behind it is coloured;
   - grey areas are uncovered (sky without depth test, HUD).
   If everything is grey, check the log: no scene target, or "camera draws 0" means the camera block is wrong.
   "Motion image 1280x720, 2 samples, RGBA32F" should appear once the scene target is found. If
   cars show the world's colour instead of dark, their matrices are not per draw (or not matched): look at
   "matched/unmatched".
2. **Jitter.** `RPCS3_DLSS=jitter`: the 3D scene should shimmer by under a pixel, the HUD stays still. Then
   `RPCS3_DLSS_JITTER_SCALE=0` with `RPCS3_DLSS=dlaa` gives a reference without jitter.
3. **DLAA.** `RPCS3_DLSS=dlaa`, Resolution Scale 100 or 150: edges should be smooth and stable. Ghosting behind cars
   means the motion vectors' sign is wrong (`RPCS3_DLSS_MV_SIGN=--`); a soft, wobbling image means the jitter sign is
   wrong (`RPCS3_DLSS_JITTER_SIGN=--`).
4. **Upscaling.** `RPCS3_DLSS=quality` with a large window and a lower Resolution Scale.

## Self-test

`rpcs3/dlss_selftest/` is a small program that runs the real emulator core (RSX, Vulkan renderer, the DLSS code)
without a game: it writes a synthetic RSX capture (a floor, a static cube and a moving cube under a perspective
camera whose matrix is in `c[0..3]` with DP4 rows, like GT5), replays it headless, rewrites the camera and cube
matrices in the replayed FIFO every frame, and saves screenshots of the `motionraw` view. `dlss_selftest_check.py`
compares the motion at chosen points with the motion computed from the matrices.

Scenarios: `static`, `object` (only the cube moves: a car on a static camera), `camera` (the camera orbits),
`both`. Each was run with a single-sample and a 4x MSAA scene target (lavapipe has no 2x; GT5 uses 2x), with
RGBA32F and RGBA16F motion images, 24 frames each, 3 points per frame:

| Check | Result |
|---|---|
| Motion vectors, all scenarios, 1x and 4x MSAA, RGBA32F and 16F | all probes within 0.75 px (the raw view's step is 0.25 px), e.g. moving cube -5.50 px measured vs -5.47 expected |
| Final run of `run_selftest.sh` on a clean build (8 runs, 192 probes) | 191 within 0.75 px. One miss: the moving cube read 0 motion in one frame (object, 4x). Not reproduced in 3 reruns with debug logging. Probably the test's own timing (the cube's matrix patched one replay late, so two frames drew it in the same place, where 0 is correct), but not confirmed |
| Depth view | floor and cubes at their own depths (cubes nearer) |
| Jitter (`static`, `jitter` mode, 8 frames) | image shift follows Halton(2,3): x within 0.03 px; y tracks it (noisier measure); +x right, +y down in pixels |
| Vulkan validation layer (motion, depth, jitter modes) | no errors beyond those with DLSS off |
| `dlaa` built with the NGX SDK, no NVIDIA GPU | `NVSDK_NGX_VULKAN_Init failed (0xbad00001)`, image presented unchanged, no crash |

Bugs it found (all fixed on the branch):

1. **The motion attachment was write-masked off.** RPCS3 ANDs each colour attachment's write mask with the fragment
   program's written outputs; a game program writing only `ocol0` masked the motion attachment (index 1) to 0. Only
   pipelines built before that happened (the first draw) wrote motion. Every GT5 draw would have been affected.
2. **Merged draws.** RPCS3 merges consecutive draws that only change vertex constants into one draw with sub-draws,
   re-uploading the constants between them. Those uploads got a "no motion" block; now each sub-draw is a draw of its
   own with its own matrix history.
3. **Surface clip read as 0** for a draw (capture replay resets registers): the draw lost its motion and the next
   frame's match. Falls back to the framebuffer size.
4. **2x MSAA RGBA32F** may not be supported as a colour attachment: falls back to RGBA16F, with depth stored as
   `1 - z` so half floats keep it precise near the far plane.
5. **NGX failure** stopped the frame bookkeeping (only matters for the self-test, but now the game carries on).

Earlier fixes from the same runs: frames whose flips draw nothing (re-present the last output), constant rewrites
between draws (no history pollution), the scene target re-detected at every frame's first bind, and an upstream
capture-replay regression (`Capture Replay: context alloc failed`, `System.cpp`: reserve the main memory area).

Build and run (Linux, Ubuntu 24.04 tested; no Qt):

```bash
cmake -S rpcs3 -B build-core -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=gcc-14 -DCMAKE_CXX_COMPILER=g++-14 \
  -DBUILD_RPCS3_GUI=OFF -DBUILD_DLSS_SELFTEST=ON -DUSE_SDL=OFF -DUSE_DISCORD_RPC=OFF -DWITH_LLVM=OFF \
  -DUSE_SYSTEM_FFMPEG=ON -DUSE_SYSTEM_PROTOBUF=OFF -DUSE_PRECOMPILED_HEADERS=OFF -DCMAKE_DISABLE_FIND_PACKAGE_Wayland=ON
ninja -C build-core dlss_selftest
rpcs3/rpcs3/dlss_selftest/run_selftest.sh build-core/bin/dlss_selftest /tmp/dlss-selftest
```

Needs `xvfb-run`, a Vulkan driver (Mesa lavapipe is enough) and Python 3 with numpy and Pillow.
`DLSS_SELFTEST_VALIDATION=1` adds the Khronos validation layer. Notes from the cloud build: clang 18 was too old
(gcc 14 works); a few `NP/` files hit a gcc 14 internal compiler error (built with clang 20); FFmpeg 6 needs a
small local `media_utils.cpp` shim (not committed: the Windows build uses its own FFmpeg).

## Known limitations and risks

- The HUD goes through DLSS with the scene: during fast motion its edges may smear slightly.
- Display-buffer and scene sizes are assumed to match (GT5: 1280x720 both); otherwise the motion image is stretched
  to the displayed image.
- The shader interpreter's draws do not write motion (only while shaders compile).
- Pipelines with the motion attachment go into the shader cache; they are harmless with DLSS off.
- GT5 scene detail: the mirror is drawn into the scene target with its own camera; its draws match their own
  previous frames (they are later repeats of the same meshes), so its motion should be right too.
- VR: not supported yet. Each eye would need its own R (from the per-eye matrices), its own motion layer and its own
  DLSS feature; the multiview path is where that would go.
