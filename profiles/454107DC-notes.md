# Burnout Revenge (Xbox 360, 454107DC) - VR notes

Recomp: `H:\Xerenge` (hookmanuk/Xerenge, ReXGlue + plume), branch `vr`; SDK `H:\Xerenge\rexglue-sdk`, branch `vr`.

## Run

    cd H:\Xerenge\rexglue && sh run.sh --vr            # SteamVR running; add --windowed for a desktop window
    sh run.sh --vr --draw_resolution_scale_x=3 --draw_resolution_scale_y=5   # 3840x3600 an eye

`--vr` = the xenos GPU plugin on Vulkan + `--vr=true`. Defaults set by `rexglue/src/burnout_vr.cpp` in VR: vsync off,
`XERENGE_UNLOCK_FPS=1`, eyes 2560x2160 (2x3), `MCLA_VR_DIRECT_RESOLVE=0`, the HUD shaders (`MCLA_VR_HUD_VS`), the
matrices' registers (`vr_world_constant=-1`, `vr_wvp_constant=0`, `vr_constants_transposed=true`).

## Build

`H:\Xerenge\build_game.cmd` (game + the SDK runtime it compiles; ~3-5 min incremental). `H:\Xerenge\build_sdk.cmd`
builds only the SDK's codegen tool. Never `scripts/setup-sdk.sh` (it hard-resets the SDK to origin). Close
burnout.exe first (else lld cannot write it). `openxr_loader.dll`, `bbport_dlss.dll`, `nvngx_dlss.dll` copied into
`rexglue/build` from the MCLA build.

## Test tools (scratchpad bo/)

`borun.sh NAME [args]` (simulator, pad file, eye shot, frame log, thread dump triggers), `race.sh NAME` (pad route
to the Traffic Attack race at Sunshine Keys from the save), `bodrive.py`, `poses.py PREFIX` (real head poses),
`eyeshot.py`, `symstacks.py` (host stacks named by exports). Triggers: `VR_LOG_FRAME_FILE` (a frame's draws +
c0-c23), `XERENGE_THREAD_DUMP` (guest threads' lr, r3-r5, r31 and the vtables of r30/r31), `MCLA_VR_EYE_SHOT`.

## Facts

- Camera: CGtViewport::Update (sub_8235A080) builds the camera's world matrix on its stack (rows right, up, at, pos at
  r1+80..), copies it into the camera frame (RwFrameGetMatrix sub_820FBE60 from 0x8235A1A4), view window via
  sub_82353BA8 -> RwCameraSetViewWindow sub_8234ABC0 (0x82353C14), viewport+0 from sub_821425A8. The renderer's view:
  sub_82175350 reads the frame (0x82175374, 0x821753A0, 0x82175614). Race viewport 82923220. RenderWare's camera is
  left-handed (right x up = at): OpenXR x = -right, y = up, z = -at.
- Shader constants: gObjToProjMatrix c0-c3 (transposed: clip.i = dot(c_i, pos)), gObjToWorldMatrix c15 (34 of 174
  shaders), gWorldToProjMatrix c19 (10 of 174).
- Frame: scene 1280x720 2x MSAA in three predicated tiles (256 rows), resolved per tile; bloom 320 wide; composite
  vs D714DEDADAB9415A into the 1x 1280 target; HUD vs BCEC88072A5F344D / 30B5339A49CB9B5B / B2352AFC8C60D6B7 /
  D25CBA074BB11277; resolve to the frontbuffer.
- Bloom carries half the picture: the composite (ps FB3A19D15B918C21) is 1.17 x the scene (pixel c50.x x 0.25 over 8
  taps) + 1.5 x the bloom (320x180, ps C976E1B2F0B205DC extract then 6B97F1EC888F4E4D blur, weights pixel c56-c63).
  XERENGE_NO_BLOOM (any value, also empty: getenv) skips the setup that sets those weights, and on xenos the bloom term
  is black: the frame at ~0.4x, a stormy sky. Plume with bloom off adds the pixel itself. Test scripts must leave the
  variable unset, not empty. The frame log (VR_LOG_FRAME_FILE) prints each draw's texture fetch constants 0-5 and
  pixel constants c48-c63, c250-c255; --dump_shaders=DIR writes the microcode disassembly.
- Accelerate is RT (pad file token `rt`); `up` is the d-pad and does nothing in a race (earlier "at speed" shots were the
  rolling start).
- DLSS and the logic-step interpolation: see 6-wip-games (MCLA_VR_DLSS_TILES, MCLA_VR_CAMERA_VS, vr::SetFrameInterpolation,
  XERENGE_VR_INTERPLOG for the per-frame state, t and camera).
- Movie player (main menu): object with five synchronization events at +84..+148 and wait wrappers sub_8248D1E0..
  sub_8248D240 (vtable 82056A28 +160..+176); the main thread waits on +132 (sub_8248D228 from 0x8248E8B0), the worker
  on +100 (sub_8248D1F8 from 0x8248DAC4).
