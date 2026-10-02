# Upstream merge audit: what the `openxr` branch changes in master's files

Audited 2026-10-02 against `openxr` at `90640f9` and `master` at `9e86f165` (upstream of
2026-09-19). `master` is the merge base: `openxr` is 146 commits ahead and 0 behind, so this
is the complete fork delta. Upstream churn figures are commits on `master` touching the file in
the 12 months to 2026-09-19 (6 months in brackets). Upstream lands 100 to 220 commits a month.

The question this answers: how much of the fork lives inside files that upstream also edits,
which of that is structurally likely to conflict, and what can be moved, deleted or reshaped so
that `git merge master` into `openxr` is routine.

## 1. The delta in numbers

| | Files | Lines |
|---|---:|---:|
| Whole diff `master..openxr` | 142 | +32,027 / -153 |
| New files, all | 74 | +26,446 |
| of which 3rdparty OpenXR headers | 3 | 15,844 |
| of which fork source (`.cpp`, `.h`, `.glsl`) | 9 | 7,587 |
| of which data and docs (profiles, patches, md, png) | 62 | ~3,000 |
| **Upstream files modified** | **68** | **5,734 changed (+5,581 / -153)** |

New files never conflict. The merge cost is entirely in the 68 modified upstream files, and
within those it is concentrated:

| Category | Files | Changed lines | Share |
|---|---:|---:|---:|
| R: Vulkan renderer and RSX integration | 23 | 4,216 | 74% |
| U: settings and UI plumbing (Qt, home menu, config) | 18 | 768 | 13% |
| D: development and diagnostic hooks only | 6 | 598 | 10% |
| P: fork policy, build and packaging | 12 | 104 | 2% |
| S: shader pipeline | 9 | 48 | 1% |

Four files carry 63% of it: `VKDraw.cpp` (1,397), `VKGSRender.cpp` (1,306), `VKPresent.cpp`
(685) and `settings_dialog.ui` (372). The first three are the files upstream's graphics work
goes through (35, 46 and 19 upstream commits in the last year).

Cutting the 5,734 lines another way, by what kind of change they are (estimates from reading
every hunk; the groups overlap by about 230 lines where profiler functions are both "new whole
functions" and "diagnostic"):

| Kind | Lines (approx.) | What it means for merging |
|---|---:|---|
| New whole functions placed inside upstream files | ~1,750 | Movable to fork-only files with no behaviour change |
| Development and diagnostic hooks (env-var gated) | ~1,300 | Deletable, or movable behind one call per site |
| Inline edits to upstream functions | ~2,900 | The real integration; shrinkable to hook calls |
| Of the inline edits: two reorderings of upstream code | ~150 | Highest conflict risk per line, see section 2 |

## 2. Structural hazards, ranked

These are the things that will produce conflicts or silent breakage out of proportion to
their line count.

1. **`VKPresent.cpp`, `flip()`: an upstream block was moved.** The ~70-line swapchain
   acquisition loop (the `acquire_next_swapchain_image` `while`, the aspect-ratio
   calculation and the `target_image` setup) now sits *after* the screenshot and recording
   capture, where upstream has it *before*. Git sees a deletion and an unrelated insertion. Any
   upstream edit inside that loop (they edited it twice in early 2026, for a CPU frame
   misalignment bug and the NVIDIA resize crash) conflicts, and the resolution has
   to be hand-ported into the moved copy. The fork comment says the move avoids a driver crash
   when screenshots are taken with the desktop locked, which is a scripted-run convenience.
2. **`VKDraw.cpp`, `emit_geometry()`: upstream's draw dispatch was re-indented.** The ~75
   lines of `vkCmdDraw` / `vkCmdDrawIndexed` / multidraw dispatch are wrapped in the lambda
   `emit_vulkan_draw` and indented one level; the inner `else` branch was also rewritten
   (the `subranges` local removed). Every upstream edit to the dispatch conflicts on
   whitespace; upstream edited `emit_geometry` five times in the year, most recently for
   sub-pass dependency barriers (Sep 2026) and the draw-time constants rework (Oct 2025). Around the lambda,
   another ~460 lines of VR logic are inline in the same function, so the function is now
   ~750 lines of which ~200 are upstream.
3. **`VKGSRender.h`: ~220 fork lines inside the class body.** Members, two nested structs,
   ~45 GPU-profiler fields and ~40 method declarations are interleaved with upstream's
   members. Upstream touched this header 16 times in the year. Each fork insertion point is a
   conflict site.
4. **Duplicated upstream logic that must stay in step.** `vr_hud_vertex_env()` in
   `VKDraw.cpp` re-implements the vertex-environment fill from `load_program_env()`
   (hard-coded offsets 64, 68, 72, 76, 80, 84 and the 96-byte size), and
   `bind_vr_eye_constants()` re-implements `upload_transform_constants()`. If upstream changes
   either layout the merge is clean and the VR copy is silently wrong.
5. **Shared binary layouts extended by the fork.** `RSXDefines2.glsl` turns
   `reserved[3]` into `vr_keep_depth` plus two reserved floats, and `color_utils.hpp` appends
   `VR_REPROJECT_BIT` to `texture_control_bits`. If upstream claims a reserved slot or adds a
   control bit, the textual merge may succeed and the GPU-side layout break. The
   `std::memset(buf + 84, 0, 12)` in `load_program_env()` is the only guard.
6. **Mid-list insertions in settings tables.** `emu_settings_type.h/.cpp`,
   `localized_string_id.h`, `localized_emu.h`, `emu_settings.cpp`, `tooltips.h` and
   `system_config_types.h` insert VR entries in the middle of enums, maps and switches,
   next to the stereo/anaglyph entries upstream added in May 2026 and may extend again.
7. **`rpcs3_version.cpp`: the fork edits upstream's version line.** The
   `static constexpr utils::version version{ 0, 0, 42, ... }` line now carries
   `RPCS3_VR_VERSION`, so every upstream version bump conflicts, and every fork release bump
   (vr5, vr6, ...) is a commit on an upstream file.
8. **Coupling to upstream internals without an interface.** The fork reaches into
   `sampled_image_descriptor` (`upload_context`, `image_handle`, `external_subresource_desc`,
   `ref_address`, `is_cyclic_reference`), `surface_cache` (`m_bound_render_targets`,
   `m_bound_depth_stencil`, `superseded_surfaces`, `orphaned_surfaces`,
   `m_render_targets_storage`), `deferred_request_command` values, the occlusion query
   manager, and `command_buffer_chunk` fields (`vr_secondary_cb` pokes `pool`, `commands`,
   `is_open`, `is_pending`, `flags`, `reset_id`). Upstream refactored
   `deferred_subresource` in Aug 2026 and the surface cache blit storage the same month. These
   are compile-time breaks, not merge conflicts, but they are the slow part of a merge.
9. **`emucore.vcxproj` line endings.** CRLF file; a tool that rewrites it to LF turns a
   3-line change into a 2,300-line diff (this already happened once, see 4-next-steps.md).

## 3. What to minimise, in order of payoff for effort

### A. Move whole functions out of upstream files (no behaviour change, ~1,750 lines)

Member function bodies can live in any translation unit. Create fork-only files, for example
`rpcs3/Emu/RSX/VK/VKGSRenderVR.cpp` (eye constants, batching, blit mirror, right-eye texture
selection, pose stamping, HUD env), `VKPresentVR.cpp` (`vr_update_view`,
`vr_track_frame_boundary`) and `VKGSRenderDev.cpp` (GPU profiler, rtdump, trace), and move
these there verbatim:

| From | Functions | Lines |
|---|---|---:|
| `VKDraw.cpp` end of file | `vr_sampled_pose`, `vr_stamp_targets`, `vr_is_feedback_texture`, `vr_shift_feedback_textures`, `vr_trace_copy_reads`, `vr_realign_blend_targets`, `vr_is_passthrough_hud`, `vr_hud_draw_scale`, `vr_unboxed_draw`, `vr_sampled_textures`, `vr_preprojected_program`, `vr_hud_vertex_env` | 619 |
| `VKGSRender.cpp` after `clear_surface` | `vr_on_end_renderpass`, `vr_batch_begin`, `vr_batch_flush`, `vr_batch_execute` | ~125 |
| `VKGSRender.cpp` after `upload_transform_constants` | `find_fragment_constant_overrides`, `scale_offset_constants`, `vr_apply_box_scissor`, `bind_vr_eye_constants` | ~210 |
| `VKGSRender.cpp` before `scaled_image_from_memory` | `vr_mirror_blit` | ~265 |
| `VKGSRender.cpp` end of file | `vr_reprojects_older_frames`, `vr_redirect_previous_frame_copy`, `gpuprof_enabled`, `gpuprof_mark`, `gpuprof_flip` | 212 |
| `VKPresent.cpp` end of file | `vr_update_view`, `vr_track_frame_boundary`, `vr_trace_flush_cam`, `vr_rtdump` | 246 |
| `VKOverlays.cpp/.h` | `vr_homography_warp_pass`, `ui_overlay_renderer_xr` | ~105 |

Add the new `.cpp` files to `VKGSRender.vcxproj`, its `.filters`, and `Emu/CMakeLists.txt`
(these three already carry fork lines, so no new file joins the modified set).

For the header: put all VR declarations and members in one fork-only file and include it once
inside the class body:

```cpp
class VKGSRender : public GSRender, public ::rsx::reports::ZCULL_control
{
    ...
    #include "VKGSRenderVR.inl"   // VR fork: all VR members and declarations
```

`VKGSRender.h` then changes by about 6 lines (the include, `m_vr_right_rtts`, the
`bind_texture_env(bool)` default parameter, and the forward declaration of
`rsx::vr::fragment_constant_override`) instead of 224. The same trick suits `PPUThread.cpp`
(section B): its dev hooks need the file-static `ppu_read` and `ppu_cache`, which a textually
included `.inl` sees.

### B. Decide the fate of each development hook (~1,300 lines)

Every hook below is gated by an environment variable or a probe-file key and does nothing in
a normal run. Each is either finished with (delete) or still used by the playbook (keep, but
move). Where kept, the pattern is one call at the upstream site and the body in a fork file
such as `rpcs3/Emu/RSX/Capture/rsx_vr_dev_hooks.cpp`.

| Hook | File(s) | Lines | Suggested |
|---|---|---:|---|
| `RPCS3_PPU_TRACE`, `RPCS3_PPU_WATCH`, `RPCS3_PPU_RWATCH`, `RPCS3_PPU_WATCH_FILE` | `PPUThread.cpp`, `sys_timer.cpp`, `RSXThread.cpp` | 272 + ~95 + ~30 | Interpreter-only, used to find frame-rate patch sites. Move the `PPUThread.cpp` part to `PPUDevHooks.inl` (textual include, see A); the `sys_timer.cpp` part to a `rsx::vr::dev::on_usleep(ppu, sleep_time)` call. Delete once the games that needed them are patched. |
| `RPCS3_PPU_SAMPLE`, `RPCS3_USLEEP_STATS`, `RPCS3_CALLSTACK_AT`, `RPCS3_STATS_PERIOD_MS` | `sys_timer.cpp` | ~80 | Same `on_usleep` call. |
| `RPCS3_SYSCALL_PROFILE` | `lv2.cpp` | 43 | Marked `TEMP` in the source. Delete. |
| `RPCS3_VR_MEMDUMP`, `RPCS3_VR_PEEK`, `RPCS3_VR_POKE`, `RPCS3_VR_SHOT`, `RPCS3_VR_FRAMESTATS` | `RSXThread.cpp` | ~175 | One call `rsx::vr::dev::on_frame_end(*this, buffer)` in `on_frame_end`, one in `flip`. `FRAMESTATS` is still used by vr-games.md measurements; the rest are investigation tools. |
| `RPCS3_VR_KEYS` | `keyboard_pad_handler.cpp/.h` | 102 | `Key()` is protected, so the member must stay declared (3 lines in the header); move the body to a fork `.cpp`. The call in `process()` is 1 line. |
| `RPCS3_DUMP_ELF` | `System.cpp` | 8 | Keep or delete; 8 lines in a 66-commits-a-year file. |
| `RPCS3_VR_GPUPROF`, `RPCS3_VR_GPUPROF_TARGET` | `VKGSRender.cpp/.h`, `VKPresent.cpp`, `VKDraw.cpp` | ~290 | The profiler functions move with A. The ~45 fields leave the header with the `.inl`. The inline timers (`readback_timer`, `flip_timer`, `m_gpuprof_*_ms +=` in `flush_command_queue`, `frame_context_cleanup`, `emit_geometry`, `bind_vr_eye_constants`) are ~60 lines across 8 sites and are the part worth deleting: each is a conflict site in a hot function. |
| `RPCS3_VR_RTDUMP` | `VKPresent.cpp`, `VKDraw.cpp`, `VKGSRender.h` | ~130 | Request parsing (~45 lines inline in `flip`) to a helper `vr_rtdump_poll(info)`; `vr_rtdump` moves with A. |
| `vr_tracing()` trace (`m_vr_trace`, `vr_trace_*`, `TEMPORARY diagnostic`) | `VKDraw.cpp`, `VKGSRender.cpp`, `VKPresent.cpp`, `VKGSRender.h` | ~120 | Labelled temporary in the header. Delete, or keep only `vr_trace_copy_reads` if Ico work continues. |
| Probe dev keys `why=`, `hide=`, `unboxfp=`, `gamecam=`, `dev=` bits 0x100/0x200 | `VKDraw.cpp`, `VKGSRender.cpp` (`decode_rsx_state`) | ~70 | The two `dev_flags()` tests in `decode_rsx_state` edit upstream's depth/stencil setup for a development toggle; delete those two. The others fold into the hook functions of section C. |
| `RPCS3_VR_BATCH`, `RPCS3_VR_NO_RSX_EARLY`, `RPCS3_VR_FEEDBACK_FLIP_V`, `RPCS3_VR_WOBBLE`, `RPCS3_VR_HEAD_OFFSET` | `VKGSRender.cpp`, `VKDraw.cpp`, `VKPresent.cpp` | ~45 | A/B switches from past investigations. Delete the ones whose answer is known (batching on, early readback on). |
| Stereo inspector capture, profile generator sampling | `VKDraw.cpp`, `VKGSRender.cpp`, `nv0039.cpp` | ~70 | Shipping features (the home-menu profile generator) so they stay, but as one call each: `vr_capture_draw(sub_index, upload_info)`. |

### C. Collapse the inline integration into named hooks (~2,900 lines, target ~900)

This is the step that changes the shape of the merge. Each upstream function keeps its
upstream text plus a handful of one-line calls; the bodies live in `VKGSRenderVR.cpp`. VR
per-draw state that today is ~20 locals in `emit_geometry` becomes one struct member
(`vr_draw_state m_vr_draw`).

| Upstream function | Fork lines inline today | Replace with |
|---|---:|---|
| `VKGSRender::emit_geometry` | ~535 | `vr_begin_draw(sub_index, upload_info)` (classification, probe `set_draw_*`, eye constants, HUD env, batching decision, query suspension), `vr_before_draw()` (box scissor, clear-shown), `vr_after_left_draw(sub_index, upload_info, emit)` (the whole right-eye replay or batch, taking the draw emitter as a callable), `vr_end_draw()` (restore env). Four calls. |
| `VKGSRender::bind_texture_env` | ~175 | `vr_right_eye_view(i, sampler_state, view)` for the fragment loop, `vr_right_eye_vertex_view(i, sampler_state, image_ptr)` for the vertex loop, and the depth-stencil ternary. Three short calls. |
| `VKGSRender::end` | ~80 | `vr_skip_draw()` (hidden_draws, `hide=`, rtdump trigger) returning bool, `vr_before_draw_setup()` (realign blend targets, inspector `begin_draw_clause`). |
| `VKGSRender::load_texture_env` | ~25 | `vr_redirect_texture(i, tex, saved)` / restore pair. |
| `VKGSRender::clear_surface` | ~125 | `vr_map_clear_rect(...)` before the region is built, `vr_mirror_clear(...)` after the clear. |
| `VKGSRender::prepare_rtts` | ~200 | `vr_before_prepare_rtts()` (early readback) and `vr_prepare_right_rtts()` after `m_rtts.prepare_render_target`. |
| `VKGSRender::load_program_env` | ~30 | Already small; keep the three `vr_` locals but move the override loop into `vr_apply_fragment_constant_overrides(buf, size)`. |
| `VKGSRender::on_access_violation` | ~45 | `vr_note_readback(result)`; delete the profiler timer. |
| `VKGSRender::scaled_image_from_memory` | ~45 | `vr_before_blit(src)` and `vr_after_blit(src, dst, interpolate)`. |
| `VKGSRender::VKGSRender` / `~VKGSRender` | ~70 | `vr_init_before_instance()`, `vr_select_adapter(gpus, adapter_name)`, `vr_init_after_device()`, `vr_destroy_before_wait()`, `vr_destroy_resources()`. The teardown ordering matters (XR session before `vkDeviceWaitIdle`), so the calls stay where they are but the bodies move. |
| `VKGSRender::flip` | ~330 | `vr_rtdump_poll(info)`, `vr_right_eye_present_image(present_info, buffer_w, buffer_h)`, `vr_publish_frame(info, image_to_flip, image_to_flip2, ...)` (the entire OpenXR publish/overlay/commit/pose-update block, ~120 lines), `vr_crop_for_side_by_side(calibration_src, ...)`. The side-by-side screenshot edits (~40 lines) touch upstream's capture code at 6 points and are the hardest to factor; consider dropping side-by-side screenshots from the desktop capture path and taking them from the VR eye images instead. |
| `rsx::thread` (`RSXThread.cpp`) | ~45 real | Keep: the four `effective_vblank_rate()` substitutions are the minimum, `reload_profile()`, `poll()`, `update_game_refresh_rate()`, `on_frame_end()` are one line each. |

After A, B and C the four hot files would carry roughly: `VKDraw.cpp` ~120 lines of calls and
small conditionals (from 1,397), `VKGSRender.cpp` ~150 (from 1,306), `VKPresent.cpp` ~90
(from 685) if the block move is also undone, `VKGSRender.h` ~6 (from 224). The VR code itself
does not shrink; it moves into files upstream never touches.

### D. Undo the two reorderings (section 2, items 1 and 2)

- `flip()`: restore upstream's order (acquire, then capture). If the locked-desktop
  screenshot case still matters for scripted runs, the better fix is to make the VR eye
  publish path write the screenshot from the published eye images (it already copies them)
  and leave upstream's desktop capture alone. Alternatively upstream the reorder with the
  NVIDIA crash as justification; until it lands, it is the single most conflict-prone hunk in
  the fork.
- `emit_geometry()`: either restore the upstream text and indentation inside the lambda
  (then `git merge -Xignore-space-change` resolves upstream edits automatically), or extract
  upstream's dispatch into a member `emit_draw_commands(upload_info, draw_call)` so the only
  edit at the site is one call and the fork's replay calls the same member. The second is
  cleaner and is a 1-line conflict at most.

### E. Settings and UI (768 lines, target ~250)

- `settings_dialog.ui` (372 lines, 39 upstream commits a year) and `settings_dialog.cpp`
  (138): move the VR group box into its own `vr_settings_widget.ui` with a small
  `vr_settings_widget` class owning the slider wiring and frame-rate combo filtering. The
  dialog then has a promoted-widget placeholder in the `.ui` (~12 lines) and one construction
  call in the `.cpp` (~5 lines). The new files never conflict.
- Enum, map and switch additions (`emu_settings_type.h/.cpp`, `localized_string_id.h`,
  `localized_emu.h`, `emu_settings.cpp`, `tooltips.h`, `system_config_types.h/.cpp`,
  `system_config.h`): these ~230 lines are inherent in how RPCS3 settings are declared and
  cannot be moved. Place them at the end of each list rather than next to the stereo entries,
  and keep each block contiguous. A conflict there is then "both sides appended" and takes
  seconds.
- Home menu (`overlay_home_menu_*`, ~115 lines): the VR page is already its own class. The
  `home_menu_dropdown` filter/relabel extension (42 lines) is generic and a reasonable
  upstream pull request; it is the only non-additive edit in that group.

### F. Policy and build items (104 lines)

- **Auto-updater** (`main_window.cpp` 37 lines, `main_window.ui` 2): upstream defines
  `RPCS3_UPDATE_SUPPORTED` at `main_window.cpp:102` and already guards all three sites with
  it. Replace the three commented-out blocks with one `#undef RPCS3_UPDATE_SUPPORTED` (or a
  fork compile definition that suppresses the `#define`) right after upstream's define. The
  menu item then shows upstream's own "not available for your OS" message, or stays hidden
  via the 2-line `.ui` comment. 37 lines in the most-edited file in the tree (74 commits a
  year) become 3.
- **Version** (`rpcs3_version.cpp` 13 lines): move `#define RPCS3_VR_VERSION "vr6"` into a
  fork-only header `rpcs3_vr_version.h`, so the per-release bump never touches an upstream
  file. The concatenation into the `utils::version` line still has to be there and will
  conflict once per upstream version bump (about yearly); that is acceptable.
- **Patch "Enabled By Default"** (`bin_patch.cpp/.h`, 25 lines, 3 upstream commits a year):
  low risk, keep. Worth proposing upstream; it is a general feature.
- `.gitignore`, `.ci/deploy-*.sh`, `vcxproj`, `CMakeLists.txt`: trivial and append-only, keep.

### G. Hot-file exposure in the texture cache

`Common/texture_cache.h` is 4,001 lines with 51 upstream commits a year, the busiest file the
fork touches. The 25-line `flush_listed_sections` template uses only protected members
(`m_storage`, `m_cache_mutex`) and can move to the derived `vk::texture_cache` in
`VKTextureCache.h` (10 commits a year). The 6-line `vr_record_flushes` hook inside `flush_all`
and the three public fields have to stay, unless `flush_all` grows a virtual
`on_section_transferred(section)` that the derived class overrides, which is a tidier 4-line
upstream-shaped change.

### H. Candidates to upstream (make the diff disappear permanently)

Realistic, because they are generic or fix real bugs:

- `VKTextureCache`: keeping `upload_image_simple` results alive until the next flip
  (`m_flip_uploads`). The fork hit a use-after-free when an extra submit happens between
  upload and present; upstream has the same hazard whenever anything submits in between.
- `command_pool::create(..., flags)` and `instance::handle()`: tiny API generalisations.
- `home_menu_dropdown` filter/relabel.
- The `flip()` "image cannot be captured this frame" guard (`capturable`) that skips a
  screenshot instead of crashing on a sub-sized or wrong-format present image.
- Patch key "Enabled By Default".

Unlikely to be accepted, keep as fork: the `end_renderpass` hook, `FPOpcodes` logging
instead of throwing, the global submit lock around present and `vkDeviceWaitIdle` (only
needed with a second submitting thread), the shader `vr_keep_depth` and `VR_REPROJECT_BIT`.

### I. Guard the silent-breakage points

Add to the fork, next to the duplicated code, so that a clean merge that breaks a layout
fails to compile or fails at startup rather than in the headset:

- `static_assert` on the vertex environment size and the offset of `vr_keep_depth` in both
  fill sites, or better, factor upstream's fill into a small helper the VR path calls (one
  5-line upstream edit replaces two 15-line duplicates).
- `static_assert(rsx::texture_control_bits::VR_REPROJECT_BIT < 32)` and a check that
  `GAMMA_CTRL_MASK` and the other masks still fit.
- A startup `ensure` that `sizeof(vertex_context_t)`-equivalent constants match between
  `RSXDefines2.glsl` and the C++ side (upstream has the GLSL layout as a string; a comment
  cross-reference is the minimum).

## 4. Expected result

| File | Fork lines today | After A to G (approx.) | Upstream commits / year |
|---|---:|---:|---:|
| `VKDraw.cpp` | 1,397 | ~120 | 35 |
| `VKGSRender.cpp` | 1,306 | ~150 | 46 |
| `VKPresent.cpp` | 685 | ~90 | 19 |
| `VKGSRender.h` | 224 | ~6 | 16 |
| `settings_dialog.ui` | 372 | ~12 | 39 |
| `settings_dialog.cpp` | 138 | ~5 | 42 |
| `RSXThread.cpp` | 226 | ~50 | 49 |
| `PPUThread.cpp` | 272 | 1 (or 0) | 38 |
| `sys_timer.cpp` | 173 | 1 (or 0) | 2 |
| `lv2.cpp` | 43 | 0 | 11 |
| `keyboard_pad_handler.cpp` | 91 | ~3 | 15 |
| `main_window.cpp` | 37 | 3 | 74 |
| `texture_cache.h` | 40 | ~12 | 51 |
| All 68 files | 5,734 | ~1,100 | |

About 80% of the fork's footprint in upstream files goes away without changing what the
emulator does. What remains is one-line hooks, settings declarations that have nowhere else to
go, and a handful of small deliberate behaviour changes.

## 5. Merge procedure, until and after the restructuring

- **Merge often.** The current base is 13 days old; at upstream's rate that is on the order
  of 50 to 100 commits. Upstream's recent work (programmable blending, flat shading, blit storage moved into the
  surface cache, `deferred_subresource` refactor) lands exactly in the fork's hot spots. A
  merge every two to four weeks keeps each one small; a quarterly merge of ~400 commits into
  the present layout would be a multi-day job.
- `git config rerere.enabled true` in the `rpcs3` checkout, so a conflict resolved once in a
  trial merge is replayed automatically.
- While the `emit_vulkan_draw` re-indent exists, merge with
  `git merge -Xignore-space-change master`.
- **Post-merge checklist**, because several couplings are not textual:
  1. Build with both the Visual Studio solution and CMake (the fork adds files to both).
  2. `emucore.vcxproj` is still CRLF (`git diff --stat` shows a 3-line change, not 2,000).
  3. `vertex_context_t` in `RSXDefines2.glsl` still has `vr_keep_depth` at offset 84 and
     both C++ fill sites write 96 bytes.
  4. `texture_control_bits` still has room for `VR_REPROJECT_BIT`; `GLSLCommon.cpp` still
     emits its name.
  5. `bind_texture_env` still compiles against `sampled_image_descriptor` and
     `deferred_request_command`; `vr_mirror_blit` against `surface_cache` and
     `blit_src_info`/`blit_dst_info`; `vr_secondary_cb` against `command_buffer_chunk`.
  6. The four `effective_vblank_rate()` substitutions in `RSXThread.cpp` are all still
     present (a conflict there is easy to resolve by taking upstream and losing one).
  7. The regression pass of 7-vr-regression.md on the headset titles.
- **Restart the fork version at vr1** after each upstream version bump, as 4-next-steps.md
  already says.

## 6. Implementation (2026-10-02)

Sections A to G and I were applied on branch `ccr-6db5810d-uriwc6` of `hookmanuk/rpcs3`, based on
`openxr` at `90640f9`. The branch has not been compiled: the build machine is Windows and this was
done in a container without Qt or the Vulkan SDK. Build it with the Visual Studio solution before
merging it into `openxr`, then run the 7-vr-regression.md pass (the restructuring moves code, it
does not change what the emulator does, but the hooks were re-plumbed by hand).

Every modified upstream file was rebuilt from upstream's text plus one-line hooks, so the merge
footprint is now:

| | Before | After |
|---|---:|---:|
| Upstream files modified | 68 | 71 (the three new ones are append-only build lists) |
| Fork lines in upstream files | 5,734 | 915 |
| `VKDraw.cpp` / `VKGSRender.cpp` / `VKPresent.cpp` / `VKGSRender.h` | 1,397 / 1,306 / 685 / 224 | 39 / 57 / 47 / 4 |
| `settings_dialog.ui` / `.cpp` | 372 / 138 | 9 / 5 |
| `PPUThread.cpp` / `sys_timer.cpp` / `lv2.cpp` / `RSXThread.cpp` / `keyboard_pad_handler.cpp` | 272 / 173 / 43 / 226 / 91 | 2 / 3 / 2 / 22 / 1 |

New fork-only files, where the moved code lives:

| File | Holds |
|---|---|
| `rpcs3/Emu/RSX/VK/VKGSRenderVR.inl` | every VR member and declaration of `VKGSRender`, included inside the class body by one line |
| `rpcs3/Emu/RSX/VK/VKGSRenderVR.h` | includes and the two dev-bit helpers for `decode_rsx_state` |
| `rpcs3/Emu/RSX/VK/VKGSRenderVR.cpp` | the moved VR functions (verbatim) and the hook bodies: `vr_begin_draw`, `vr_setup_draw`, `vr_begin_right_eye`, `vr_end_right_eye`, `vr_after_clear`, `vr_prepare_right_rtts`, `vr_publish_frame`, ... |
| `rpcs3/Emu/RSX/VK/VKGSRenderVRDev.cpp` | GPU profiler, `RPCS3_VR_RTDUMP`, the per-frame trace, the probe dev bits |
| `rpcs3/Emu/RSX/VK/VKOverlaysVR.h/.cpp` | `ui_overlay_renderer_xr`, `vr_homography_warp_pass` |
| `rpcs3/Emu/RSX/Capture/rsx_vr_hooks.h/.cpp` | the glue called from `RSXThread.cpp`, `sys_timer.cpp`, `lv2.cpp` and `System.cpp`, with the relocated dev hooks (`RPCS3_VR_MEMDUMP`, `PEEK`, `POKE`, `SHOT`, `FRAMESTATS`, `PPU_WATCH_FILE`, `PPU_SAMPLE`, `USLEEP_STATS`, `SYSCALL_PROFILE`, `DUMP_ELF`) |
| `rpcs3/Emu/Cell/PPUDevHooks.inl` | the trace and watch breakpoints, textually included by `PPUThread.cpp` |
| `rpcs3/Input/keyboard_pad_handler_vr.inl/.cpp` | `RPCS3_VR_KEYS` |
| `rpcs3/rpcs3qt/vr_settings_widget.ui/.h/.cpp` | the VR group box of the GPU tab, a promoted widget in `settings_dialog.ui` |
| `rpcs3/rpcs3_vr_version.h` | `RPCS3_VR_VERSION` (the per-release bump no longer touches an upstream file) |

Behaviour kept as it was, with these deliberate exceptions: `flip()` is back in upstream's order
(swapchain acquire before the screenshot capture), so a screenshot with a locked desktop is again
subject to the driver crash the fork had worked around; the GPU profiler's "flip" and "waiting for
older frames" timers now span the whole function and the whole cleanup rather than the exact
upstream statements; the vblank-rate notice, the frame-end dev hooks and the syscall profiler log
on the `VRDEV` channel instead of `RSX`, `sys_timer` and `PPU`. No dev hook was deleted: each is
referenced by the playbook or tools, so all were relocated.

**Coding style.** The fork's code follows the RPCS3 coding style (github.com/RPCS3/rpcs3/wiki/Coding-Style):
every fork-only source file is formatted with the repository's `.clang-format` (what the `pre-commit.readme`
hook runs), and on the fork's lines inside upstream files clang-format changes nothing. The OpenXR frame
thread and the sampling profiler are `named_thread`s. Three kinds of `#define` remain, each commented with why
it must be a macro: the `openxr.h` configuration macros, the entry-point loader macros (token pasting and
stringising) and `RPCS3_VR_VERSION` (string-literal concatenation with the generated git version). Before
committing fork code, run `git clang-format --style=file` so that only the changed lines are formatted.

Not done here: the upstream pull requests of section H, and the two `decode_rsx_state` dev bits,
which the report suggested deleting, were kept as one-line helpers because the probe `dev=` key is
still documented.

### Merged into `openxr` (2026-10-02, after vr7)

Merged locally as fork 62c3367ab (not pushed until the regression passes). `openxr` had 31 commits since `90640f9`
(the vr7 work); 8 files conflicted. The five upstream files (`VKDraw.cpp`, `VKGSRender.cpp/.h`, `VKPresent.cpp`,
`RSXThread.cpp`) were taken from the branch and those commits' changes were ported into the fork files instead:
`VKGSRenderVR.cpp/.inl` (3D-content tracking `vr_has_3d`, `screen_frame_draws`, `screen_frames_when`,
`frames_without_3d_as_screen`, cached vertex program hash, eye-constant copies), `VKGSRenderVRDev.cpp` (profiler,
RTDUMP poll) and `rsx_vr_hooks.cpp` (`RPCS3_RSX_SAMPLE`, dev trigger polling, `RPCS3_VR_SAVESTATE`, FRAMESTATS CPU
time). The `zcull_approximate` helper `rsx::reports::precise_zpass_count` moved from `RSXZCULL.cpp` into
`rsx_vr_hooks.cpp`: upstream keeps one declaration and three one-line call sites. Fork lines added to upstream files
by the merge: 6, all one-line hooks marked `// VR fork`.

Build fix: `rsx_vr_hooks.cpp` declared the PPU dev functions (`ppu_watch_install`, `ppu_rwatch_install`,
`ppu_register_function_at`, `ppu_trace_breakpoint`) with block-scope `extern` inside `rsx::vr`, which names
`rsx::vr::...`: six unresolved externals at link. They are declared at global scope now. With that the branch
compiles and links (per-project builds; it had never been compiled). Ported fork lines were formatted with VS's
clang-format 22.1.3 and the repository's `.clang-format`; it changed nothing outside them.

Regression after the merge (`evidence/vrtest/2026-10-02-1415`, all 29 states, against the latest pre-merge run of
each): every sustainable rate unchanged except Ridge Racer 7, 72 -> 90 Hz (its menu-video stall needed retries in
both runs). RSX thread ms/frame over 77 state/rate pairs: median +1.7%, quartiles 0% and +4.3%; the large swings
(Tales of Xillia, WipEout, Dynasty Warriors 6) move between rates within a run (scene variation).

## Appendix: every modified upstream file

Category: R renderer/RSX integration, U settings and UI, D development hooks, P policy and
build, S shader pipeline. "Fork lines" is insertions plus deletions in `master..openxr`.
"Up 12m (6m)" is upstream commits touching the file in the year (half-year) before the base.

| File | Cat. | Fork lines | Up 12m | Up 6m | What the fork does there |
|---|---|---:|---:|---:|---|
| `rpcs3/rpcs3qt/main_window.cpp` | P | 37 | 74 | 45 | auto-updater commented out at 3 sites; title uses get_version_and_branch |
| `rpcs3/Emu/System.cpp` | D | 8 | 66 | 41 | RPCS3_DUMP_ELF |
| `rpcs3/Emu/RSX/Common/texture_cache.h` | R | 40 | 51 | 48 | vr_record_flushes hook in flush_all + flush_listed_sections template (could live in the vk derived class) |
| `rpcs3/Emu/RSX/RSXThread.cpp` | R | 226 | 49 | 26 | ~45 lines of real hooks (vblank rate, probe poll, reload_profile); ~175 lines of dev hooks (MEMDUMP, PEEK, POKE, WATCH_FILE, SHOT, FRAMESTATS) inline in on_frame_end/flip |
| `rpcs3/Emu/system_config.h` | U | 20 | 46 | 27 | node_vr settings block inside node_video |
| `rpcs3/Emu/RSX/VK/VKGSRender.cpp` | R | 1306 | 46 | 22 | ~810 lines of new member functions inserted mid-file (batching, eye constants, blit mirror, GPU profiler); inline edits in ctor/dtor, clear_surface, prepare_rtts, load_program_env |
| `rpcs3/emucore.vcxproj` | P | 6 | 43 | 22 | 3 new source files (CRLF file: keep the line endings) |
| `rpcs3/rpcs3qt/settings_dialog.cpp` | U | 138 | 42 | 29 | VR group box wiring (sliders, frame-rate combo filtering) |
| `rpcs3/rpcs3qt/settings_dialog.ui` | U | 372 | 39 | 23 | VR group box with 6 sliders inserted into the GPU tab |
| `rpcs3/Emu/Cell/PPUThread.cpp` | D | 272 | 38 | 29 | trace/write-watch/read-watch breakpoints (RPCS3_PPU_TRACE, RPCS3_PPU_WATCH, RPCS3_PPU_RWATCH); interpreter only |
| `rpcs3/Emu/RSX/VK/VKDraw.cpp` | R | 1397 | 35 | 14 | emit_geometry +535 inline, bind_texture_env +150, 619 lines of new member functions appended at EOF; draw dispatch re-indented into a lambda |
| `rpcs3/Emu/CMakeLists.txt` | P | 1 | 35 | 16 | VKOpenXR.cpp |
| `rpcs3/rpcs3qt/emu_settings_type.h` | U | 10 | 32 | 19 | 10 VR enum entries inserted after ScreenSize (mid-enum) |
| `rpcs3/Emu/RSX/VK/VKFragmentProgram.cpp` | S | 3 | 31 | 10 | _VR_REPROJECT define |
| `rpcs3/rpcs3qt/tooltips.h` | U | 9 | 30 | 16 | 9 VR tooltips (mid-struct) |
| `rpcs3/Emu/RSX/VK/VKTextureCache.cpp` | R | 42 | 25 | 15 | m_flip_uploads lifetime fix (upstream candidate), blit_vr_right |
| `rpcs3/Emu/RSX/VK/VKShaderInterpreter.cpp` | S | 3 | 25 | 16 | VR_KEEP_DEPTH define |
| `rpcs3/Emu/RSX/Program/GLSLCommon.cpp` | S | 3 | 24 | 15 | VR_REPROJECT_BIT name |
| `rpcs3/rpcs3qt/main_window.ui` | P | 2 | 22 | 9 | updateAct commented out |
| `rpcs3/rpcs3qt/gs_frame.cpp` | U | 6 | 22 | 11 | side-by-side screenshot keeps full width |
| `rpcs3/rpcs3qt/emu_settings.cpp` | U | 16 | 21 | 10 | vr_frame_rate localisation (mid-switch insertion) |
| `rpcs3/rpcs3qt/localized_emu.h` | U | 16 | 20 | 14 | VR strings (mid-switch insertion) |
| `rpcs3/Emu/RSX/Overlays/HomeMenu/overlay_home_menu_settings.cpp` | U | 56 | 20 | 7 | home_menu_settings_vr page (own class, appended) |
| `rpcs3/Emu/localized_string_id.h` | U | 16 | 19 | 14 | VR ids inserted mid-enum (two places) |
| `rpcs3/Emu/RSX/VK/VKPresent.cpp` | R | 685 | 19 | 7 | flip(): ~70-line upstream block (swapchain acquire) moved below the capture block; OpenXR publish/commit inline; 246 lines appended at EOF |
| `rpcs3/Emu/RSX/VK/VKGSRender.h` | R | 224 | 16 | 3 | ~220 lines of VR members, nested structs and ~45 GPU-profiler fields inside the class body |
| `rpcs3/Emu/Cell/Modules/cellVdec.cpp` | R | 8 | 16 | 6 | vdec_open_count() for the video vblank cap (appended function) |
| `rpcs3/Input/keyboard_pad_handler.cpp` | D | 91 | 15 | 8 | RPCS3_VR_KEYS scripted key presses (process_key_script) |
| `rpcs3/Emu/RSX/VK/VKVertexProgram.cpp` | S | 3 | 15 | 6 | vr_keep_depth in insertMainEnd |
| `rpcs3/rpcs3qt/emu_settings_type.cpp` | U | 10 | 13 | 13 | 10 cfg_location entries (mid-map) |
| `rpcs3/Emu/RSX/VK/VKRenderTargets.h` | R | 24 | 13 | 11 | render_target::vr_pose field; surface_cache::find_color_surface |
| `rpcs3/Emu/RSX/Overlays/HomeMenu/overlay_home_menu_components.h` | U | 42 | 13 | 3 | home_menu_dropdown filter/relabel + value index map (generic; upstream candidate) |
| `rpcs3/Emu/RSX/Program/GLSLSnippets/RSXProg/RSXFragmentTextureOps.glsl` | S | 16 | 12 | 1 | VR_REPROJECT homography in _texcoord_xform (under #ifdef _VR_REPROJECT) |
| `rpcs3/Emu/RSX/VK/VKOverlays.cpp` | R | 93 | 11 | 6 | ui_overlay_renderer_xr, force_side_by_side parameter, vr_homography_warp_pass (new class, ~75 lines) |
| `rpcs3/Emu/RSX/Program/GLSLInterpreter/VertexInterpreter.glsl` | S | 4 | 11 | 9 | VR_KEEP_DEPTH |
| `rpcs3/Emu/Cell/lv2/lv2.cpp` | D | 43 | 11 | 8 | RPCS3_SYSCALL_PROFILE, marked TEMP in the source |
| `rpcs3/Emu/RSX/VK/VKTextureCache.h` | R | 27 | 10 | 8 | occlusion_depth_readback early-out in flush (reorders 2 upstream lines), m_flip_uploads, blit_vr_right decl |
| `rpcs3/Emu/RSX/VK/vkutils/device.cpp` | R | 29 | 9 | 4 | spare graphics queue for the OpenXR frame thread; XR device extensions |
| `.ci/deploy-windows-clang.sh` | P | 4 | 9 | 2 | same |
| `rpcs3/Emu/RSX/Overlays/HomeMenu/overlay_home_menu_settings.h` | U | 13 | 8 | 2 | add_dropdown filter/relabel parameters; home_menu_settings_vr decl |
| `rpcs3/Emu/RSX/Core/RSXDrawCommands.cpp` | R | 12 | 8 | 3 | the camera probe hook at the end of fill_vertex_program_constants_data (the core instrument) |
| `rpcs3/rpcs3_version.cpp` | P | 13 | 7 | 2 | RPCS3_VR_VERSION define; edits upstream's version line (conflicts at every upstream bump); openxr branch special case |
| `rpcs3/Emu/system_config_types.cpp` | U | 24 | 7 | 3 | fmt for vr_frame_rate (appended) |
| `rpcs3/Emu/RSX/Program/Assembler/FPOpcodes.cpp` | S | 11 | 7 | 2 | unimplemented FP opcodes log instead of throw (GT5 loading shader) |
| `rpcs3/Emu/system_config_types.h` | U | 16 | 6 | 3 | enum vr_frame_rate (inserted mid-file) |
| `rpcs3/Emu/RSX/VK/vkutils/device.h` | R | 6 | 6 | 4 | m_xr_queue accessors |
| `rpcs3/Emu/RSX/Program/GLSLSnippets/RSXProg/RSXDefines2.glsl` | S | 4 | 6 | 0 | vertex_context_t: reserved[3] becomes vr_keep_depth + 2 reserved (layout hazard) |
| `rpcs3/Emu/RSX/Overlays/HomeMenu/overlay_home_icons.cpp` | U | 2 | 6 | 0 | vr icon |
| `.ci/deploy-windows.sh` | P | 4 | 6 | 2 | copy vr-games.md, vr-settings.md, docs into bin |
| `rpcs3/Input/keyboard_pad_handler.h` | D | 11 | 5 | 4 | scripted_key_event struct + process_key_script decl |
| `rpcs3/Emu/RSX/NV47/HW/nv0039.cpp` | R | 28 | 5 | 4 | stereo-inspector note; keep_rendered_display_buffers skip |
| `rpcs3/Emu/RSX/VK/vkutils/commands.h` | R | 5 | 4 | 1 | command_pool::create flags parameter (upstream candidate); invalidate_state_cache |
| `rpcs3/Emu/RSX/VK/VKRenderPass.cpp` | R | 7 | 4 | 4 | g_end_renderpass_hook |
| `rpcs3/Emu/RSX/VK/VKOverlays.h` | R | 28 | 4 | 3 | declarations for the two new passes |
| `rpcs3/Emu/RSX/Overlays/HomeMenu/overlay_home_menu.cpp` | U | 1 | 4 | 1 | page_navigation::exit_menu |
| `rpcs3/Emu/RSX/Overlays/HomeMenu/overlay_home_icons.h` | U | 1 | 4 | 0 | fa_icon::vr |
| `rpcs3/VKGSRender.vcxproj.filters` | P | 2 | 3 | 1 | VKOpenXR files |
| `rpcs3/VKGSRender.vcxproj` | P | 2 | 3 | 1 | VKOpenXR files |
| `rpcs3/Emu/RSX/VK/vkutils/instance.cpp` | R | 11 | 3 | 2 | XR instance extensions |
| `rpcs3/Emu/RSX/VK/vkutils/commands.cpp` | R | 4 | 3 | 1 | flags parameter plumbing |
| `Utilities/bin_patch.cpp` | P | 22 | 3 | 2 | patch key "Enabled By Default" (7 small hunks) |
| `rpcs3/Emu/RSX/VK/vkutils/swapchain.cpp` | R | 8 | 2 | 1 | global submit lock around vkQueuePresentKHR |
| `rpcs3/Emu/RSX/VK/VKRenderPass.h` | R | 4 | 2 | 2 | hook declaration |
| `rpcs3/Emu/Cell/lv2/sys_timer.cpp` | D | 173 | 2 | 2 | env-var dev hooks inline in sys_timer_usleep (PPU_TRACE, PPU_WATCH, PPU_RWATCH, CALLSTACK_AT, PPU_SAMPLE, USLEEP_STATS) |
| `.gitignore` | P | 8 | 2 | 2 | un-ignore bin/vr_profiles and bin/patches |
| `rpcs3/Emu/RSX/Utils/color_utils.hpp` | S | 1 | 1 | 1 | VR_REPROJECT_BIT appended to texture_control_bits (bit budget hazard) |
| `rpcs3/Emu/RSX/VK/vkutils/instance.h` | R | 2 | 0 | 0 | handle() accessor (upstream candidate) |
| `Utilities/bin_patch.h` | P | 3 | 0 | 0 | enabled_by_default fields |
