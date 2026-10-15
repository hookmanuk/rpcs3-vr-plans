# Variable-rate shading: full resolution in the centre, less in the lens periphery

Plan for fixed foveated rendering in the fork with Vulkan `VK_KHR_fragment_shading_rate`: every pass into an
eye-sized stereo target carries a shading-rate attachment that keeps the centre of each eye at full rate (1x1) and
shades the outer part, which the headset's lens shows blurred, at 2x2 (and the corners at 4x4). Written 2026-10-15
against fork commit `4957e702d` (vr11 + the night's work) on the `openxr` branch of hookmanuk/rpcs3. Evidence labels
as in [3-investigation.md](3-investigation.md): `[SOURCE]` verified in the checked-out code, `[LIVE]` measured at
runtime, `[SPEC]` from the Vulkan specification (re-check with the validation layers at bring-up), `[INFERENCE]`
expected but not yet proven.

Companion: [12-hidden-area-mask-plan.md](12-hidden-area-mask-plan.md) (pixels the lens never shows; cheaper, and
the same per-eye geometry feeds both).

## 1. Why

The games that miss their rate on Matt's PC are GPU-bound on pixel work, not on draw count or the game's CPU. Uncharted's
jungle (`vrtest_uncharted_jungle`, Matt's config: 300%, DLSS Performance + frame generation, 2880x2880 eyes on the
OpenXR Simulator) `[LIVE]` (`profiles/BCUS98103-notes.md`):

| Pass | GPU ms / frame | Draws |
|---|---|---|
| Main scene `c07d0000` (foliage, rock) | 9.4 | 990 |
| Present: DLSS upscale + frame generation + composite, both eyes | 5.3 | - |
| Pre-scene pass `c34b0000` | 3.0 | 58 |
| Depth prepass `c0f50000` | 2.8 | 1159 |
| Shadow mask, depth copies, shadow maps, small passes | 4.1 | - |
| **Total** | **24.6** (GPU 86 % busy; the RSX thread at 100 % of a core, mostly waiting on it) | 3675 |

Resolution is the only lever that moved it: 250 % gave 53 FPS on the boat, 100 % 66-68, and the game's own effects
are each worth under 1 FPS (shadows, MSAA, single passes). The eye shape is 150 % x 300 % at "300 %": 1920x2160
rendered per eye, upscaled by DLSS to 2880x2880. God of War III (`vrtest_gow3_gaia2`) is the same shape of problem:
52-59 FPS with 16 ms of RSX-thread time per frame against the GPU.

A headset lens resolves far less at the edge of the view than at the centre (pancake lenses lose about half their
sharpness beyond ~30 degrees off-axis), so pixels there are shaded at a resolution the eye cannot see. Shading the
outer part of each eye at 2x2 halves the pixel work in that region for no visible loss; the centre keeps the
configured resolution. Expected `[INFERENCE]`: with 1x1 inside a 60 % x 60 % centre, 2x2 outside it and 4x4 in the
corners, the per-pixel passes (scene, pre-scene, prepass, shadow mask: ~16 ms of the 24.6) drop by 35-45 %:
roughly 24.6 -> 18-19 ms, 40 -> 52-55 FPS in the jungle, and 45 locked holds there with frame generation on. The
present pass (5.3 ms) is untouched: DLSS runs on the full eye.

## 2. What it needs from Vulkan `[SPEC]`

- `VK_KHR_fragment_shading_rate` (device extension; NVIDIA Turing and later, so the 5090). Features
  `VkPhysicalDeviceFragmentShadingRateFeaturesKHR::attachmentFragmentShadingRate` (a rate image per render pass) and
  optionally `pipelineFragmentShadingRate`. Properties
  `VkPhysicalDeviceFragmentShadingRatePropertiesKHR::minFragmentShadingRateAttachmentTexelSize` /
  `maxFragmentShadingRateAttachmentTexelSize` (NVIDIA: 16x16 texels per rate texel; a 1920x2160 eye needs a 120x135
  rate image), `fragmentShadingRateWithShaderDepthStencilWrites`, `fragmentShadingRateWithSampleMask`,
  `fragmentShadingRateWithFragmentShaderInterlock` (RPCS3 uses `gl_FragDepth` in a few paths and sample masks with
  MSAA; both must be allowed or those pipelines keep 1x1).
- The rate image: `VK_FORMAT_R8_UINT`, usage `VK_IMAGE_USAGE_FRAGMENT_SHADING_RATE_ATTACHMENT_BIT_KHR`, layout
  `VK_IMAGE_LAYOUT_FRAGMENT_SHADING_RATE_ATTACHMENT_OPTIMAL_KHR`, one layer per eye (2 layers for multiview: the rate
  attachment may be an array matching the view mask), texel value = `(log2(h) << 2) | log2(w)` (0 = 1x1, 5 = 2x2,
  10 = 4x4).
- The render pass: `VkFragmentShadingRateAttachmentInfoKHR` chained to `VkSubpassDescription2` (the renderpass2 API;
  RPCS3 creates passes with `vkCreateRenderPass` / `VkSubpassDescription` `[SOURCE]` `VKRenderPass.cpp:360-392`, so the
  stereo variants that carry a rate attachment move to `vkCreateRenderPass2` with `VkAttachmentDescription2` and
  `VkRenderPassMultiviewCreateInfo`'s view masks expressed as `VkSubpassDescription2::viewMask`). The attachment is
  listed with the others and referenced from the subpass with `shadingRateAttachmentTexelSize`.
- Pipelines: `VkPipelineFragmentShadingRateStateCreateInfoKHR` chained to `VkGraphicsPipelineCreateInfo` with
  `fragmentSize` 1x1 and `combinerOps` `{KEEP, REPLACE}` (the attachment's rate wins), or the dynamic state
  `VK_DYNAMIC_STATE_FRAGMENT_SHADING_RATE_KHR` set once per command buffer with `vkCmdSetFragmentShadingRateKHR`.
  Static is simpler and the pipeline cache key already carries the render pass.
- The framebuffer: the rate image's view among the attachments; a framebuffer without one uses 1x1 everywhere.
- Interaction with MSAA: the rate applies per pixel; a 2x MSAA surface at rate 2x2 shades one fragment per 2x2
  pixels and still writes all samples (coverage from the rasteriser). Fine for the game's 2x targets.

## 3. Where it goes in the fork `[SOURCE]`

| Piece | Where | Notes |
|---|---|---|
| Extension and features | `vkutils/device.cpp:103-128` (feature query, next to multiview) and `:617-631` (requested extensions, the VR block) | add `fragment_shading_rate` to `optional_features_support`, request the extension and chain the features struct; `device.h:193` style getter |
| Rate image per eye-sized stereo target | new `VK/VKShadingRateVR.{h,cpp}`: owns one 2-layer `R8_UINT` image per (width, height) of a view target, built on first use from the headset's per-eye FOV (`m_vr_eye_fov[2][4]`, tangents, `rsx_camera_probe.h:1124`) and the rendered FOV (`render_fov`, `VKGSRenderVR.cpp:1732-1800`): the texel rate is a function of the angle from the eye's axis | the visible rectangle of the target maps to `eye_fov` inside `render_fov` (the margin from `effective_reprojection_margin`): everything outside `eye_fov` is 4x4, inside it 1x1 within the centre ellipse and 2x2 beyond |
| Render pass variant | `VKRenderPass.cpp` renderpass key: a new bit "rate attachment" (`renderpass_key_blob` has spare bits beside `view_mask`); the fork's `vr_renderpass_multiview_info` hook (`VKMultiviewVR.cpp:82`) grows into `vr_renderpass_create(...)` that builds the renderpass2 version when the bit is set | one-line call site change in the upstream file (as the multiview pNext today); everything else in fork files |
| Framebuffer | `VKFramebuffer.cpp:24-26` key (add a bit), `VKGSRender.cpp:2747` passes `vr_framebuffer_images()` (fork function): append the rate view when the target qualifies | the DLSS motion attachment is appended the same way today |
| Pipelines | `VKPipelineCompiler.cpp:178-189`: chain the shading-rate state when the render pass has the bit (`vk::get_renderpass_view_mask(create_info.renderpass_key)` is already read there for multiview) | one line; the pipeline cache key includes the renderpass key, so VRS and non-VRS pipelines do not collide |
| Which targets | `VKGSRenderVR.cpp` where `m_vr_draw_view_mask` is chosen (stereo draws into view targets): a target gets the rate attachment when stereo renders, it is a view target (`profile->is_view_target`) at the eye size, and the pass is not a readback or DLSS input that must stay uniform | shadow maps, reflections, small passes: never (they are not in eye space) |
| Setting | `Video > VR > Foveated Shading` (Off / Mild / Strong: centre 70 % / 55 % of the eye at 1x1), home menu live toggle like DLSS's; dev `RPCS3_VR_VRS=0/1/2` | default Off until the headset check |

Image views: multiview samplers see the rate image never (it is not sampled). The rate image is written once from the
CPU (`vkCmdCopyBufferToImage`) when the eye FOV changes by more than a degree (reprojection margin changes it), and
transitioned to the shading-rate layout; a per-eye 2x2 texel border of 1x1 around the HUD box keeps text sharp
(`map_box_scissor` gives the box rectangle per eye).

## 4. Where it must not apply

- Passes that read back to the guest (`late_readback_sections`, `skip_readback_sections` lists) and the game's own
  readbacks (Uncharted reads `0x31030000` every frame `[LIVE]`): a lower shading rate changes the bytes the game sees.
  Readback targets are small and not eye-sized, so the eye-size test excludes them; log any that would qualify.
- DLSS inputs: the motion vectors and depth DLSS consumes come from the same eye targets. A rate of 2x2 on the colour
  is what DLSS then upscales; motion and depth are per pixel from the rasteriser (`fragmentShadingRateWithShaderDepthStencilWrites`
  matters only for `gl_FragDepth` writers). NVIDIA's DLSS guide allows VRS input but warns of flicker at rate
  boundaries; the Mild preset's 2x2 region sits where DLSS's output is behind the lens's blur anyway. Check in the
  headset before Strong.
- The HUD box and the fixed screen: 1x1 (text).
- Fixed-screen frames (menus, videos): no attachment.

## 5. Stages

| Stage | Work | Done when |
|---|---|---|
| 1 | Device: extension, features, properties logged (`VR: fragment shading rate: attachment yes, texel 16x16`) | log line on the 5090; nothing else changes (regression run unchanged) |
| 2 | Rate image + renderpass2 variant + framebuffer bit + pipeline chain, gated by `RPCS3_VR_VRS=1`, a uniform rate image (all 1x1) | validation layers clean on `vrtest_uncharted_jungle` and `vrtest_gow3_gaia2`; picture identical to today (`regcompare.py` picture diff 0) |
| 3 | The real rate map from `eye_fov` / `render_fov`; dev `RPCS3_VR_VRS_DEBUG=1` tints 2x2 and 4x4 regions in the eye | simulator shots show the centre untouched; GPU profile per target shows the scene / prepass drop |
| 4 | Setting and home-menu toggle; profiles may set `foveated_shading: false` for games whose post passes break (a screen-space effect sampling at pixel precision) | `vr_regress.sh` over the usual states at 72 / 90: no state slower, pictures within the usual diff |
| 5 | Headset (Matt): Mild then Strong in Uncharted's jungle and GoW III; look for shimmer at the rate boundary with DLSS on, and whether the periphery blur is visible when the eye looks there (it will be: fixed foveation assumes the gaze is near the centre) | Matt's verdict decides the default |

Measurement: `tools/re/vr1pct.sh` / the `unc_ab.sh` pattern (uncapped Vblank 600, 16 x 1 s windows, two fresh loads
per setting) with `RPCS3_VR_GPUPROF=1` for the per-target split, DLSS off and on, 300 %. Success is the jungle at
45 locked with frame generation on and 0 windows under 44.5 in 30 s.

## 6. Risks and open questions

- Renderpass2 migration for the stereo variants only: the fork already owns the stereo render-pass variants through
  `vr_renderpass_multiview_info`; the rest of RPCS3 keeps `vkCreateRenderPass`. Mixed use is fine `[SPEC]`.
- `renderpass_key_blob` bit budget: `view_mask : 2`, `base_layer : 3`, `layer_count : 3` are already fork additions;
  one more bit fits (`VKFramebuffer.cpp:24-26`, and the renderpass key in `VKRenderPass.cpp`'s blob).
- Pipelines created by the shader interpreter (`vr_interpreter_pipeline_state`) need the same chain.
- `vkCmdClearAttachments` and the fork's per-eye clears (`vr_clear_attachments`) ignore the rate: fine.
- Occlusion queries (`get_occlusion_query_result`): sample counts are unchanged by VRS (coverage is per pixel) `[SPEC]`.
- Alpha-tested foliage (Uncharted) at 2x2: the alpha test runs once per 2x2 block, so leaf edges in the periphery
  get blockier than a plain resolution drop would. Mild keeps 2x2 beyond ~35 degrees where the lens hides it.
- If `fragmentShadingRateWithFragmentShaderInterlock` or the depth-write cap is false on the driver, pipelines using
  those features silently keep 1x1 (not an error).
- Not for the simulator's eyes to judge: the simulator window shows the eye unblurred, so the periphery will look
  worse there than in the headset. Judge on the headset; the simulator is for correctness and the GPU profile.
