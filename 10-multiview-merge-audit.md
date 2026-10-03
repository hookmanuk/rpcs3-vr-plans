# Multiview merge audit: what the `multiview` branch adds to upstream's files

**Upstream** in this document is [RPCS3/rpcs3](https://github.com/RPCS3/rpcs3), the repository the fork was
made from, not hookmanuk/rpcs3. The fork's `master` is RPCS3's `master` as of `9e86f165` (2026-09-19, an RPCS3
commit by RPCS3's Elad) plus six issue-template commits, so every "upstream file", "upstream line" and
"upstream commits a year" figure below is RPCS3's code and RPCS3's history. RPCS3's commits after 2026-09-19
are not in it: the fork's `master` has not been synced since (section 4, "Not done").

Audited 2026-10-03: `multiview` at `2a0afd28` against `openxr` at `d582cbeb` (the fork after the
restructuring of [8-upstream-merge-audit.md](8-upstream-merge-audit.md)) and upstream `master` at
`9e86f165` (2026-09-19, the merge base of both). `openxr..multiview` (9 commits, one of them identical in
content to `openxr`'s latest) is the complete multiview delta. Upstream churn is commits on `master` touching a
file in the 12 months to the base (6 months in brackets).

**Exposure** is the measure this audit adds. For each fork hunk in an upstream file, it counts the
upstream commits in that year that changed lines within 3 lines of the hunk (`git log -L` on the base).
It shows where the next merge is likely to conflict better than a file's churn does: a file with 46
commits a year can be safe if the fork's lines sit where nobody edits. Exposure 0 means upstream did not
touch that spot all year. [tools/merge/hunk_exposure.sh](tools/merge/hunk_exposure.sh) recomputes it.

The question: how intrusive multiview is compared with upstream's code, and how much of it can be made
cheaper to merge without changing what the emulator does.

## 1. Short answer

- **Multiview nearly doubles the fork's footprint in upstream files.** `openxr` carries 928 changed
  lines in 73 upstream files. `multiview` carries 1,628 in 95: 700 more lines, 22 upstream files touched
  for the first time, and 125 more upstream lines modified rather than added to.
- **Most of it is plumbing in upstream's lower layers**, not VR logic. Two-layer render targets have to
  be carried through the texture cache, render targets, MSAA resolve, render pass and framebuffer keys,
  image views, blits, the device setup, both shader generators, the shader interpreter and five GLSL
  snippets. The port already kept the VR logic in fork files: `VKGSRender.cpp`, `VKDraw.cpp` and
  `VKPresent.cpp` only gained hooks of one to a few lines.
- **About half of it sat where upstream was busy.** 374 of multiview's 711 hunk lines were in spots
  upstream edited during the year. The hot ones were `VKTextureCache.cpp` (upstream's August 2026
  multi-layer transfer work went through the same functions), `VKShaderInterpreter.cpp`,
  `VKFragmentProgram.cpp` and the ROP epilogue (programmable blending, 10 commits in 6 months), and one
  line in `gcm_enums.h`, in the middle of the list where upstream adds shader control bits (upstream
  edited the lines around it 7 times in the year).
- **Done:** commit `55d63cc4` on branch
  [`ccr-887e03d9-ccgvu0`](https://github.com/hookmanuk/rpcs3/tree/ccr-887e03d9-ccgvu0) of hookmanuk/rpcs3
  (on top of `multiview`) moves what can move into fork-only files and turns inline blocks into one-line
  hooks.
  Multiview's footprint drops from **700 to 485 lines** (22 to 20 new upstream files), and its lines in
  spots upstream edited during the year drop from **374 to 215**. Behaviour is unchanged (section 4). It
  compiles; it has not been run.
- **What remains (about 480 lines) is inherent to two-layer targets.** It is mostly single-line edits:
  a layer count where upstream wrote `1`, or a layer parameter on an upstream function. It shrinks
  further only with design changes (section 5).

## 2. Numbers

The whole branch against RPCS3's code (`9e86f165`). New files never conflict; the merge cost is in the
RPCS3 files the fork modifies, and most of all in the lines where RPCS3 itself kept editing:

| Branch | New fork files | RPCS3 files modified | Fork lines in RPCS3 files | Of those, in spots RPCS3 edited in the year before |
|---|---:|---:|---:|---|
| `openxr` | 98 (33,824 lines) | 73 | 928 | 413 lines in 44 files |
| `multiview` | 98 (34,583 lines) | 95 | 1,628 | 784 lines in 64 files |
| after this work (`f6e8731f`) | 100 (35,000 lines) | 93 | 1,413 | 625 lines in 60 files |

Multiview's own share, separated from openxr's:

| | Upstream files | Lines added | Upstream lines modified or removed | Total |
|---|---:|---:|---:|---:|
| `openxr` | 73 | 855 | 73 | 928 |
| `multiview` | 95 | 1,430 | 198 | 1,628 |
| after this work (`f6e8731f`) | 93 | 1,228 | 185 | 1,413 |
| multiview's share before / after | +22 / +20 | +575 / +373 | +125 / +112 | +700 / +485 |

| Multiview's hunks | Hunks | Lines | In spots upstream edited during the year | Exposure (sum) |
|---|---:|---:|---|---:|
| `multiview` | 212 | 711 | 100 hunks, 374 lines | 196 |
| after | 199 | 502 | 89 hunks, 215 lines | 163 |

Per file, sorted by multiview's footprint. "Fork lines" is insertions plus deletions against `master`.
The exposure columns count multiview's hunks only, not openxr's.

| File | Fork lines `openxr` / `multiview` / after | Up 12m (6m) | Exposure before / after | What multiview does there |
|---|---|---:|---|---|
| `VK/VKTextureCache.cpp` | 42 / 123 / 89 | 25 (15) | 35 / 34 | Copies of stereo targets get two layers: `copy_transfer_regions` per layer, `find_cached_image` by layer count, temporaries' layer count, atlas and mip-chain builders cover both layers. Helpers moved out; the rest is per-layer plumbing in five upstream functions |
| `VK/VKGSRender.cpp` | 59 / 79 / 75 | 46 (22) | 3 / 3 | One-line hooks (`bind_viewport`, per-eye clears, view mask and two-layer framebuffer in `prepare_rtts`); the query-pair lines are gone |
| `VK/VKDraw.cpp` | 39 / 63 / 63 | 35 (14) | 12 / 12 | One-line hooks: array and null views at 10 descriptor bind sites, the query begun inside the pass |
| `VK/vkutils/device.cpp` | 29 / 63 / 63 | 9 (4) | 9 / 9 | Multiview, `multiViewport` and viewport-index features queried and enabled, upstream's own pattern |
| `VK/VKShaderInterpreter.cpp` | 3 / 61 / 23 | 25 (16) | 21 / 18 | The interpreter's multiview variant: now one-line calls, plus four option-mask lines |
| `VK/VKTextureCache.h` | 53 / 59 / 59 | 10 (8) | 8 / 8 | Declarations with layer parameters |
| `VK/VKQueryPool.cpp` | 0 / 49 / 9 | 1 (1) | 0 / 0 | Query pairs: allocation moved out; pair freeing and the pair's average stay (8 lines) |
| `VK/VKVertexProgram.cpp` | 3 / 47 / 11 | 15 (6) | 7 / 10 | Multiview variant: now 7 one-line insertions and no modified upstream line (two were modified before; exposure counts the neighbours of an insertion too) |
| `GLSLSnippets/RSXProg/RSXFragmentTextureOps.glsl` | 16 / 44 / 48 | 12 (1) | 6 / 0 | Array forms of the 2D texture macros: now an override block in a spot upstream did not touch all year. Before, one upstream line was modified and two were moved |
| `VK/VKRenderTargets.h` | 25 / 43 / 43 | 13 (11) | 2 / 2 | Two-layer surfaces (creation, sinks) |
| `VK/VKResolveHelper.h` | 0 / 42 / 42 | 2 (1) | 2 / 2 | Layer parameter on the 8 MSAA resolve/unresolve passes |
| `VK/vkutils/image.cpp` | 0 / 38 / 14 | 10 (0) | 10 / 8 | `get_layer_view` split from `get_view`; `as_array` moved out |
| `VK/VKRenderPass.cpp` | 7 / 36 / 26 | 4 (4) | 1 / 0 | View-mask key bits, `get_renderpass_view_mask`, pre-end hook; multiview create info moved out |
| `RSXThread.cpp` | 22 / 31 / 24 | 49 (26) | 5 / 5 | Program control bit: now one call per program, upstream's lines restored |
| `VK/VKRenderTargets.cpp` | 0 / 30 / 23 | 10 (8) | 2 / 1 | Layer counts, per-layer resolve; `g_vr_stereo_layers` and the layer copy moved out |
| `VK/VKFragmentProgram.cpp` | 3 / 28 / 9 | 31 (10) | 19 / 8 | Array samplers: now 3 one-line insertions and 1 modified line |
| `VK/VKResolveHelper.cpp` | 0 / 28 / 28 | 0 (0) | 0 / 0 | Layer parameter plumbing |
| `VK/VKTexture.cpp` | 0 / 25 / 25 | 11 (8) | 5 / 5 | `blitter::scale_image` per layer |
| `VK/VKFramebuffer.cpp` / `.h` | 0 / 23 / 23 | 4 (2) | 8 / 8 | Framebuffer key bits, layered attachment views |
| `VK/vkutils/image.h` | 0 / 13 / 13 | 7 (0) | 5 / 5 | `stereo_layers`, `as_array`, `get_layer_view` declarations |
| `rpcs3/CMakeLists.txt` | 0 / 9 / 9 | 16 (9) | 0 / 0 | `BUILD_RPCS3_GUI` for Linux core-only builds (modifies three upstream `if` lines) |
| `GLSLSnippets/RSXProg/RSXROPEpilogue.glsl` | 0 / 9 / 9 | 12 (10) | 13 / 13 | `frag_depth` read at the view's layer (2 modified lines) |
| `GLSLSnippets/.../MSAAOps.glsl`, `MSAAOpsInternal.glsl`, `GLSLCommon.cpp`, `GLSLTypes.h` | 3 / 19 / 19 | | 8 / 8 | MSAA helpers on array samplers |
| `GLSLSnippets/RSXProg/RSXFragmentTextureDepthConversion.glsl` | 0 / 5 / 7 | 3 (1) | 4 / 0 | Depth-as-colour read at the view's layer: now an override at the end of the file |
| `gcm_enums.h` | 0 / 1 / 0 | 13 (7) | 7 / 0 | `RSX_SHADER_CONTROL_VR_MULTIVIEW`, now in the fork's `rsx_vr_hooks.h` |
| `VK/VKGSRenderTypes.hpp` | 0 / 1 / 0 | 4 (2) | 0 / 0 | `occlusion_data::stereo_pairs`, now not needed |
| `VK/VKPipelineCompiler.cpp` | 0 / 6 / 1 | 4 (3) | 0 / 0 | One fork line raises the viewport count for two-view passes |
| 11 more files (`VKRenderPass.h`, `vkutils/device.h`, `VKOverlays.cpp/.h`, `VKQueryPool.h`, `VKHelpers.h`, `barriers.cpp`, `VKVertexProgram.h`, build lists) | | | 4 / 4 | 1 to 6 lines each |

## 3. Hazards specific to multiview, ranked

1. **The texture cache.** `VKTextureCache.cpp` has the most exposure and the least room to shrink.
   Multiview edits five upstream functions inline: the per-layer split of `copy_transfer_regions_impl`,
   the layer count in `find_cached_image` and `create_temporary_subresource_view_impl`, and the layer
   ranges and layer-1 background in `generate_atlas_from_images` and `generate_2d_mipmaps_from_images`.
   Upstream reworked these paths in August 2026 (multi-layer and explicit mip/layer transfers).
   That rework is also what multiview builds on (`rsx::image_copy_subresource_layers`), which helps. Expect
   conflicts here on most merges. Each is a one- or two-line resolution, but each needs reading.
2. **Upstream layouts and bit budgets the fork extends.** These merge cleanly and break silently if
   upstream claims the same bits:
   - `renderpass_key_blob`, bits 42-43 (`view_mask`);
   - `framebuffer_storage_key` (`view_mask`, `base_layer`, `layer_count`, 8 bits after `ia_ref`);
   - the `viewable_image::views` cache key, bits 48 and up (`layer + 1`);
   - `query_slot_info::pair_head`;
   - the program control bit `0x4000`;
   - interpreter compiler option bit 32.

   The last two are now guarded by `static_assert`s; the others are on the checklist in section 6.
3. **Upstream text the fork copies or patches.** Two cases:
   - The interpreter variants patch upstream's interpreter GLSL by string replacement. The fragment
     patch had a runtime `ensure`. The vertex patch failed silently: both eyes would clip to the left
     eye's scissor.
   - The multiview texture macros are copies of upstream's `TEX2D*`, `TEX2D_SHADOW*` and
     `TEX2D_Z24X8_RGBA8` with a layer coordinate added. If upstream changes one, the VR copy goes stale.

   All of these are now checked at compile time (section 4).
4. **In-place edits of hot upstream GLSL.** The ROP epilogue (2 modified lines, 12 upstream commits a
   year, 10 of them in the last 6 months) and the MSAA sampling helpers (2 lines). These are function
   bodies, so the override approach used for the macros does not apply. They will conflict when upstream
   edits those statements. The resolution is to re-apply `_ROP_DEPTH_COORD` / `_MS_TEXEL_FETCH`.
5. **Edits that change upstream code paths for every run, VR or not.** All are no-ops for one-layer
   images, which is every image while multiview is off, but a reviewer has to know they are there:
   - `insert_texture_barrier` covers all layers;
   - `find_cached_image` matches on layer count;
   - `viewable_image::get_view` returns layer 0 of a stereo image;
   - `query_pool_manager::free_query` frees a pair's second slot.
6. **Build glue.** `BUILD_RPCS3_GUI` modifies three `if (NOT ANDROID)` lines in `rpcs3/CMakeLists.txt`
   (16 upstream commits a year). It is a convenience for Linux compile checks. Drop it if it starts
   conflicting.

## 4. What was changed (`55d63cc4`), and how it was checked

| Change | Upstream files affected | Effect |
|---|---|---|
| New fork-only `VK/VKMultiviewVR.h/.cpp` holding the moved code: `image_view::as_array()`, `query_pool_manager::allocate_query_pair/begin_query_pair`, the render pass `VkRenderPassMultiviewCreateInfo`, the texture cache's layer helpers, `g_vr_stereo_layers`, and all multiview GLSL text the generators and interpreter emit | `vkutils/image.cpp`, `VKQueryPool.cpp`, `VKRenderPass.cpp`, `VKTextureCache.cpp`, `VKRenderTargets.cpp`, `VKShaderInterpreter.cpp`, `VKFragmentProgram.cpp`, `VKVertexProgram.cpp` | ~200 lines out of upstream files; each site is one call |
| `RSX_SHADER_CONTROL_VR_MULTIVIEW` moved from `gcm_enums.h` to `rsx_vr_hooks.h`, with a `static_assert` against upstream's bits | `gcm_enums.h` untouched | removes a 7-exposure insertion |
| `rsx::vr::set_multiview_ctrl(ctrl)`: one call per program in `RSXThread.cpp` | `RSXThread.cpp` | upstream's `ctrl &= ~FLAT_SHADING` line restored |
| The pair's average is taken in `query_pool_manager::get_query_result` (from `pair_head`), not by a fork wrapper with an `occlusion_data::stereo_pairs` list | `VKGSRender.cpp` (3 lines back to upstream), `VKGSRenderTypes.hpp` untouched, `VKQueryPool.cpp` (+2) | the logic sits in a file upstream touched once in the year rather than 46 times |
| `RSXFragmentTextureOps.glsl`, `RSXFragmentTextureDepthConversion.glsl`: the multiview macros are `#undef`/`#define` overrides after upstream's, not `#if/#elif` around them | both | no upstream line modified or moved; the block sits where upstream did not edit all year |
| Pipelines keep upstream's `viewportCount = 1; scissorCount = 1;` and one fork line raises both | `VKPipelineCompiler.cpp`, `VKShaderInterpreter.cpp` | 2 modified upstream lines become 1 inserted line each |
| Merge guards: `static_assert`s in `VKMultiviewVR.cpp` on the exact upstream text that the VR macro copies and interpreter patches depend on; on the interpreter option width; on the control bit | none | a merge that changes them stops the build and names the VR copy to update |
| `vr_null_view_type` calls upstream's `vk::get_view_type` instead of a copy of it | none (fork file) | one duplicated upstream function gone |
| `multiview_active()` and `effective_vblank_rate()` declared once (`rsx_vr_hooks.h`) | none (fork headers) | two `-Wredundant-decls` warnings gone |

`f6e8731f` separately fixes a GCC `-Werror=sign-compare` error in `rsx_vr_profile_generator.cpp`, a
fork file. The error is on `openxr` too, and it stopped Linux core builds of that file.

**Behaviour.** Every move is verbatim, and every hook does what the inline code did, at the same point
in the same function. Places that are not literally identical, each checked:

- **Generated shader text.** Blank lines moved. `#define _VR_MULTIVIEW` and the interpreter's
  `GL_EXT_multiview` line sit after a blank line. The vertex shader defines `get_draw_params()` as
  upstream does, then `#undef`s and redefines it for two views. After preprocessing, the shaders are the
  same.
- **The query average.** "`id` is in `stereo_pairs`" holds exactly when the slot's `pair_head` is set.
  Both are set together in `vr_mv_begin_query_segment` and cleared together when the query is freed.
  The formula and the order of the two reads are unchanged, and `get_query_result` has no other caller.
- **`set_multiview_ctrl`.** Sets or clears the same bit at the same point as the inline code.
- **One new log line** (`rsx_log.error`) in a path that cannot run today: when the vertex interpreter
  patch finds nothing to replace, it now says so instead of failing silently.

**Checks run in this container (Ubuntu 24.04, no GPU):**

- **Compile.** All 158 translation units of `rpcs3/Emu/RSX` plus everything that includes the changed
  fork headers compile with GCC 13. The flags are `-std=gnu++23` and the warning flags of
  `buildfiles/cmake/ConfigureCompiler.cmake`, including its `-Werror`s; third-party headers come from
  Ubuntu packages ([tools/merge/compile_check.sh](tools/merge/compile_check.sh)). There are no new
  warnings, and two old ones are gone.
- **Symbols.** `nm` across the 158 objects shows no symbol that lost its definition and none defined
  twice. This is the link-level check for the moves.
- **GLSL.** The old and new snippets were run through the C preprocessor under every combination of
  the 10 defines they test (1,024 combinations). With every macro expanded, the two give the same
  output ([tools/merge/glsl_equiv.py](tools/merge/glsl_equiv.py)).
- **Guards.** Changing one guarded macro's text makes the build fail as intended.

**Not done:**

- No run. On the PC, before merging into `openxr`, run the multiview A/B pass of
  [9-multiview-plan.md](9-multiview-plan.md) section 10 (`RPCS3_VR_MULTIVIEW=0` vs `1`, the simulator
  regression).
- No MSVC build. The new files are in `VKGSRender.vcxproj`, `.filters` and `Emu/CMakeLists.txt`, with
  CRLF and BOM kept.
- No trial merge with RPCS3's current `master`. The fork's `master` stops at RPCS3's 2026-09-19, and
  RPCS3/rpcs3 cannot be attached to a session beside the fork (both check out as `rpcs3`). Two ways to
  get it: sync the fork (GitHub, `master`, "Sync fork"), after which a session can fetch RPCS3's newer
  commits from hookmanuk/rpcs3; or, on the PC with the `upstream` remote of [1-structure.md](1-structure.md):

  ```
  git merge --no-commit upstream/master
  git diff --name-only --diff-filter=U
  git merge --abort
  ```

  Run it on `multiview` and on this branch to see the difference in conflicting files.

## 5. What remains, and what it would take to shrink it

The remaining ~480 lines are mostly single-line edits that only make sense in place:

- a layer count instead of `1` (render targets, resolve targets, barriers, clears, subresource ranges);
- a layer parameter on upstream functions (`resolve_image`, `unresolve_image`, the 8 resolve passes,
  `get_framebuffer`, `get_renderpass_key`, `find_cached_image`, `create_temporary_subresource_view_impl`);
- the per-layer splits of `blitter::scale_image` and `copy_transfer_regions_impl` (wrapper plus renamed
  body, so upstream's body stays in place);
- the device feature plumbing;
- the ROP and MSAA GLSL lines.

Options beyond mechanical moves. Each one changes code paths, so it needs a test pass on the PC:

1. **View mask from the images.** `get_renderpass_key` could set the multiview bits itself when every
   image has `stereo_layers` (as 9-multiview-plan.md 3.2 first proposed). The explicit `view_mask`
   argument at the call sites and `vr_image_view_mask`/`vr_draw_view_mask` would go. The per-eye clears
   (view masks 2 and 3) would still pass one explicitly.
2. **Array views where views are made, not where they are bound.** If `viewable_image::get_view` and
   `vk::null_image_view` returned 2D-array views for 2D images while multiview is on, most of the ten view
   wraps in `bind_texture_env` and `bind_interpreter_texture_env` (`VKDraw.cpp`, 35 upstream commits a
   year) would go.
3. **Layered resolves** (plan M4). One compute dispatch over `image2DArray` would replace the per-layer
   loop. The `layer` parameter on eight resolve functions would become a layer count read from the image.
4. **`device.cpp` in one call.** The multiview feature query needs its struct to outlive
   `vkGetPhysicalDeviceFeatures2`. A fork-side holder object would turn three insertions into two calls.
   This is a small gain; upstream's own features are added the same way.
5. **The 100% resolution scale fix** (section 7) would move one hook line, not add one.

None of this is a good upstream pull request: upstream has no user of two-layer render targets.

## 6. Post-merge checklist additions

Add to [8-upstream-merge-audit.md](8-upstream-merge-audit.md) section 5 for merges into a branch that
carries multiview:

1. **Build first.** The `static_assert`s in `VKMultiviewVR.cpp` and `rsx_vr_hooks.cpp` fire on the
   upstream changes the VR code depends on by text or by bit. If one fires, update the VR copy (the
   override blocks at the end of `RSXFragmentTextureOps.glsl` / `RSXFragmentTextureDepthConversion.glsl`,
   or the patch in `vr_insert_interpreter_*`), then the guarded text.
2. **New control bits.** For any new `RSX_SHADER_CONTROL_*` bit in `gcm_enums.h`, add it to the
   `static_assert` list in `rsx_vr_hooks.cpp`. It must not be `0x4000`.
3. **Key layouts.** `renderpass_key_blob` still ends below bit 42 (multiview's `view_mask` is 42-43).
   `framebuffer_storage_key` still fits 64 bits. `viewable_image::get_layer_view`'s cache key still has
   bits 48 and up free.
4. **Hot spots to read after a merge.** Upstream changes to `copy_transfer_regions_impl`,
   `find_cached_image`, `create_temporary_subresource_view_impl` and the atlas and mip-chain builders
   (`VKTextureCache.cpp`); `blitter::scale_image` (`VKTexture.cpp`); `render_target::resolve`/`unresolve`;
   the ROP epilogue's depth read. A clean merge there can still miss layer 1.
5. **Recompute exposure.** Run `tools/merge/hunk_exposure.sh` on the new base to see where the fork
   now sits in upstream's busy code.
6. **Test.** Multiview A/B (`RPCS3_VR_MULTIVIEW=0` vs `1`) on one savestate per hazard class: an atlas
   title (Kingdom Hearts II), a memory-bounce title (ICO), an MSAA title, and a title that uses occlusion
   queries (WipEout).

## 7. Other findings (not changed here)

1. **Likely bug: stale right eye after a memory reload at 100% resolution scale.**
   `vk::render_target::load_memory` (`VKRenderTargets.cpp`) copies layer 0 into layer 1 only in its
   scaled/MSAA branch. The `[[likely]]` branch (scale 100%, one sample) uploads into layer 0 alone, so a
   surface the CPU or SPU wrote keeps an old right eye. The regression runs use 300%, which takes the
   other branch. Fix: call `vk::vr_copy_left_to_right_layer(cmd, this)` after the upload in that branch
   too (one line). Left as is because it changes behaviour; worth one test at 100% (an SPU-written
   screen, inFamous 2).
2. **Line-ending dependence.** Upstream's GLSL files are stored with CRLF line endings. The vertex
   interpreter patch matches `"\tgl_Position = pos;\n"`, which works because the compiler turns CRLF
   into `\n` inside raw strings: GCC does, checked here, and MSVC does too as far as known. If it ever
   does not match, the new log line says so.
3. **GCC build.** Fixed in `f6e8731f` (section 4).
