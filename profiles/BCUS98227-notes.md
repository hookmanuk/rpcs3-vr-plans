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
