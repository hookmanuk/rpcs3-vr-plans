# DLSS test: motion vectors and DLSS for PS3 games (Gran Turismo 5 first)

An experiment, not a release feature. Branch `ccr-d7a07b1e-7eh4fp` of hookmanuk/rpcs3, on top of `openxr`
(`0b51d79`). Written 2026-10-10. **Not yet run on hardware**: the code compiles (with and without the DLSS SDK) and
its shaders validate with glslang, but nothing has been tested in a game. Flat (2D) only: with VR stereo rendering
the motion path stays off.

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
`VKFragmentProgram.cpp`, `vkutils/instance.cpp`, `vkutils/device.cpp`, `Capture/rsx_vr_hooks.*`.

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
| `RPCS3_DLSS` | `motion` (show the motion vectors), `depth` (show the depth), `jitter` (jitter only), `dlaa`, `quality`, `balanced`, `performance`, `ultra` |
| `RPCS3_DLSS_CAMERA` | camera block when the title's profile is not loaded, e.g. `0` (GT5: `c[0]`, column vectors); `0,rows` for row vectors |
| `RPCS3_DLSS_TARGET` | the scene target's address in hex, e.g. `c1980000` |
| `RPCS3_DLSS_MV_SIGN`, `RPCS3_DLSS_JITTER_SIGN` | `++` (default), `-+`, `+-`, `--`: sign conventions passed to DLSS |
| `RPCS3_DLSS_JITTER_SCALE` | jitter amplitude, default 1, `0` turns it off |
| `RPCS3_DLSS_DEPTH_INVERTED` | set if the game's depth is reversed (1 near, 0 far) |

Use VR off (or no headset) and the Vulkan renderer. The log channel is `DLSS`: it reports the scene target,
the motion image, NGX start-up and, every 300 frames, the camera draws matched against the previous frame.

## Test plan for GT5

GT5's profile is in `vr-non-working/` on the branch, so set the camera block explicitly.

1. **Motion vectors first.** `RPCS3_DLSS=motion`, `RPCS3_DLSS_CAMERA=0`, `RPCS3_DLSS_TARGET=c1980000`. In a race:
   - standing still: the screen is near black (no motion) except moving cars;
   - driving straight: the road and scenery fan out from the vanishing point in a smooth colour wheel;
   - a car alongside at the same speed is dark (it does not move on screen), the world behind it is coloured;
   - grey areas are uncovered (sky without depth test, HUD).
   If everything is grey, check the log: no scene target, or "camera draws 0" means the camera block is wrong. If
   cars show the world's colour instead of dark, their matrices are not per draw (or not matched): look at
   "matched/unmatched".
2. **Jitter.** `RPCS3_DLSS=jitter`: the 3D scene should shimmer by under a pixel, the HUD stays still. Then
   `RPCS3_DLSS_JITTER_SCALE=0` with `RPCS3_DLSS=dlaa` gives a reference without jitter.
3. **DLAA.** `RPCS3_DLSS=dlaa`, Resolution Scale 100 or 150: edges should be smooth and stable. Ghosting behind cars
   means the motion vectors' sign is wrong (`RPCS3_DLSS_MV_SIGN=--`); a soft, wobbling image means the jitter sign is
   wrong (`RPCS3_DLSS_JITTER_SIGN=--`).
4. **Upscaling.** `RPCS3_DLSS=quality` with a large window and a lower Resolution Scale.

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
