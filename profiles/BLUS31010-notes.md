# Need for Speed Most Wanted (2012) (BLUS31010 v01.00) - findings

PPU hash `PPU-98af44a0b9e296d01619c79bced9a1985b4b6908`. Criterion's engine, libgcm directly.
Evidence: `plans/evidence/nfsmw/`.

## Running it

- Boot: title screen `Return`; first run only: TV margin screen (hold right stick-left key `L` for full
  frame, then `X`); PSN sign-in prompt (`Down`, `X` = no); then the intro cutscene hands over to driving on
  Connors Bridge Road (~3 min from boot). `nav_nfs.sh` pattern: `Return`, wait, `Down`+`X`, wait ~2 min.

## Frame rate (2026-09-24): solved, see plans/6-five-titles-status.md (the text below is the earlier dead end)

- 60 FPS in menus and the title, 30 FPS in cutscenes and gameplay, at any Vblank Rate (60/90/120), so the
  cap is not only vblank-based.
- Flip pacing through two RSX labels: the vblank handler `0x740da4` counts label A (`*0xd128e8` index)
  down each vblank and sets label B when it reaches 0; the flip code `0x73ff6c` waits on label B, then
  re-arms label A with the frame interval `*0xd128e0` at `0x7400cc`. The interval comes from the game
  state's `+0x83120` (1 in menus, 2 in game; copied at `0x494988`).
- Patch `BLUS31010-patch.yml` (`li r5,1` at `0x7400cc`) removes that gate: the RSX-label spin at `0x740158`
  disappears from the `RPCS3_USLEEP_STATS` report. **Gameplay still runs at 30.** The main thread then
  waits in a spin-sleep at `0x72f53c` (called from `0x48ff80` in the frame loop, `0x72f67c`), i.e. a second,
  time-based 30 Hz pacer. Forcing the state interval to 1 at `0x494968` did not change it either. Next
  step: trace what `0x72f490`/`0x72f67c` wait on (a job/worker completion flag at `0x72f540`?) and where
  its 1/30 comes from. The patch is installed but **disabled** in `patch_config.yml`.
- The game clock is real time at 30 (memory dumps: ~34 clocks at 1.0 s per second, `plans/tools`-style
  `memclock.py`), so once unlocked it may well need no speed fix.

## VR profile (2026-09-24)

`bin/vr_profiles/BLUS31010.json`, from the in-emulator generator after these generator/renderer changes,
then edited (`generated-in-emulator-BLUS31010.json` is the generator's output).

- **The 3D scene renders at 1280x704** (2.3% off 16:9), so nothing counted as a camera view at the 2%
  tolerance (979 of 47,762 draws). The generator now accepts targets within 5% and writes a matching
  `output_aspect_tolerance` (0.03 here).
- **New matrix layout `column_vectors_xyw`**: the camera is three DP4 slots `c[212]`, `c[213]`, `c[214]` =
  clip x, y, w; `c[215]` holds z parameters and the shader computes z itself. The generator tests it as a
  third layout (and had to stop storing the layout as a bool).
- Blocks `[212, 216]`. The generated list also had `c[0]` (a few draws, with `require_rigid_camera`); with
  it, a full-screen pass was sheared and the right eye turned orange, so it is removed.
- Camera position `c[219]`. Near plane 0.1 -> `eye_baseline` 0.064 (metres). A second stereo rule for the
  640-wide half-resolution targets (0.88x).
- **Right-eye texture fix (renderer):** the lighting pass samples a render target through a deferred
  copy with a format conversion (no direct view), which the right eye used to take from the left. The
  right eye now rebuilds such copies from its own surfaces (`VKDraw.cpp`, `bind_texture_env`).
- **HUD:** the in-game HUD panels are 3D, drawn with the camera block as a pixel-origin plane 1108.5 units
  ahead (`x = 1.73x - 1108`, `y = -3.08y + 1108`, `w = z + 1108.5`). `depth_offset_projection` now also
  accepts an x/y shift, so these go into the headset HUD box. (The desktop yaw audit rotates them with the
  world; only the headset path uses the HUD box.)
- Stereo on the desktop: both eyes render the whole frame (`stereo-noperturb-vs-c212.png` shows the c[0]
  fix). Yaw audit (`audit-yaw25.png`): road, car and city rotate together.

Open: the 30 Hz pacer; a dark region in the audit's rotated eye near the car (possibly a screen-space
shadow/decal pass); headset run.
