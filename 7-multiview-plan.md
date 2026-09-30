# Vulkan multiview: both eyes from one draw

Plan for replacing the fork's two-draw stereo (left draw on the primary command buffer, right draw
replayed into a second surface cache) with Vulkan multiview: one `vkCmdDraw*` renders both eyes into
two layers of the same render target, with the vertex shader picking each view's constants by
`gl_ViewIndex`. Written 2026-09-30 against fork commit `aaef58a` (vr5) on the `openxr` branch of
hookmanuk/rpcs3. Evidence labels as in [3-investigation.md](3-investigation.md): `[SOURCE]` verified
in the checked-out code, `[LIVE]` measured at runtime (from the profile notes), `[SPEC]` from the
Vulkan specification (to be re-checked with the validation layers during bring-up), `[INFERENCE]`
expected but not yet proven.

## 1. Why

Stereo today costs a second trip through the driver for every draw, and a parallel copy of every
render target. Measured on the RSX thread (`[LIVE]`, from the profile notes):

| Title | Flat | Stereo (two draws) | Source |
|---|---|---|---|
| Bayonetta BLUS30367, 100%, 90 Hz | 7.8 ms/frame | 13.4, ~11 after the batch fixes | `profiles/BLUS30367-notes.md` |
| Gran Turismo 5 BCUS98114, race start | ~42 FPS dip, RSX 88-94% busy | ~30 FPS; stereo adds ~40% RSX time, ~60% of it driver code | `profiles/BCUS98114-notes.md` |
| WipEout BCES00664, ships in view | - | right-eye replay ~210 ms/s of RSX time, ~125 ms/s of it bind + draw state + render pass per draw | `4-next-steps.md`, Gate 6 |
| Ridge Racer 7 BCAS20001, grid | - | ~2 ms/frame left after the shared-copy fix: "the right eye's second pass through the driver and the per-draw eye constants; multiview would be the structural fix" | `profiles/BCAS20001-notes.md` |
| MotorStorm BCUS98155 | - | "the per-draw stereo cost (multiview)" listed as still open | `profiles/BCUS98155-notes.md` |

Where that time goes `[SOURCE]` (`rpcs3/Emu/RSX/VK/VKDraw.cpp`, `VKGSRender::emit_geometry`):

1. `bind_vr_eye_constants(+1)`: a second constant fill and ring allocation (needed in any design).
2. `bind_texture_env(true)`: every sampled render target is looked up again in `m_vr_right_rtts`; deferred
   copies (format conversions, atlases, mip chains) are rebuilt uncached for the right eye
   (`create_temporary_subresource` with `do_not_cache`), unless a profile rule says the copy is shared.
3. `vr_batch_begin` / `vr_batch_execute`: the right-eye draw is recorded into a secondary command buffer;
   the NVIDIA driver allocates in every `vkBeginCommandBuffer` with render-pass inheritance (~140 secondaries
   a frame in Bayonetta); batches end whenever the left pass ends (depth sampling, barriers, target changes).
4. A second `m_program->bind`, `update_vertex_env`, `update_draw_state`, `vr_apply_box_scissor` and
   `emit_vulkan_draw` per draw, then the left eye's constants, textures and framebuffer are restored.
5. Draws that cannot be batched (feedback loops, programmable blending, conditional rendering) end and
   restart the render pass twice per draw and split the guest occlusion query around the right eye.
6. Outside draws: every blit (`vr_mirror_blit`, `texture_cache::blit_vr_right`), clear (full and
   scissored), surface initialisation (`init_right` in `prepare_rtts`) and CPU bounce (`m_vr_staged`) is
   mirrored by hand into the right-eye surface cache; each of those was a bug in some title first.

Multiview removes items 2-6 entirely and keeps item 1. GPU work per eye is unchanged (both views are
still vertex-shaded and filled), but there are no render pass switches, no secondary buffers, no rebuilt
copies and no second descriptor set per draw.

## 2. What multiview needs from Vulkan `[SPEC]`

- Core since Vulkan 1.1 (`VkPhysicalDeviceMultiviewFeatures::multiview`, `VK_KHR_multiview`). RPCS3
  creates its instance at `VK_API_VERSION_1_2` (`vkutils/instance.cpp:101`) and compiles shaders for
  Vulkan 1.2 / SPIR-V 1.5 (`Program/SPIRVCommon.cpp:144`), so nothing new is needed from the loader.
- A render pass with `VkRenderPassMultiviewCreateInfo` chained to `VkRenderPassCreateInfo`, one
  `viewMask` per subpass (`0b11` = both eyes). The renderpass1 API RPCS3 uses accepts it.
- Framebuffer attachments are image views with `layerCount` >= the number of views (2D array views of
  images with `arrayLayers` >= 2); `VkFramebufferCreateInfo::layers` must be 1.
- Pipelines are created against a multiview render pass. Nothing else in the pipeline changes.
- Shaders read `gl_ViewIndex` (`GL_EXT_multiview`) in any stage. Push constants, descriptors, dynamic
  state, viewport and scissor are shared by both views within a draw.
- Per-view scissor is possible through `multiViewport` (already tested in `vkutils/device.cpp:1008`)
  plus `shaderOutputViewportIndex` (a Vulkan 1.2 feature): the vertex shader writes
  `gl_ViewportIndex = gl_ViewIndex` and the command buffer carries two viewports and two scissors.
- `vkCmdClearAttachments` inside a multiview render pass takes `baseArrayLayer 0, layerCount 1` and
  clears all views in the mask.
- Input attachments (RPCS3's programmable blending) read the fragment's own view. Feedback-loop layouts
  and conditional rendering are per image and per draw respectively; both work inside multiview passes.
- Occlusion queries: a query begun inside a multiview pass occupies N consecutive query indices
  (N = views in the mask). Whether the implementation writes the sum of all views into the first index
  and zero into the rest, or one result per view, is implementation-defined. Either way the sum over
  the N indices is the total over both eyes. See 3.9 for what that means for the guest.
- `maxMultiviewViewCount` is at least 6; two views is always available.

## 3. Design, mapped onto the fork

The principle: **layer 0 of every render target stays exactly what it is today (the guest's picture);
layer 1 is the host-only right eye.** Everything that talks to guest memory (readbacks, flushes,
downloads, the texture cache's synchronisation, presents, screenshots, savestates) already addresses
`{aspect, mip 0, layer 0, count 1}` and is untouched. The second surface cache `m_vr_right_rtts` and
everything that fed it goes away.

### 3.1 Stereo surfaces (render targets with two layers)

- `[SOURCE]` `VKRenderTargets.h`, both `create_new_surface` overloads: the `vk::render_target`
  constructor takes `layers` (currently 1). While the VR renderer is enabled
  (`rsx::vr::camera_probe::render_enabled()`), create colour and depth surfaces with 2 layers. MSAA
  images take layers the same way.
- `render_target::vr_pose` and the pose-stamping logic (`vr_stamp_targets`, `vr_sampled_pose`,
  frame boundaries) are per surface and unchanged.
- Memory doubles for render targets, as it does today with the second cache.
- The right-eye cache and its users are deleted: `m_vr_right_rtts`, `m_vr_right_draw_fbo`,
  `m_vr_right_fbo_images`, the Gate 5 block in `prepare_rtts` (including `init_right`),
  `vr_mirror_blit`, `texture_cache::blit_vr_right`, `surface_cache::find_color_surface`,
  `create_surface_from_rsx_section` users, `m_vr_staged` (see 3.7 for its replacement),
  `m_gpuprof_right_copies`.

Optional later (Phase M4): surfaces the profile classes as "game camera in both eyes" (shadow maps,
cube-map faces, `game_camera_target_widths`, other off-aspect targets unless `offaspect_player_views`)
can stay 1-layer and be drawn with an ordinary pass. Sampling a 1-layer array at layer 1 clamps to
layer 0, so both eyes read the same picture at no extra cost. Constraint: every attachment of one
framebuffer must have the same layer count, so a 1-layer surface bound beside a 2-layer one has to be
promoted (re-created with its content copied, as the surface cache already does on format changes).

### 3.2 Render passes and framebuffers

- `[SOURCE]` `VKRenderPass.cpp`, `renderpass_key_blob`: bits 0-41 are used. Add a 2-bit `view_mask`
  field at bits 42-43: 0 = ordinary, 1 = views `0b11`, 2 = view 0 only, 3 = view 1 only (the last two are
  for the query-strict fallback in 3.9 and for per-eye clears in 3.7). `get_renderpass` chains
  `VkRenderPassMultiviewCreateInfo` with the mask and `correlationMasks = {0b11}` when the field is set.
  `get_renderpass_key(images, ...)` sets the field from the images' layer count, so every caller
  (`prepare_rtts`, the overlay passes, the resolve helpers) picks the right variant without changes.
- `[SOURCE]` `VKFramebuffer.cpp`, `get_framebuffer(dev, w, h, has_input_attachments, renderpass,
  image_list)`: the views are created as `VK_IMAGE_VIEW_TYPE_2D` with one layer. For images with
  2 layers create `VK_IMAGE_VIEW_TYPE_2D_ARRAY` views with `layerCount 2`; `framebuffer_holder::matches`
  compares images, so cached framebuffers never mix the two kinds.
- `[SOURCE]` `VKPipelineCompiler.cpp:82-200` (`pipe_compiler::compile`): `vp.viewportCount` and
  `scissorCount` become 2 when the render pass key has `view_mask == 1`. `pipeline_props` already hashes
  the renderpass key, so multiview pipelines are separate cache entries; the on-disk pipeline cache
  keys change only for VR runs.
- `begin_render_pass`, `renderpass_op`, `close_render_pass`, `g_current_renderpass` bookkeeping: unchanged.
  `g_end_renderpass_hook` and `vr_on_end_renderpass` are deleted with the batches.

### 3.3 Shaders: one variant flag, `gl_ViewIndex` selects everything per eye

The fork already produces two per-draw parameter blocks per subdraw `[SOURCE]` (`emit_geometry`:
`alloc_size = pass_count * 168 * 2`, `update_vertex_env(sub_index * 2)` for the left eye and
`update_vertex_env(sub_index * 2 + 1)` for the right). Each 168-byte `draw_parameters_t` entry names
that eye's `xform_constants_offset` (its transformed camera constants) and `vs_context_offset` (its
vertex context: viewport matrix, HUD-box mapping, `vr_keep_depth`), and the vertex shader copies the
fragment offsets (`fs_texture_base_index` etc.) into the flat `draw_params_payload` varying
(`VKVertexProgram.cpp:322-333`). So the whole per-eye state is one index away:

- Vertex shader `[SOURCE]` `VKVertexProgram.cpp:87`: `#define get_draw_params()
  draw_parameters[draw_parameters_offset]` becomes `draw_parameters[draw_parameters_offset +
  gl_ViewIndex]` in the VR variant, with `#extension GL_EXT_multiview : require`. The push constant
  stays one `uint`; the two entries are adjacent by construction. `main()` also writes
  `gl_ViewportIndex = gl_ViewIndex` (`GL_ARB_shader_viewport_layer_array`) so each view uses its own
  scissor (3.6). The flat payload then carries per-view fragment offsets automatically (a flat varying is
  written per view).
- Fragment shader: reads no draw parameters directly; it gets them through the payload. It only needs
  `gl_ViewIndex` for texture layers (3.4).
- Variant flag: a free bit in the program control word for both `RSXVertexProgram::ctrl` and
  `RSXFragmentProgram::ctrl` (`gcm_enums.h:450-477` lists the taken bits; the fork's bits go beside
  `RSX_SHADER_CONTROL_INSTANCED_CONSTANTS` and `RSX_SHADER_CONTROL_INTERPRETER_MODEL`), set in
  `get_current_vertex_program` / `get_current_fragment_program` while the VR renderer is enabled. The
  storage hashes include `ctrl`, so flat and VR shaders coexist in the shader cache and a VR run never
  binds a flat shader to a multiview pass.
- Shader interpreter `[SOURCE]` `VKShaderInterpreter.cpp`, `VertexInterpreter.glsl`,
  `FragmentInterpreter.glsl`: the interpreter is the async fallback while real shaders compile, so it
  needs the same variant from day one (its option flags select compiled variants already; add the VR
  flag with the same defines and the array samplers of 3.4).

### 3.4 Textures: every 2D sampler becomes an array sampler in VR shaders

A draw that samples a render target (post-processing, feedback loops, reflections) must read layer 0 in
view 0 and layer 1 in view 1. Descriptors are shared by both views, so the selection has to be in the
shader coordinates, not in the binding:

- In VR shader variants every 2D sampler type becomes its array form: `sampler2D` ->
  `sampler2DArray`, `sampler2DMS` -> `sampler2DMSArray`, `sampler2DShadow` -> `sampler2DArrayShadow`,
  the `usampler2D` stencil mirrors likewise. Cube and 3D samplers are unchanged (cube maps gathered from
  render targets are shared between eyes today, and stay shared). `[SOURCE]` type selection:
  `VKFragmentProgram.cpp:214-261`, `FragmentProgramDecompiler.cpp:310-322`, vertex textures in
  `VKVertexProgram.cpp` (`vtex_location`).
- `[SOURCE]` `RSXFragmentTextureOps.glsl:74-94`: the `TEX2D*` macros (`texture`, `textureLod`,
  `textureGrad`, bias, the manual projective forms and the shadow forms) append the layer:
  `vec3(COORD_SCALE2(index, coord2), float(gl_ViewIndex))`. RPCS3 never uses `textureProj` (its
  projective forms divide by hand), and the array shadow sampler takes `vec4(uv, layer, ref)`, so every
  macro has an array equivalent. MSAA fetch helpers take `ivec3`; size queries return `ivec3` and the
  helpers that read `.xy` keep doing so.
- Ordinary uploaded textures are 1-layer images. A 2D image with one layer can be viewed as
  `VK_IMAGE_VIEW_TYPE_2D_ARRAY`, and sampling layer 1 of a 1-layer array clamps to layer 0, so no
  per-texture flag and no extra shader permutations are needed. `[SOURCE]` `vkutils/image.cpp:365`:
  `image_view` picks 2D for `arrayLayers == 1`; in VR mode the sampling views in `viewable_image::get_view`
  (its cache key gains the view type) and the texture cache's explicit views use 2D_ARRAY for all 2D images.
  Depth-as-colour and stencil mirror views (`TEX_NAME_STENCIL`, `frag_depth_input_location`) follow.
- Deferred copies `[SOURCE]` `VKTextureCache.cpp`, `create_temporary_subresource` and the
  `deferred_request_command` ops (`copy_image_static/dynamic`, `atlas_gather`, `mipmap_gather`,
  `blit_image_static`): when any source section is a 2-layer surface the temporary image is created
  with 2 layers and the copies run per layer; otherwise it stays 1-layer (and clamps). This replaces the
  fork's right-eye rebuild (`to_right` in `bind_texture_env`), its `shared_copy` rules (dummy 3x3
  textures, cube maps, atlases, mip chains) and the `m_gpuprof_right_copies` counter. The copies are
  cached again like the left eye's (the fork had to mark right-eye rebuilds `do_not_cache`).
- `cubemap_gather`, `cubemap_unwrap`, `_3d_gather`, `_3d_unwrap`: layer 0 sources only, as today.
- `bind_texture_env(bool vr_right_eye)` loses its parameter and the whole right-eye branch;
  `bind_interpreter_texture_env` likewise.

### 3.5 Constants: one paired allocation per draw

- `[SOURCE]` `VKGSRender.cpp`, `bind_vr_eye_constants(eye_sign, source_offset, source_size)`: keep the
  fill-from-guest-registers into a CPU scratch buffer and the two `apply_render_eye` calls (all camera
  math, classification, HUD-box mapping, linked blocks, FOV remap live there and do not change), but
  allocate the two results together: one `alloc_bytes(align(size) * 2)` on the transform-constants
  ring, left at `+0`, right at `+align(size)`, one `window<16>` covering both, and two
  `xform_constants_offset` values (`m_xform_constants_dynamic_offset` for entry `2n`, plus
  `align(size) / 16` for entry `2n + 1`). `update_vertex_env(id, ...)` takes the eye's offset instead
  of reading the member. The 8 KB full bank twice (interpreter, indexed constants) is far inside
  `maxUniformBufferRange`.
- Draws the classifier leaves alone (HUD "as drawn", shadow maps, passes with no camera block) get two
  identical entries pointing at one allocation: both views draw the same picture, which is what the
  replay does today, with no special case.
- The HUD-box vertex context (`vr_hud_vertex_env(eye_sign, ...)`) already runs once per eye before each
  eye's `update_vertex_env`; keep that order so each entry's `vs_context_offset` is its own.
- Instanced draws (`is_trivial_instanced_draw`, `_ENABLE_INSTANCED_CONSTANTS`): today excluded from
  stereo. First cut: both views share the one instancing table, so the right eye equals the left (no
  gap, no parallax) instead of being skipped. Phase M4: fill the lookup table and constants array twice
  (`fill_constants_instancing_buffer` with each eye's transform, as `evidence/pure/instanced-per-eye.patch`
  prototyped), store the right eye's base in the entry's spare `reserved` word, and index
  `instanced_constants_array[view_base + corrected_offset]` in `_fetch_constant`.

### 3.6 `emit_geometry` after the change

One path instead of three (left, batched right, replayed right):

1. `bind_vr_eye_constants` fills and allocates both eyes (3.5); per eye it runs the HUD-box context and
   records that eye's box scissor (`vr_apply_box_scissor` computes a rect per eye from
   `map_box_scissor`; the probe's `clear_box_mapped` / `m_box_mapped` are per eye already).
2. `update_vertex_env(sub_index * 2, left)` and `update_vertex_env(sub_index * 2 + 1, right)`; the push
   constant is the left entry's index.
3. `update_draw_state` sets two viewports (identical) and two scissors (identical unless a HUD-box
   draw). `begin_render_pass` opens the multiview pass on the 2-layer framebuffer.
4. `vr_clear_shown_region` (one `vkCmdClearAttachments`, clears both views).
5. One `emit_vulkan_draw()`.

Deleted: `vr_batch`, `vr_feedback` and `vr_suspend_query` decisions, `vr_query_continuation`, the
secondary command buffer machinery (`vr_secondary_cb`, `vr_primary_batches`, `vr_batch_begin`,
`vr_batch_flush`, `vr_batch_execute`, `m_vr_batch_*`, `RPCS3_VR_BATCH`), the per-draw replay block, the
restore of left constants/textures/framebuffer, `m_vr_right_rtts.on_write`. The stereo inspector and
profile generator hooks stay where they are (before the draw).

Per-eye scissor needs `shaderOutputViewportIndex`. Fallback if a device lacks it (NVIDIA has it): one
scissor equal to the union of both eyes' rects. HUD-box clipping then leaks between eyes on boxed draws
only, which is acceptable for a fallback; the fork's HUD titles (GT5, SotC) should be checked with it off.

### 3.7 Writes to render targets outside draws

Every path that writes layer 0 without a draw must also write layer 1, or the right eye keeps stale
pixels. This is the same list the fork mirrored by hand; with layers it is one `layerCount = 2` per site:

| Site `[SOURCE]` | Today | With layers |
|---|---|---|
| `VKGSRender::clear_surface` (`VKGSRender.cpp:1397`): in-pass `vkCmdClearAttachments`, out-of-pass `vkCmdClearColorImage` (`:680`), partial clears | mirrored into `m_vr_right_rtts`, with `vr_right_clear` for HUD-box mirror clears | in-pass clears cover both views; out-of-pass clears use the image's layer count; the per-eye HUD-box rectangle clear (different rect per eye) runs as two single-view passes (`view_mask` 2 and 3) or a scissored clear draw |
| Surface initialisation and inheritance (`surface_store.h` `prepare_render_target`, `invalidate_surface_contents`, `split_surface_region`, `on_write_copy`; `VKRenderTargets.h` transfers via `vk::copy_image` / `copy_scaled_image`) | `init_right` re-runs the left eye's init on the right surface | `erase_bkgnd` clears and `old_contents` copies run with `layerCount = 2` when both surfaces are stereo; a 1-layer source fills both layers |
| Blit engine (`texture_cache::blit`, NV3089/NV0039 paths in `VKTextureCache.cpp`, `texture_cache_blit_helpers.h`) | `vr_mirror_blit`, `blit_vr_right`, `vr_redirect_previous_frame_copy` | surface -> surface: both layers; texture -> surface: layer 0 into both layers; surface -> memory or non-surface: layer 0 only. `vr_redirect_previous_frame_copy` (profile `current_frame_copies`) keeps its address logic |
| Reload of a surface from guest memory after CPU/SPU writes (`invalidate_surface_contents`, texture cache upload into `framebuffer_storage`) | ICO: `m_vr_staged` keeps right-eye pixels through the memory bounce; inFamous 2: left-eye only | layer 0 is copied to layer 1 after the reload (right eye shows the CPU-written picture, as the left does); the ICO staged right-eye copy becomes "upload the staged image into layer 1 instead", same trigger, one image less |
| MSAA resolve / unresolve (`VKResolveHelper.h`: `cs_resolve_task`, `cs_unresolve_task`, the depth/stencil overlay passes) | separate surfaces, separate resolves | compute tasks address `image2DArray`/`image2DMSArray` and loop layers; overlay passes run once per layer with per-layer views |
| `vr_realign_blend_targets` warp (`m_vr_warp_scratch`) | per eye already | per layer |
| Early readback copies (`m_vr_readback_ranges`, `flush_listed_sections`), occlusion depth readback | layer 0 | unchanged |

### 3.8 Present and screenshots

- `[SOURCE]` `VKPresent.cpp:600-700`: `image_to_flip2` is found in `m_vr_right_rtts`. Instead the right
  eye is layer 1 of `image_to_flip`. `vk::xr::publish_eyes` (`VKOpenXR.cpp:1368`) takes a layer per
  source and copies with `srcSubresource.baseArrayLayer = layer`; the desktop side-by-side preview
  (`video_out_calibration_pass` with two inputs), F12 and `RPCS3_VR_SHOT` get a per-layer 2D view of the
  display surface. Native PS3 3D (`avconfig.stereo_enabled`, two guest addresses) is untouched.
- Overlays (`m_xr_overlay_img`, `ui_overlay_renderer_xr`), the OpenXR frame thread, pose ids, FOV
  declaration, fixed screen, reprojection margin: unchanged.

### 3.9 Occlusion queries and conditional rendering

`[SOURCE]` Today a guest occlusion query is split around the right-eye draw so the guest counts the
left eye only (`emit_geometry`, `vr_batch_execute`). Inside a multiview pass a query counts both views,
across N consecutive query indices, and the split between "sum in the first index" and "one per index"
is implementation-defined `[SPEC]`.

Proposed guest semantics: **the guest sees the average of both eyes.** `occlusion_query_manager`
(`VKQueryPool.cpp`) allocates two consecutive slots for a query begun in a multiview pass; result
collection (`VKGSRender::get_occlusion_query_result` and the conditional-render predicate path) already
sums a query's `indices`; slots recorded in multiview segments are summed and halved. For "any samples
passed" (conditional rendering, ZCULL visibility) this is better than left-only: an object visible to
one eye is drawn for both. For pixel counts (lens flares, occlusion fades) it is the count from the
midpoint camera, which is where the game's own camera sits.

Strict fallback for validation (`RPCS3_VR_STRICT_QUERIES=1`): a draw inside an active guest query
renders view 0 in a `view_mask = 2` pass inside the query and view 1 in a `view_mask = 3` pass outside
it, on the same layered framebuffer. Same cost as today's replay, only for queried draws, no texture or
cache work. WipEout draws its world inside queries (Gate 5 note), so this mode is for A/B comparisons,
not for shipping.

Open `[SPEC]` point to check with the validation layers: whether a query may be active across the start
of a multiview render pass instance. RPCS3 prefers to begin queries outside passes on strict drivers
(`use_strict_query_scopes`); if the multiview rule forbids that, begin and end query segments inside the
pass in VR mode (the manager already supports many segments per query).

Conditional rendering (`_vkCmdBeginConditionalRenderingEXT`) and programmable blending (input
attachments with the self-dependency barrier) work inside multiview passes and lose their "keep the
per-draw replay" special cases.

Per title: GT5's config already has `Disable ZCull Occlusion Queries` on (kept as a small gain in
`BCUS98114-notes.md`), so none of this applies to the headline title. That per-game setting is also
the escape hatch for any title where the averaged counts ever show an artefact. Two slots per query
halve the pool's capacity; raise the pool size so the "out of free occlusion slots, forcing hard sync"
path is not hit more often than today.

### 3.10 Device support and switches

- `[SOURCE]` `vkutils/device.cpp`: `physical_device::get_physical_device_features` chains optional
  feature structs; add `VkPhysicalDeviceMultiviewFeatures` (or `VkPhysicalDeviceVulkan11Features`) and
  the Vulkan 1.2 `shaderOutputViewportIndex`; enable them in `render_device::create`; expose
  `get_multiview_support()` beside the existing `get_*_support()` accessors and `maxMultiviewViewCount`.
- The two-draw path stays (decision 2026-09-30): it is the runtime fallback on a device without
  multiview, and the A/B reference on the same build. Selection: multiview when the device supports it,
  `RPCS3_VR_MULTIVIEW=0` (later a `Video > VR` setting if it earns one) forces two draws. The right-eye
  surface cache and the mirror sites therefore remain in the code, compiled but idle on the multiview
  path; section 3.1's deletion list becomes "unused while multiview is active".
- `RPCS3_VR_GPUPROF=1` keeps GPU ms per target and draws; the batch and rebuild counters go.

### 3.11 What does not change

`rsx_camera_probe.{h,cpp}` (classification, `apply_render_eye`, rotation, FOV remap, HUD box, linked and
pre-projected blocks), the profile format and every profile, the profile generator and inspector, the
frame-boundary and pose-stamp logic, the feedback-texture reprojection (per-eye texture parameters reach
the fragment shader through the payload), the OpenXR thread and pacing, the fixed screen, the home-menu
VR tab, the frame-rate patches, early readback copies, occlusion depth readback.

## 4. Phases and gates

Work on a branch off `openxr` (`multiview`), each phase behind `RPCS3_VR_MULTIVIEW` until M5. Validation
layers on (`Video > Debug output`) for M0-M2: the exit test of each phase includes "zero validation
errors through a race / a level".

### M0 - plumbing, both views identical

- [ ] Device features and `get_multiview_support()`.
- [ ] Render pass `view_mask` key bits and `VkRenderPassMultiviewCreateInfo`; array views in `get_framebuffer`.
- [ ] Pipelines with two viewports/scissors for multiview keys; `update_draw_state` sets both.
- [ ] Shader variant flag; `gl_ViewIndex` draw-parameter indexing; `gl_ViewportIndex`; interpreter variant.
- [ ] Render targets created with 2 layers; present layer 1 as the right eye.
- [ ] Both draw-parameter entries point at the same constants.

Gate: WipEout on the desktop shows two identical eyes (side-by-side capture: pixel-identical halves),
holds 60 FPS on the grid, no validation errors. Proves the pass, framebuffer, pipeline and shader
plumbing before any stereo logic moves.

### M1 - stereo through multiview

- [ ] Paired constant allocation and per-entry `xform_constants_offset`.
- [ ] Per-eye HUD-box context and scissors.
- [ ] Layered clears, initialisation, inheritance, blits, resolves (3.7) for colour and depth.

Gate: the Gate 5 disparity table on the Vineta K start line, generated vs native, within 1 px:
far +50, rail +49, near edge +26, ship nose +26, ship body +19, HUD 0. the rotation-invariance audit
(`RPCS3_VR_AUDIT=25`, playbook section "rotation audit") passes as on the two-draw path. At this point post-processing still reads layer 0 for both eyes
(NFS/Blur/GT5 will look wrong; that is M2).

### M2 - textures by layer

- [ ] Array samplers in fragment, vertex and interpreter shaders; texture-op macros with the layer.
- [ ] 2D_ARRAY sampling views everywhere in VR mode; view cache keyed by type.
- [ ] Deferred copies create 2-layer temporaries from stereo sources and copy per layer; cached again.
- [ ] Remove the right-eye branch of `bind_texture_env`.

Gate: the titles whose bugs came from right-eye texture reads look right in both eyes on the desktop,
Gran Turismo 5 first (car shadows: feedback loop on the MSAA scene target; per-car texture sharing;
the rear-view mirror in the box), then NFS Most Wanted lighting (deferred copy of a render target), Blur
(scaled MSAA blits), ICO (memory bounce, older-frame reprojection),
Ridge Racer 7 (environment cube map gathered from off-aspect faces, road reflection tiles with
`offaspect_player_views`), Bayonetta motion vectors, Demon's Souls soft particles (depth sampling that
broke the batches). Compare each against a two-draw capture of the same savestate
(`RPCS3_VR_MULTIVIEW=0`), mean absolute RGB difference per eye within the Gate 4 noise floor.

### M3 - delete the second draw

- [ ] Remove batches, replay, query splitting; queries as in 3.9; strict mode switch.
- [ ] Remove `m_vr_right_rtts` and every mirror site (3.1, 3.7).
- [ ] `RPCS3_VR_GPUPROF` reports 0 batches, 0 rebuilds.

Gate (performance, the point of the work: `rsx_sample.py` / `RPCS3_VR_GPUPROF=1`, same savestates as
the notes). GT5's race start is the headline number; the others confirm the gain is general:

| Title | Now (two draws) | Target with multiview |
|---|---|---|
| Bayonetta 100% 90 Hz, RSX ms/frame | ~11 (flat 7.8) | <= 9 |
| **GT5 race start, stereo FPS dip** | ~30 (flat ~42) | within 10% of flat (the RSX thread is CPU-bound in flat too, so flat is the ceiling; stereo RSX time within ~5% of flat) |
| WipEout ships in view, right-eye replay RSX time | ~210 ms/s | 0 (no replay exists) |
| Ridge Racer 7 grid, stereo idle | ~3.5 ms/frame | >= 5 ms/frame |
| MotorStorm pack start 300% | 64-84 FPS | within 10% of flat (89-90) unless GPU-bound |

Headset gate: each playable title in `vr-games.md` run in the headset by Matt, looking for anything
the two-draw path did not show: eye mismatch on HUD-box clips, stale right-eye pixels after menus and
videos (uncleared display buffers), occlusion-driven effects (lens flares, popping) with the averaged
query semantics.

### M4 - optimisations

- [ ] Per-view instanced constants (3.5).
- [ ] 1-layer surfaces for game-camera targets with promotion on mixed binding (3.1). Memory is not a
      priority (decision 2026-09-30); do this only if it shows a fill-rate gain on GT5's shadow atlases.
- [ ] Layered compute resolves instead of per-layer loops if the loop shows up in `RPCS3_VR_GPUPROF`.

### M5 - cleanup and release

- [ ] Two-draw path kept as fallback and A/B reference (decision 2026-09-30); make sure both paths
      still build and run on every title in section 5.
- [ ] Update `profiles/README.md` (the copy-sharing rules that no longer exist), `vr-settings.md`,
      `4-next-steps.md` Gate 6, this file's status.
- [ ] Release vr6 with the title matrix results.

## 5. Validation matrix

| Title | Exercises | Compare with |
|---|---|---|
| WipEout BCES00664 | camera shear + c[465], queries around the world pass, HUD box, 90 Hz pacing | Gate 5 disparity table, Gate 2 captures |
| Pure BLUS30182 | column-vector matrices, pause menu in both eyes, 1:1 blit mirror | `evidence/pure/` |
| ICO / SotC BCUS98259 | memory bounce (`m_vr_staged`), reprojection of older frames, HUD keep-depth, pre-projected sprites, occlusion depth readback | `evidence/ico/`, `BCUS98259-*notes.md` |
| Blur BLUS30295 | scaled MSAA blits, depth-offset HUD plane, mirror | `evidence/blur/` |
| NFS MW BLUS31010 | format-converting deferred copies (lighting), `column_vectors_xyw` | `evidence/nfsmw/` |
| GT5 BCUS98114 | feedback loops (car shadows), sub-viewport mirror in the box, uncleared 2D menus, early readbacks | `BCUS98114-notes.md` (race-start FPS is the headline number) |
| Bayonetta BLUS30367 | soft particles sampling depth, linked camera blocks, fragment constant overrides | `BLUS30367-notes.md` perf table |
| Demon's Souls BLUS30443 | clip-space scene draws, fog gate non-rigid block, DoF override | `BLUS30443-notes.md` |
| MotorStorm BCUS98155 | mip-chain gathers, render-target memory sampled as textures (flush waits) | `BCUS98155-notes.md` |
| Ridge Racer 7 BCAS20001 | cube map gathered from six off-aspect faces (shared copy today), `offaspect_player_views` (per-eye reflection tiles), resolution-scaled constants | `evidence/rr7/`, `BCAS20001-notes.md` |
| inFamous 2 BCUS98125 | SPU-processed layer (layer 1 copied from layer 0 after the reload) | `evidence/infamous2/`, `BCUS98125-notes.md` |

Tools: `tools/sbsshot.ps1` (both eyes), `RPCS3_VR_SHOT`, the rotation audit (`RPCS3_VR_AUDIT`), `tools/rsx_sample.py`,
`tools/sampler.py`, `RPCS3_VR_GPUPROF=1`, the stereo inspector (`RPCS3_STEREO_INSPECT`) for draw-level
diffs between the two paths, the Vulkan validation layer.

## 6. Risks and open points

1. **Query semantics** (3.9): the averaged result is a design choice, and the spec leaves the
   per-index split to the implementation. Both are handled by summing N slots; the strict switch exists
   to A/B any occlusion-driven effect that looks different.
2. **Queries spanning pass boundaries** (3.9): a `[SPEC]` rule to confirm with the validation layer in
   M0; the fix is local to where segments begin.
3. **Shader permutations**: every VR run compiles its own variants (the flat cache is not reused), so
   first runs of each title stall on compiles as a fresh install does; the interpreter variant must be
   ready in M0 or draws are skipped while compiling. Not a new kind of cost: the fork already has
   `[VR]`-specific shader source through `vr_keep_depth`.
4. **Array sampling helpers**: every 2D helper in the GLSL snippets (`RSXFragmentTextureOps.glsl`,
   MSAA fetch, `textureQueryLevels`/`textureSize` users, the interpreter's generic sampling) needs the
   layer argument. Miss one and a title samples layer 0 in both eyes. The M2 title set covers each kind
   of source (plain RT, MSAA RT, depth RT, stencil mirror, deferred copy, atlas, mip chain).
5. **Descriptor-free view selection relies on layer clamping** for 1-layer textures. That is core GLSL
   behaviour (array layer coordinates are clamped), not an extension; no `nonuniformEXT` or descriptor
   indexing is involved.
6. **Surface inheritance and memory pressure**: `surface_store` re-creates and inherits surfaces in
   several paths (`split_surface_region`, `invalidate_surface_contents`, spill/trim). Each copies layer 0
   today; each needs `layerCount = 2`. A missed path shows as a stale right eye after target reuse, which
   the M1 gate (uncleared 2D menus, GT5) and the ICO recycled-target case catch.
7. **Per-eye scissor** needs `shaderOutputViewportIndex`; the union-scissor fallback leaks HUD-box
   clipping between eyes on boxed draws only.
8. **GPU-bound titles gain little**: MotorStorm at 300% and GT5 at high scale are limited by fill;
   multiview removes pass switches and copies, not shading. The M3 targets say "within 10% of flat",
   not "flat".
9. **Drivers other than NVIDIA** are untested for the fork as a whole; multiview, multiViewport and
   `shaderOutputViewportIndex` are all widely supported on desktop, and the feature check falls back to 2D.
10. **inFamous 2's SPU layer** stays mono in the right eye (layer 1 copied from layer 0), as today.

## 7. Size

Removed: the right-eye batch and replay in `emit_geometry`, `vr_batch_*`, `g_end_renderpass_hook`,
`m_vr_right_rtts` and its `prepare_rtts` block, `vr_mirror_blit`, `blit_vr_right`,
`find_color_surface`, `m_vr_staged`, the right-eye branch of `bind_texture_env`, `vr_right_clear`
and the partial-clear mirrors: on the order of 2,000 lines. Added: render pass / framebuffer /
pipeline variants, feature plumbing, shader variant defines and array-sampler macros, paired constant
allocation, layer counts at the write sites, present by layer, query pairing: on the order of 800
lines, most of them one-line `layerCount` changes at existing sites. Files touched are the ones cited
above plus `VKQueryPool.{h,cpp}`, `VKShaderInterpreter.cpp`, `VKResolveHelper.h`, `VKTexture.cpp`,
`VKTextureCache.{h,cpp}`, `vkutils/image.{h,cpp}`, `Program/GLSLCommon.cpp`, the three interpreter
GLSL files and `gcm_enums.h`.

## 8. Decisions (2026-09-30, Matt)

The goal is performance; nothing else motivates the change.

1. **Keep the two-draw path.** It stays as the runtime fallback and the A/B reference (3.10, M5).
2. **Occlusion queries: averaged over both eyes**, with the strict left-only dev switch (3.9). What
   changes for the guest: counts are the mean of the two eyes instead of the left eye's; an object
   visible to only one eye passes "any samples" tests for both; two query slots per query. GT5 runs
   with ZCull occlusion queries disabled, so it is unaffected; that per-game setting is the escape
   hatch elsewhere.
3. **Memory is not a priority.** Every render target gets two layers; the 1-layer optimisation in M4
   is only worth doing for fill rate, if at all.
4. **GT5 gates the work.** It is first in the M2 texture gate and the headline number in M3. Its
   ceiling is flat's own RSX-bound ~42 FPS dip at the race start; multiview removes the stereo extra
   (~40% RSX time), it cannot lift the flat dip.
5. Headset testing goes title by title as each passes the desktop comparison, GT5 first.
