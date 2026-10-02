# Puppeteer (BCUS98227, disc 01.00)

Added 2026-10-01. Profile `bin/vr_profiles/BCUS98227.json` (generated in the first stage), copy in
`rpcs3/vr-non-working/`. Desktop only. Savestate `bin/savestates/BCUS98227/BCUS98227_1_0.SAVESTAT.zst`: the first
playable moment (Kutaro in the cage). The disc offers to install a bundled manual package at first boot (RPCS3 "PKG
Installation" dialog): `tools/launch.ps1` now dismisses it automatically.

## Frame rate

- Native 30: one flip every 2 vblanks (30 at Vblank 60, 90 at Vblank 180; RSX ~50% at 90).
- **Frame-locked:** at 90 FPS Kutaro walks 5.5 units in a 0.5 s hold vs 1.5 at 30 (3.7x).
- **Frame time found:** global timing struct `0x98ebe8` = {59.94 Hz, frame time 0.033367}; getter `0x84064`. Physics
  (`PhysicsStep` thread, Havok-like) gets dt = frame time x `[0x79a3b8]` (1.0) via `0xc0d64` -> `0x2629ac`
  (job `+0x1c`). The game never rewrites the frame time after boot: setting it to 1/90 at 90 FPS brought the walk
  to 1.8 (vs 1.5 at 30, 5.5 unpatched): close to real time. Profile `game_frame_time_f32: ["0x98ebec"]` sets it.
- **Still 2 vblanks per flip:** for 90 FPS on a 90 Hz headset the flip interval has to become 1. The main thread
  waits on an lv2 semaphore (`0x3f1c40`) posted by the flip handler `0x3f4f78`; the vblank handler `0x3f4fe0`
  calls through an object at `[0x7ac93c]+0x270`. Next: find the interval in that object (or the
  `cellGcmSetFlipMode` / `_cellGcmSetFlipCommandWithWaitLabel` stubs at `0x771fb8` / `0x772000`). Until then
  the profile keeps `vblanks_per_frame 2` (45 FPS at 90 Hz with the right speed, or 30 at 60 Hz).

## 2026-10-01: 90 FPS and stereo working (desktop)

- **90 FPS:** the flip interval does not need changing: at Vblank 180 the game flips every second vblank = 90 FPS,
  and the profile now has `max_fps 0`, `default_fps 0` (it kept `vblanks_per_frame 2`, so the headset path runs
  the vblank at twice the headset rate). Walk speed (Kutaro's position `0x99a010`, per-frame peek,
  `tools/re/pp_phys.sh`): 3.9 u/s at native 30, 4.0 at 90 with the profile frame time: real-time.
- **Stereo was left-eye only:** the frame goes through main memory for EDGE post-processing on the SPUs (blit of the
  scene `0xc0750000` to `0x39600000`, SPU job, result at `0x399c0000`, drawn back by the final composite), so both
  eyes showed the left eye's image (yaw audit identical, 0 px parallax). The community *Disable SPU MLAA* patch does
  not remove the bounce. Fork: new profile key **`texture_redirects`** `[{"from": "0x399c0000", "to": "0xc0750000"}]`
  makes the composite read the scene render target per eye. Parallax now ~34 px, audit correct, 90 FPS stereo
  (`evidence/puppeteer/`). Cost: the SPU post effects (MLAA) are skipped in VR (flat is unchanged: the redirect
  only applies while stereo rendering is on). *Disable SPU MLAA* was enabled in `patch_config.yml` during the test
  (harmless, saves SPU time).
- Headset view (`-FakeHmd 100`): correct but the stage is small: the game camera is a narrow ~45-degree theatre view
  (A = 2.41), so in a 100-degree headset view the stage fills about a third of the width with darkness around.
  Worth trying World Scale / camera depth in the headset.

## VR profile (generated)

`column_vectors`, camera `c[256, 264, 0]`, HUD `c[0]` + `hud_skips_passes`, metres. 100% of depth-tested draws.
Stereo and audits not yet checked (time-boxed).

## Open

- Headset run: stage size (World Scale), HUD and menus; later levels (different SPU post buffers would need their
  own `texture_redirects`).

## 2026-10-01: first headset run (Matt, 90 Hz)

- Barely works: trails of graphics everywhere and very dark. In the intro a light moves with the head.
- Savestate showing the trails: `bin/savestates/BCUS98227/vrtest_puppeteer_matt_trails.SAVESTAT.zst` (hard link to
  `BCUS98227_1_1`, 17:59).
- In the game proper it kind of works, but the world looks far away and small (world scale, `eye_baseline`).
- Desktop stereo and the fixed-pose fake headset never showed the trails; reproduce on the OpenXR Simulator with a
  head sweep from the savestate.

## 2026-10-01 evening: OpenXR Simulator, Matt's savestate (the intro stage)

- **Fixed: the light that follows the head.** Program `03dd68c4dfe94371` draws light glows at the lights' flat-screen
  positions: 160x120 halos (around the candles and the orb) and 208x252 glints (the orb). They also sample the scene
  target (occlusion), so the renderer took them as passes and left them as drawn: head-locked. `hidden_draws` for
  both (fork). Simulator, head turned 20 degrees: the head-locked dot is gone. **Check in gameplay that Pikarina's
  cursor is not one of these sprites**; if it disappears, drop the 208x252 rule.
- Trails: not seen on the simulator with the head still or sweeping (yaw 25, pitch 10 at 0.5 Hz); still open.
- Dark: the intro is dark in flat play too; in VR the SPU post (`texture_redirects`) is skipped, which may also drop
  a brightening pass. Open.
- Small and far away: the camera sits in the audience of a puppet theatre; try World Scale (VR settings) above 100%.
  `eye_baseline` 0.064 assumes metres; unchecked.

## 2026-10-02 night: darkness investigated (no fix yet)

On the OpenXR Simulator from `vrtest_puppeteer_matt_trails`, with RTDUMP of the targets (both eyes), flat vs stereo:
- Pipeline: G-buffer MRT pass (draws 1-203) into `c0750000` (scene/emissive), `c0af0000` (normals), `c0e90000`
  (packed depth), `c1230000` (albedo); depth `c17a0000` resolved to colour `c15d0000` (draw 205, `1c793403`); one
  light draw (`30532bfcf0d877be`, 18 vertices) adds ~7 of the scene's mean 18 (flat); then the SPU post (blit after
  draw 466 to `0x39600000`, SPU output at `0x399c0000`, redirected to `c0750000` in VR) and the composite.
- The G-buffers are right in the headset view (normals, albedo, the stage smaller in the wider view). The packed
  depth buffer is a left-to-right red/green gradient in the headset view (uniform yellow flat): the packed value
  depends on screen x there. Lead: the G-buffer shader packs something from the transformed clip position.
- The scene target is far darker in stereo, but frame means mislead: in the headset view the stage covers ~1/4 of
  the frame, and the scene moved between runs (throne vs cage). Not settled: with the game camera (Fixed Screen
  setting) 1.78 vs 18 flat; right-eye batching off 5.3 vs on 7.4 (different moments).
- Tried and reverted: a profile key forcing the fixed screen (`fixed_screen`); it did not fix the darkness.
- Next: a paused moment (pause menu off, or the savestate with the game paused by the PS button) to compare
  flat and stereo at identical frames; then the depth packing and the light draw's fragment constants.

## 2026-10-02 early morning: darkness explained, velocity fixed, diorama scale (fork cd9505230)

- **Darkness is the small stage, not the lighting.** Same moment, same savestate, OpenXR Simulator: with the headset FOV
  the lit stage averages 19.9 per lit pixel (14.0 with `RPCS3_OPENXR_FOV=game`), but covers 13% of the eye image
  (65% with the game FOV). The game camera is 45 x 26 degrees, the stage ~27 units away; at `eye_baseline` 0.064
  (1 unit = 1 m) that is a small lit box 27 m away in a black void. (The earlier frame means were misleading: the
  savestate plays a dark intro, then the throne, then the cage, so runs a few seconds apart differ.)
- The light pass (`30532bfcf0d877be`) does rebuild view position from `wpos` with fragment constants `fc0..fc3`
  (game projection) and samples the shadow map: in the headset view the rebuilt rays are the game's, not the eye's.
  The measurement above says the effect on brightness is small; light shapes may still sit wrong. Unchecked.
- **Velocity buffer:** the G-buffer program (`e9dd0017`, `a10a18f7`, ...) outputs position from `c[256..258]` with w
  from `c[267]`, and a velocity from the previous frame's `c[264]`, `c[265]`, `c[267]`/`c[259]`. Only the current
  block got the eye transform, so the velocity target (`c0e90000`) was a red/green gradient across the screen in the
  headset view. `linked_camera_blocks: [264]` makes it uniform. Likely the trails (unverified in the headset).
- **Scale:** `eye_baseline` 0.064 -> 0.64: the stage reads as a puppet-theatre diorama ~2.7 m away. To make it
  bigger, the VR menu's **Camera Depth Offset** (metres, +5 max; world units = metres x 10 at this scale): +2 m put
  the viewer ~20 units closer and roughly doubled the stage's size on the simulator. Matt to judge in the headset;
  if it suits, a profile default for the camera offset would need a new key.
- Tried and reverted: a profile key forcing the fixed screen.
