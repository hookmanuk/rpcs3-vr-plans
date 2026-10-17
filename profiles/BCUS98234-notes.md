# Killzone 3 (BCUS98234, disc 01.00)

Started 2026-10-17. Files: `bin/vr_profiles/BCUS98234.json` (tracked copy in `rpcs3/vr-non-working/`). PPU hash
`PPU-ae204e2198c9a051a44a69913c48f6591b811082`.

## Setup

- Community patch **Disable MLAA (Post-processing On SPU)** enabled in `config/patch_config.yml` (allows Resolution
  Scale; some screen effects lost). No update installed (disc 01.00).
- First boot: language, brightness, controller mapping, then the intro film (cannot be skipped, ~2.5 min), title, main
  menu > Campaign > Trooper. The game made a new save; no earlier save existed.
- Savestate `bin/savestates/BCUS98234/kz3_helghan_base`: first mission, first control on the Helghast walkway
  (playing in a Helghast helmet: a visor overlay frames the screen). Keyboard pad: left stick walk (`I/J/K/L`), right
  stick look (`F/H/T/G`).

## Frame rate (DLSS off)

| Mode | Vblank / rate | FPS | Notes |
|---|---|---|---|
| Flat | 60 | 30 | every 2nd vblank |
| Flat | 120 | 60.0 (1% low 46) | RSX 16.5 ms at that rate (waits) |
| Flat | 240 | **120.0** (1% low 92), RSX 8.2 ms | |
| Stereo, 300%, generated profile | Unlimited (90 Hz cadence) | **113** while walking (86-120), 1% low 64, RSX 8.1 ms | passes 72 easily |

## Profile (generated while walking, vblank 240)

`row_vectors` `c[0]` (90% of depth-tested scene draws), `linked_camera_blocks [25]` (previous-frame matrix),
`require_rigid_camera`, `require_camera_aspect`, no camera position, HUD block `c[8]`, near 0.2 (metres, `eye_baseline`
0.064), `baseline_per_w`, max_fps 120, `vblanks_per_frame` 2. Added: `hidden_draws` for the helmet visor.

Passes (one frame, 574 draws): scene `c2200000` + depth `c25c0000`, lighting `c1e40000`, shadow maps 1408x1408,
composite `c1300000` (the visor `cbfd222185dfe6fc` draws last there), final `c0010000` (`2fa0eae7afb925ef`). Cameras:
the world at A 1.192 (eye in the world), the first-person gun and arms at **A 1.732 with the eye at the origin** (drawn
first, draws 0-10).

## Open

- **Helmet visor** (`cbfd222185dfe6fc`, 1280x720 scene copy at unit 0): a screen-space refraction of the scene with a
  dark vignette, drawn in the game's view only; in the headset it was a red-framed box in the middle of the view.
  Hidden by default (`hidden_draws`). Flat, it also darkens the whole picture, so the headset view is brighter.
  Only the opening mission has it (to check in later missions).
- **The gun may follow the head**: in pose shots it stays at a similar place while the world moves, but the game's
  idle sway makes the shots not comparable. Measure from a frozen frame (both eyes' dumps at two poses).
- 15 scene draws rejected by `require_camera_aspect` (scaled objects of `da77b819` / `d7fbe4bc` with B/A 0.2-2.9):
  they stay on the game camera, so they may slide with the head.
- The orange helmet HUD markings: check they stay in place.
- A normal mission (no helmet) as a second test scene; menus, cutscenes; generator-listed depth-reading passes
  (`2ebaa6edf0af1fbe`, `33817714ee3afbca`, `57673392487219d3`, `7c189ac31f3a74b9`, `cbfd222185dfe6fc`,
  screen passes `034a3670ca7ba800`, `787af60f3cb6ccbc`, `d2417a891fd33a1e`).
