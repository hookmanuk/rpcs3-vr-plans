# Metal Gear Solid 4 (BLUS30109, disc 02.00) - findings

Boot launcher `PPU-0d33f5054f70a738799bd5da86d8baa10635f623` (71 KB) spawns `mgs4.mself`, main executable
`PPU-33e09a0bd8fa2a3b28780a3feeb7b0e018bae381` (the hash the community patches use), TOC `0x3ef9c8`.
Evidence: `plans/evidence/mgs4/`.

## Running it

- `LLVM Precompilation: false` in `config_BLUS30109.yml`: with it on, the first boot precompiles every
  overlay in the ~400 MB mself (over 20 minutes). Overlays now compile on demand.
- First boot: "Install all data for all acts?" - No (`Circle`), then `X` to install Act 1 (a few minutes).
- Quick 3D scene: main menu (Start twice) > Virtual Range > Start without saved data > Start.
  Script: `nav_mgs4.sh` pattern in the session notes; ~2.5 min from boot.
- Act 1: New Game > Liquid Easy > the opening video (unskippable the first time, ~5 min) > Act 1 loads >
  Start > Skip on the opening cutscene. No save exists yet.

## Frame rate (2026-09-24)

- The main loop waits in `0xdb720(n)` (mutex + condition variable) until the vblank handler `0xdb7ac` has
  counted `n` vblanks; `n` is loaded at `0xfa33c` from a global interval (2 in Act 1, 1 in Virtual Range).
  The community "Unlock FPS" patch returns from `0xdb720` (no pacing at all).
- Patch `BLUS30109-patch.yml` (installed as `bin/patches/BLUS30109_patch.yml`): `li r3,1` at `0xfa33c`,
  so every frame waits exactly one vblank and the game follows the Vblank Rate.
- Real time: the game-time floats `0x548880`, `0x5488b0`, `0x691b10` advanced 1.00 s per wall second at
  60 FPS (Vblank 60) and 90 FPS (Vblank 90) in Virtual Range, and at 45 FPS in Act 1 (unpatched it is 30).
  No clock-like value ran at 1.5x at 90 Hz. `match_headset_refresh_rate: true`, config Vblank Rate 90.
- Performance here (100%): Virtual Range 90 FPS mono / 60 stereo; Act 1 45 mono / 32-36 stereo.

## VR profile (2026-09-24)

`bin/vr_profiles/BLUS30109.json`, written by hand from the generator's findings
(`generated-in-emulator-BLUS30109.json`) and captures.

- **Anamorphic camera views.** The scene renders into 1024x768 targets and is stretched to 16:9 at the
  end; the projection itself is 16:9 (A 1.8, B 3.2). Every camera-view test compared the target's aspect
  with the output's, so nothing qualified (80 of 19,822 draws on 1280x720). New profile key
  `camera_target_aspect` (here 1.33333); the generator now finds the target size with the most camera
  draws and emits it.
- `row_vectors`. Three camera forms: `c[4..7]` a bare projection with the model-view in `c[8..11]`;
  `c[0..3]` a full view-projection; and camera-relative draws (the terrain, 197,694 vertices) that read
  `c[0]`, `c[1]`, `c[2]` and `c[7]` = `(0, 0, 100, 0)` as the translation row, never `c[3]`. New profile
  syntax: a `camera_blocks` entry can be an explicit slot list, `[0, 1, 2, 7]`.
  Profile: `[4, 0, [0, 1, 2, 7], 32]`. The generator's `bare_projection: true` is wrong here (it would put
  the `c[4]` world draws in the HUD box) and is not set.
- **Depth is reversed with an infinite far plane**: clip z = -w + 103.94, so near is at w = 52 units. The
  generator assumed GL depth, divided by (k + 1) = 0 and reported a near plane of 1.3 million; fixed. Units
  are millimetres: `eye_baseline` 64, convergence 2560 (sep 0.0225).
- No camera position slot. The HUD is drawn on the final 1280x720 target, which is not a camera view.
- Stereo (desktop): Virtual Range far +24 px, Snake +18, HUD 0 (`sbs-virtual-range-stereo.png`); Act 1
  far +26, truck and Snake +18, HUD 0 (`sbs-act1-stereo.png`). Yaw audit coherent
  (`audit-yaw25.png`; the missing left side is the game's own frustum culling).

Open:
- `_sys_lwmutex_lock ... CELL_ESRCH` from MGS4 MAIN about 8-9 minutes into a session (Act 1). Once the
  screen went black afterwards (during memory dumps); on a clean run the game carried on. Not yet checked
  whether it happens without the frame-rate patch.
- Headset run.
