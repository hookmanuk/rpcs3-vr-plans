# Dragon's Dogma: Dark Arisen (BLUS31155, v01.02)

Added 2026-09-30. Profile `bin/vr_profiles/BLUS31155.json` (generated, then frame-rate and world-scale fields
edited). Fork patch file `bin/patches/BLUS31155_patch.yml` (full-screen view). Copies in `rpcs3/vr-non-working/`.
Desktop only: stereo, yaw and pitch audits in the prologue dungeon. Not played in the headset.

## Version

Needs the **01.02 update** (Matt installed it): the community *Unlock FPS* patch (FlexBy, in `patch.yml`) and the
fork's full-screen patch both target the 01.02 executable (`PPU-ec112cfa...`). The disc is 01.00.

## Frame rate (9800X3D + RTX 5090, 100%)

| | FPS | limit |
|---|---|---|
| flat, vblank 90, Unlock FPS | 90 (prologue) | main PPU thread ~96% |
| flat, vblank 180 | 120-135 | RSX thread ~100% |
| stereo desktop, vblank 90 | 88.7-89.9 | RSX thread ~91%, main PPU ~96% |

The game is **real-time** with Unlock FPS: at ~130 FPS uncapped (vblank 180), clocks in four memory dumps advance
1.0/s (`tools/re/memclock.py`; f64 clocks at 0x318b80a8 etc.). So `max_fps 0`, `default_fps 0` (headset rate).
Only the prologue dungeon was measured. The open world (Cassardis, Gran Soren) is known to be much heavier on
RPCS3 and is the frame-rate risk.

## Letterbox (patch "Full screen (no letterbox)")

The PS3 version draws its 3D view letterboxed: viewport 1280x608 at y = 56 inside 1280x720, camera aspect 2.105.
The generator then found no camera (projection B/A 2.10, not 16:9), and in a headset the bars would crop the view.
The factor is height/width = 0.475 (`0x3ef33333`):

- the renderer object `[0x1a7e254]` keeps it at `+0xd10`, flag at `+0xd15` (letterbox on);
- the setters at `0x3d5a0` and `0x3d6d0` pick from two tables `{0.475, 0.5625}` at `0x3d598` and `0x3d5f0`;
- the init at `0x3dae8` stores 0.475 directly;
- rodata `0x139a9d4` (next to `sCamera`) is read by `0x305590`, `0x44b1c8`, `0x528ef4` (camera aspect).

The patch sets all five to 0.5625. Result: viewport 1280x720, B/A 1.777, HUD and menus unchanged. Live PINE writes
to `+0xd10` do nothing: the viewport is built from it when the view is set up. Cutscenes are now full-screen too.

## VR profile

Generated in the prologue after the patch: `row_vectors`, camera `c[255, 3, 0, 258, 19]`, `require_rigid_camera`,
`nonrigid_camera_blocks [255, 3]`, `require_camera_aspect`, `camera_slots_read_directly`, HUD `c[266]`, no camera
position. 96% of depth-tested draws covered. Layout (from the shaders):

- static meshes: object 3x4 in `c[0..2]`, view-projection rows `c[3..6]`;
- skinned meshes (indexed bone palettes from `c[0]`): view-projection at `c[255..258]` or `c[258..261]` depending
  on the program (overlapping bases, hence `require_camera_aspect`);
- effects `8c80091b`, `5ae0ec1a`, `e379bc76`: camera `c[0..3]`.

**World scale:** near plane 8 units, so the generator's rule gave 80 units/m (`eye_baseline` 5.12). An NPC 385 units
away measures ~67 units head-to-chest and ~39 units across the torso: centimetres fit better, so `eye_baseline` 6.4
(stereo separation scaled to match). Least certain value: check in the headset (World Scale).

## Renderer bugs found and fixed (fork, 2026-09-30)

1. **Bone matrices matched as a camera block.** Skinned programs index their constants, so the renderer gets the
   whole bank and found bone matrices at `c[3]` perspective-looking. New profile flag `camera_slots_read_directly`:
   in such programs a camera block counts only if the program reads its slots directly (as the generator samples
   them). The generator writes it whenever it sampled indexed programs.
2. **Right eye black where static meshes shifted (generic).** Before its light volumes the game clears only the
   stencil. The clear mirroring copied the whole depth-stencil image from the left eye, so the right eye's depth was
   replaced by the left eye's, and the right-eye material pass (depth LEQUAL) was rejected wherever the shifted
   geometry was behind the unshifted depth. The mirror now copies only the aspects the clear wrote. Found with the
   new RTDUMP `prog=` trigger and depth dumps: right depth correct before `be7faa4f`, equal to the left after it.
   Every game that clears depth or stencil alone benefits.

Evidence: `evidence/ddda/` (flat letterboxed and patched, right eye before/after the fix, yaw 25 and pitch 35
audits, one inspector capture).

## Open

- Open-world frame rate (the prologue is a small dungeon).
- NPC name tags are screen-space HUD: in the headset they stay in the HUD box instead of over the NPC.
- Open world still unmeasured: the only save is at the prologue start (prologue, Hydra, character creation, then
  Cassardis); not reached by scripted input in this session.
- World scale (cm assumption) and the HUD box, in the headset.
- 14 uncovered programs in the generator log are full-screen passes and the HUD text (`92f9a341`); not individually
  checked in other scenes.

## 2026-10-01: headset view (desktop, `-FakeHmd 100`)

- The HUD was not boxed: the HUD text and bars (`38bca07d9ce9033e`) take an object transform in `c[0..3]` and a
  packed ortho in `c[4]` (scale x/y, offset x/y), so neither the ortho-block path nor the matrix-less test finds
  them, and they draw into the scene's own 1280x720 target. The minimap (`a6629f97bf957a04`) is drawn into a
  256x256 target, then into the scene target sampling it. Profile: `passthrough_hud` with `hud_programs`
  [both] (the after-shader box). Fork: the passthrough HUD now accepts draws sampling a small render target
  (not view-shaped). Result: HUD, bars and minimap boxed (`evidence/ddda/fakehmd100-hud-boxed.png`), 86-88 FPS.
- The fake headset never recorded camera targets, so the passthrough HUD could not be tested with it; it does now
  (only the target list, not the headset's pose stamping: running the full pose bookkeeping with the fake headset
  dropped Dragon's Dogma to 6 FPS and Anarchy Reigns to 60, cause not found). **Risk:** check Dragon's Dogma's
  frame rate in a real headset session.
- Dev probe `why=<vertex hash>` logs each distinct VR classification of that program's draws (camera, HUD,
  passthrough, texture kinds, target, in-scene).
- Savestate `bin/savestates/BLUS31155/dd_prologue.SAVESTAT.zst` (prologue, start).

## Driving it unattended

Keyboard pad from `tools/keyboard-pad-template.yml` into `input_configs/BLUS31155/` (deleted after the session).
`tools/re/dd_boot.ps1 [-Probe render=1] [-Audit 25]` boots and presses Start plus X five times (autosave notice,
offline notice, Main Menu, Load Game, save); scripted X presses during loads are dropped, so check with a
screenshot and press X again if it stopped at a menu. The first boot compiles PPU modules for ~2 minutes.

## Frame rate at 72 Hz, 4K per eye (2026-10-01)

- Stereo at 300% held ~68-69 FPS (`vrtest_ddda_prologue`): the RSX thread used 13.9-14.4 ms of CPU per frame
  (cycle-exact; flat 8.0). `RPCS3_RSX_SAMPLE`: **41% of it waited in `ZCULL_control::sync` ->
  `get_occlusion_query_result`**: the game writes labels that flush the pipe while occlusion queries are pending,
  and RPCS3 waits for each query's exact count (ZCULL Accuracy "Precise", the default). In stereo each wait covers
  both eyes' GPU work.
- Relaxed ZCULL Sync: 13.3 ms, 70 FPS (little help). ZCULL Accuracy "Approximate" (`Accurate ZCULL stats: false`):
  7.95 ms, 72.0 FPS, 0% late. Still images in the prologue look the same (lantern glow; the NPC moves between the
  shots).
- New profile key **`zcull_approximate: true`** (fork): Approximate reports only while VR renders (flat play and the
  user's setting untouched). With it: **72.0 FPS, 0% late, RSX thread 7.80 ms** (`evidence/vrperf/`).
- Not checked: outdoors (sun/lens flares could scale with the visible pixel count; with Approximate any visible
  pixel counts as fully visible).
