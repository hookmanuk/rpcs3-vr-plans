# SEGA Rally Revo (BLUS30068) - VR notes

Disc 01.00 (`SEGA Rally Revo (USA) (En,Fr,De,Es,It).iso`), PPU hash `PPU-cf7bf795662e7da4af16f0131ac7c3bef86776ce`.
Route: `tools/re/sr_boot.sh` (Start > Premier > Amateur > AZA Challenge > Safari > Subaru > race). Savestate
`sr_race0` (the Safari grid, race clock running).

## Savestates

Saving fails ("failed to lock SPU threads") even with Compatible Savestate Mode: an SPU sits in a GETLLAR reservation
wait (`exec_mfc_cmd<false>`, `unsavable` stays set). `Core > Disable SPU GETLLAR Spin Optimization: true` makes the
GETLLAR spin return to the SPU code, and the save works. Both are set in Matt's custom config
(`bin/config/custom_configs/config_BLUS30068.yml`).

## Frame rate: "Unlocked frame rate (follows Vblank Rate)"

- Native 30: the flip (`0x1e3978`, called from `0x1df7a4`) releases GCM label 0x42 with the vsync interval from the
  global `[0x10361bd4]` (2; set by a vsync-mode setter at `0x1d3f9c`-`0x1d40ec`); the GPU waits for label 0x42 = 0
  before the next flip and the vblank handler (`0x1e1fb4`) counts it down. The patch loads 1 (`0x1df79c`: `li r5, 1`).
- Game time is measured: the race clock keeps wall time at Vblank 120 (11.46 s over 11.41 s), and 5 s of throttle from
  `sr_race0` reaches the same place and 63 mph at Vblank 60 and 120. Profile `max_fps 0`.
- Flat ceiling with the patch: 175-225 FPS racing (Vblank 240), RSX thread ~5 ms.

## Culling: "Wider view (VR culling)"

The projection builder `0x174608` (8 callers, every camera mode) loads the FOV from the camera record (+0x4b8, 60
degrees high in the race) at `0x174640`; the patch calls a cave in the code segment's last page (`0x4d7140`, past the
segment end `0x4d7100`) that multiplies it by Scale (default 2.5) and clamps to 150 degrees. Found with a PINE scan for
perspective matrices (`tools/re/findproj2.py`: `0x10349cd0`, fovy 60) and a PPU write watch on it.
Trap: `lfs f0, -0x8e80(r12)` can't be encoded (16-bit signed offset); with `lis r12, 0x4e` the offset 0x7180 read
0x4e7180 and the scene went black. `lis r12, 0x4d` + 0x7180 is right.
On the simulator the view is filled straight, turned 25 degrees and pitched up 25 degrees.

## VR profile

Generated in the race (`row_vectors`, camera blocks `c[8]` (most scene), `c[0]`, `c[4]` (the road: removing it puts
the road at the game camera), camera position `c[4]`, near 0.1 = metres, `passthrough_hud`), then `max_fps 0`,
`default_fps 0`. HUD box straight and turned: OK (the left-eye edge crop with the head turned is the simulator
preview, as in DW Gundam).

## Open: dark shadow-like blobs, different in each eye

While driving, dark patches (shaped like cast shadows, often car-sized, sometimes thin streaks) appear on the road in
one eye and not the other; the car's own shadow is missing or displaced in one eye. Same with Wider view 1.0, with
zero eye separation (`per_eye_separation` 0, `eye_baseline` 0: so it follows each eye's projection, not the offset),
without `camera_position.slot` (Wolverine's per-eye cause; c[4] is also a camera block here), in two-draw unbatched mode (`RPCS3_VR_MULTIVIEW=0 RPCS3_VR_BATCH=0`), with `require_camera_aspect`, with
`hud_display_buffers_only`, with `unboxed_draws` for the HUD program's full-screen sizes.
**Gone** with `passthrough_hud: false` (HUD drawn full-view in each eye; car shadow then matches in both eyes) and
with probe `hide=ae5d1f3fa4187794+f780e2c460d9eba2` (both matrix-less HUD programs). Not gone hiding only
`f780e2c460d9eba2` (or only its main-target draws), the 640x720 pass `f78638bb1ce5eba2@50610000` (reads the depth
buffer), the draws into the 512x512 `c3574000`, the blended decal programs.
Frame layout (inspector, `insp/BLUS30068_20261004110745_f1890_stereo.jsonl`): 512x512 `c3678000` (563 scene draws
with the camera blocks) and `c3574000` (96), 912x912 `c8250000` (shadow map, 30 draws + `f780` blur ping-pong), main
1280x720 `c0580000`, then `f78638` (640x720 from depth), composite `f780`, bloom 320x180/160x90, final `f1458d64`
into the display buffer `c2542000`, HUD `ae5d1f3f` (27 draws, fp 175) + `f780` into the display buffer. The 512 and
912 targets exist once (RTDUMP has no right-eye surface for them).
Hiding `ae5d1f3fa4187794` alone: blobs remain. The runs don't replay exactly (the car took another line in the
hide-both run), so the two "gone" results need repeating at the same track spot (blobs show at fixed places, e.g.
right of the car at race time 0'29"6). Then find what the HUD box path changes outside the HUD draws (state left
over into the next frame's first draws: the 512 / 912 passes are matrix-less `f780` blurs that follow the last boxed
`f780` draw).

Scripts: `tools/re/sr_boot.sh`, scratchpad `srdrive.sh OUT [PROBE]` (simulator, `sr_race0`, throttle, 4 SBS shots).

### More on the blobs (2026-10-04 afternoon)

- Not `camera_position.slot`, not `eye_offset baseline_per_w`, not `clip_space_scene_draws`, not the 17 programs
  drawing into the 512x512 `c3678000` (hidden).
- A paused frame keeps the blob (the pause screen blurs a frozen copy of the last scene frame), so hide tests on a
  paused frame show nothing.
- **Timing-dependent:** three identical runs (`sr_race0`, throttle 9.3 s, pause; scratchpad `srpause.sh`) gave the
  left-eye blob in two and not in the third (region mean 44 vs 53). Bisecting with `gamecam=` sets is therefore
  unreliable (both halves "fixed" it). A per-eye difference that comes and goes between identical runs points at data
  that changes between the left and right eye's draws (a buffer or texture the game rewrites mid-frame), not at a
  profile key. Next: RTDUMP the main target per eye right before the post chain (`prog=f78638bb1ce5eba2`) over many
  frames to catch one with the blob, then step back with `prog=X#n` to the draw where the eyes diverge.
