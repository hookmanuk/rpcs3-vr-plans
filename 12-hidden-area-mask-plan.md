# Hidden-area mask: never shade the pixels the lens cannot show

Plan for using the headset's visibility mask (`XR_KHR_visibility_mask`) so that the corners of each eye that the lens
never shows are rejected by the depth test in every pass, instead of being shaded in full. Written 2026-10-15
against fork commit `4957e702d` on the `openxr` branch of hookmanuk/rpcs3. Evidence labels as in
[3-investigation.md](3-investigation.md): `[SOURCE]` verified in the checked-out code, `[LIVE]` measured at runtime,
`[SPEC]` from the OpenXR / Vulkan specifications (re-check at bring-up), `[INFERENCE]` expected but not yet proven.

Companion: [11-vrs-plan.md](11-vrs-plan.md) (lower shading rate in the periphery; the two stack).

## 1. Why

Each eye is rendered as a rectangle (1920x2160 at "300 %" `[LIVE]`), but a headset lens shows a rounded area inside
it. The corners outside that area are shaded, lit and post-processed every frame and then thrown away by the
compositor. Runtimes report the hidden region as a triangle mesh per eye; typical headsets hide 10-20 % of the
rectangle (more on wide-FOV displays with canted panels). Uncharted's jungle spends ~16 ms of a 24.6 ms GPU frame on
per-pixel passes `[LIVE]` (`profiles/BCUS98103-notes.md`), so 10-20 % fewer pixels is 1.5-3 ms a frame, with no
visible change at all. The fork already rejects hidden pixels in one case: with a HUD box clear it fills the depth
outside the box with the near value so later draws fail the depth test (`vr_clear_attachments`, "near_depth" /
"outside" rectangles, `VKGSRenderVR.cpp:5045-5080` `[SOURCE]`). This plan does the same for the lens-hidden corners
on every eye target, every frame.

## 2. What it needs `[SPEC]`

- OpenXR `XR_KHR_visibility_mask`: `xrGetVisibilityMaskKHR(session, viewConfigurationType, viewIndex,
  XR_VISIBILITY_MASK_TYPE_HIDDEN_TRIANGLE_MESH_KHR, &mask)` returns per view a triangle list of the hidden region
  (two-call size query). Vertex positions are 2D in the view's projection at unit distance: x and y in tangent-of-angle
  units of the view's `XrFovf`, so a vertex maps to the eye target through the same `render_fov` tangents the fork
  maps the game's camera through (`remap_to_eye_fov`, `rsx_camera_probe.cpp`). `XrEventDataVisibilityMaskChangedKHR`
  tells when to fetch again (per-user IPD / lens changes). SteamVR and most runtimes implement it; the OpenXR
  Simulator does not (no extension), so a synthetic mask is needed for simulator testing (section 5).
- Nothing new from Vulkan: `vkCmdClearAttachments` on the depth aspect with a list of rectangles, as the fork does
  today, or one depth-only draw of the mesh through `attachment_clear_pass` (`vr_clear_attachments_masked` shows the
  overlay-pass route, `VKGSRenderVR.cpp:5085-5110`). The clear value is the *near* side of the game's depth range:
  the game clears depth to its far value (1.0 for the usual LEQUAL tests; a reverse-Z game clears to 0 and tests
  GEQUAL), so the hidden fill is 1 - clear value, and draws that depth-test fail there whatever function they use
  except ALWAYS. The clear must go into both layers with each eye's own mesh (view masks 2 and 3, as the HUD-box clear).

## 3. Where it goes in the fork `[SOURCE]`

| Piece | Where | Notes |
|---|---|---|
| Fetch the mask | `VKOpenXR.cpp:696` (requested instance extensions: add `XR_KHR_VISIBILITY_MASK_EXTENSION_NAME` when enumerated, as `XR_FB_display_refresh_rate` is), a `xr::visibility_mask(eye)` accessor; refetch on `XrEventDataVisibilityMaskChangedKHR` in the event loop and at session start | fork file |
| Map to the eye target | new `VK/VKHiddenAreaVR.{h,cpp}`: per eye, the mesh in tangent units -> target pixels through the eye's rendered FOV (`render_fov[eye]`, `VKGSRenderVR.cpp:1732-1800`; the visible `eye_fov` sits inside it by the reprojection margin: pixels outside `eye_fov` are hidden too and join the mask). Rasterised once into horizontal bands of `VkClearRect`s (rows of 8-16 pixels, left and right spans per row: ~300 rects per eye at 2160 rows), rebuilt when the target size or the FOV changes | the band list is the same form `vr_clear_attachments` already feeds to `vkCmdClearAttachments` |
| Apply after the game's depth clear | `vr_after_clear` (`VKGSRenderVR.cpp:3600`): when `full_frame && update_z`, stereo renders, the bound depth surface belongs to a view target at the eye size (`profile->is_view_target`) and the headset view is on (not the fixed screen): end the render pass, begin the per-eye variant (view mask 2 / 3, `get_renderpass_key(m_fbo_images, {}, view_mask)` as at `:5071`) and clear the depth bands to the hidden value | reuses the existing per-eye clear code; a scissored depth clear by the game (partial) is left alone |
| Depth surfaces cleared by a draw, not a clear | some games clear depth by drawing a full-screen quad (`depth_write` on, test ALWAYS): hook `vr_setup_draw` for a full-frame depth-only draw into a view target with test ALWAYS and apply the fill after it (`m_vr_frame_covered` already tracks full-frame colour fills) | second step, only if a game needs it |
| Setting | `Video > VR > Hidden Area Mask` (on by default once checked), dev `RPCS3_VR_HIDDEN_AREA=0/1` and `RPCS3_VR_HIDDEN_AREA_SYNTH=<fraction>` (an ellipse inscribed in the eye, for the simulator) | profile key `hidden_area_mask: false` for games whose passes break |

## 4. Where it must not apply, and side effects

- Depth readbacks to the guest: a game that reads its depth buffer back (none of the three games here; the profile's
  readback lists say which sections are read) would see the fill. Skip the fill for depth surfaces in
  `late_readback_sections` / sections the generator logs as read back.
- Depth-as-colour passes (deferred lighting, SSAO, the depth remap passes): they sample the hidden pixels at the near
  value. The results land only in hidden pixels (screen-space passes map pixel to pixel), except blurs and
  down-samples near the mask edge, which pull a few near-depth texels into visible pixels: Uncharted's sun-shadow
  mask (`fc15ec0752d20290`) reads depth per pixel (no blur) `[LIVE]`; its 640x360 depth downsample (`2ffe2bfb47d877be`)
  would see them. Mitigation: shrink the mask by 8 pixels (a band) so the edge sits inside the hidden region, and
  check each game's edge for a halo (simulator, synthetic mask, eye dumps `RPCS3_VR_RTDUMP`).
- Occlusion queries / ZCULL: objects entirely inside the hidden corners report zero passed samples and the game may
  stop drawing them next frame: that is the point. Objects crossing the edge report fewer samples; games use
  thresholds of "any sample" (`[INFERENCE]`; GT5 and Uncharted use occlusion queries), so no change expected.
- DLSS: its input colour has garbage (whatever the game left) in the hidden corners, upscaled into hidden output
  pixels; its convolution reads a few pixels across the edge. Fill the hidden colour with the frame's clear colour
  too (a colour clear of the same bands at the game's clear) so the edge is uniform. Frame generation's motion
  vectors there are zero: fine.
- The fixed screen shows the whole rectangle (menus, cutscene mode): no mask on those frames (they are not in the
  headset view, so the condition above excludes them).
- Head reprojection (`reproject_older_frames`, the OpenXR layer's own reprojection): the hidden region moves with the
  head; a reprojected older frame can bring a hidden-region pixel into view at the edge for one frame. The runtime's
  own mask hides the same region at display, so this is at most a one-frame edge artefact under fast turns.

## 5. Stages

| Stage | Work | Done when |
|---|---|---|
| 1 | Synthetic mask (`RPCS3_VR_HIDDEN_AREA_SYNTH=0.9`: an ellipse with semi-axes 0.9 of the eye's half-extents in tangent space), band rasteriser, the depth fill in `vr_after_clear`, dev tint of the masked bands (`RPCS3_VR_HIDDEN_AREA_DEBUG=1` clears colour to magenta there) | simulator eye dumps show the corners magenta in every pass's target that follows a full depth clear; validation layers clean |
| 2 | GPU profile A/B on `vrtest_uncharted_jungle` and `vrtest_gow3_gaia2`: the per-pixel passes drop by about the masked fraction | measured, in the notes |
| 3 | `XR_KHR_visibility_mask` fetch, mapping through `render_fov`, mask-changed event; log the mask's covered fraction per eye | log line on the headset; the simulator path falls back to the synthetic mask only with the env set |
| 4 | Colour fill of the bands (DLSS edge), the 8-pixel inset, the `hidden_area_mask` profile key, the setting | regression run unchanged at 72 / 90 on the usual states |
| 5 | Headset (Matt): corners clean at the edge of view in Uncharted (sun shadows), GoW III, Dragon Age: Origins and GT5; look for a halo at the mask edge in deferred-lit games | Matt's verdict; default on when clean |

Measurement as in the VRS plan: `unc_ab.sh`-style fresh loads with `RPCS3_VR_GPUPROF=1`, uncapped, DLSS off and on.

## 6. Open questions

- The exact vertex space of `XrVisibilityMaskKHR` (tangent units at unit distance, vs normalised device coordinates
  of the view's projection): the spec text says positions are in the view's "projection space ... x and y as
  tangent-of-angle" `[SPEC]`; confirm against SteamVR's returned extents (they should match `eye_fov`'s tangents).
- Whether the fork's eye targets are exactly the rendered FOV rectangle: `render_fov` is `eye_fov` widened by the
  reprojection margin (`locate_render_pose`), and the camera maps the game's view onto `render_fov`
  (`remap_to_eye_fov`). If so the band mapping is a scale and offset per axis; otherwise read the mapping from
  `map_box_scissor`.
- MSAA depth surfaces: `vkCmdClearAttachments` clears all samples: fine. The Z24 depth copies the fork makes for
  depth-as-colour passes copy the fill with the rest: intended.
- Games whose depth is cleared once per frame but whose eye target is drawn through several render targets of the
  same size (GoW III's prepass into target 0 with depth `0xc18e0000`, then the colour pass with the same depth): one
  fill after the clear covers all of them, since the depth surface is shared.

## 7. Progress (branch `vr-pixel-savings` of `rpcs3/`)

Stage 1 is in (`22e5956be`, off by default). Dev `RPCS3_VR_HIDDEN_AREA=<scale>` (the ellipse inscribed in each eye's
visible field, scaled; 1 touches the visible edges), `RPCS3_VR_HIDDEN_AREA_INSET` (default 8 px kept inside),
`RPCS3_VR_HIDDEN_AREA_DEBUG=1` (magenta colour there too). The fill runs from `vr_after_clear` after a full-frame
depth clear of an eye-sized view target, per eye (view masks 2 / 3) in 8-row bands; `camera_probe::vr_eye_fovs`
gives the rendered and visible fields. The reprojection margin (rendered minus visible) is never masked.

Stage 2, `vrtest_uncharted_jungle`, 300 %: scale 1.0 masks 20 % of the shown target (more than a real lens mask:
it cuts into what the simulator shows) and gains **+0.6 FPS**; scale 1.3 masks 1.1 %. Uncharted's scene passes are
geometry-bound (see `11-vrs-plan.md` section 7: the colour pass costs 8.2 ms even at 100 %), and its foliage is alpha
tested, so its draws run late-Z: the near depth fails them only after the shader ran. The mask is worth more where the
expensive passes are full-screen and depth-tested early; to measure on GoW III.

Stage 3 (the runtime's real mask) is needed before judging: the synthetic ellipse is a guess of the lens shape.

Correction (2026-10-15, later): the "geometry-bound" reading above was itself a misdiagnosis of the GPU profile,
whose per-target times are wall intervals. An Nsight Systems trace showed the frame to be GPU busy time plus a ~3.5 ms
submission bubble after each flip (`5-vr-profile-playbook.md` > Where the frame goes). Eager submission
(`RPCS3_VR_EAGER_SUBMIT`) recovers it: Uncharted jungle 56 -> 64.5 FPS at 300 % DLSS-off. What the GPU's remaining
15.5 ms is made of (draw / vertex work or shading) is still to be measured with Nsight's GPU metrics; this plan's
value depends on that answer.
