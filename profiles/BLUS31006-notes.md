# Tales of Xillia (BLUS31006, disc 01.00)

Added 2026-09-30. Profile `bin/vr_profiles/BLUS31006.json` (generated in the first field area, Fennmont academy;
frame-rate fields edited). Copy in `rpcs3/vr-non-working/`. Needs the community **60 FPS** patch (Aphelion,
illusion; in `patch.yml`, enabled in Matt's `patch_config.yml`). Desktop only.

## Frame rate (100%)

Native 30. With the community 60 FPS patch the game renders every vblank, but its world advances one 60 Hz tick
per frame, so it is **frame-locked at 60** without the fork patch below (the patch notes say to keep Vblank at 60; it slows down below 60).
Headroom is large: at Vblank 180 the field ran at 180 flat and 130-150 in desktop stereo. With the fork patch it follows the headset rate.

**90 FPS patch (2026-10-01): "Frame rate follows VR (use with 60 FPS)"**, `bin/patches/BLUS31006_patch.yml`, on by
default, profile `game_frame_time_f32: ["0xf11ac8"]`, `max_fps 0`, `default_fps 0`.
- Found with the PPU interpreter (`RPCS3_PPU_TRACE=23f130`, new `RPCS3_PPU_TRACE_REGS=r18,f0,f13`) and read/write
  watches (`RPCS3_PPU_WATCH_FILE`): the frame-timing object is a per-channel array at `0xe340b0` (stride 0xc0);
  channel 0 at `0xe34118`. `+0xa8` = ticks (float, 60 Hz units), `+0xa4` = step (ticks x 1.0), both read through
  getters `0x23e0d4` / `0x23e074` thousands of times a frame; `+0x98` counts frames, `+0x88` is time-based.
- The cave at `0x23f12c` multiplies the tick count by `60 * W` before both are stored; `W` (bss `0xf11ac8`) is seeded
  with 1/60 by the patch and set to 1/fps by the profile. The first attempt scaled only the step, not the ticks
  (which most systems read): no effect.
- Verified: walking (player position `0xe78150`, fresh boot, 0.5 s forward then back): 60 FPS 275.1 out / 280.8
  back; 90 FPS with the patch 275.4 / 280.8; 90 FPS without it 393.7 / 394.3 (1.43x). The game-time float
  `0xe3eeb0` runs at 0.99x of its 60 FPS rate. Per-frame u32 counters still run 1.5x (unknown uses). Battles not
  checked. Test scripts: `tools/re/tox_ob.sh`, `outback.py`.

## VR profile (generated)

`row_vectors`, camera `c[0, 47]` (100% of depth-tested draws), HUD `c[0]` with `hud_skips_passes` (the HUD block is
also read by 20 full-screen passes), no camera position. Near plane 5 units: the generator's rule gives 50
units/m (`eye_baseline` 3.2), unverified. Desktop stereo and the yaw-25 audit are clean: the world turns
coherently, the minimap stays in the HUD box.

## Boot

First boot: ~110 PPU modules. The intro can show black for a while at a raised Vblank (it came up on a second try).
First-run Options (Start), opening movie (Start > Skip Movie > Yes), character select (Jude: Left, X), opening
cutscene (Start > Skip Cutscene > Yes), two tutorial screens: `tools/re/tox_boot.ps1` scripts it, with timing that
sometimes needs a hand at character select.

## 2026-10-01: headset view (desktop, `-FakeHmd 100`)

At the first field (academy corridor): minimap and pop-ups boxed, scene follows the head, 90 FPS
(`evidence/xillia/fakehmd100-field-minimap-boxed.png`). Savestate `bin/savestates/BLUS31006/tox_field.SAVESTAT.zst`.
The first battle is well into the story (not reached by scripted input).

## Open

- Battles at 90 (timing), skits.
- World scale (50 units/m assumed), battles (a separate camera and HUD), menus and skits in the headset.

## 2026-10-01: first headset run (Matt, 90 Hz)

- White screen forever (not frozen) after the first Namco splash screen, **only when Start is pressed on that splash
  screen**. Without pressing anything the game boots normally: in the headset, in desktop stereo at Vblank 90 and on
  the OpenXR Simulator at 90 (no `cellVdec ... waiting for a consumer` warnings in the log).
- Open: does pressing Start on the splash also do it flat at 60 (upstream behaviour) or only with VR? Compare logs.
- **In game: performance great, image broken.** HUDs all over the place (some tied to the head, some offscreen);
  screen effects in the wrong place; edge outlines around characters and blur outside those edges. Leads, unverified:
  the HUD uses `c[0]` + `hud_skips_passes` (HUD elements outside that path stay full-view and follow the head or land
  off the HUD box); the outlines and blur look like a screen-space pass (edge detect / DoF / bloom) that samples the
  scene at the flat-screen position instead of the headset view. Desktop stereo and the fixed-pose fake headset
  showed none of this; next step: OpenXR Simulator (Dream Air, 90 Hz) with `pose_sweep_command.json`, in the field.

## 2026-10-01 evening: OpenXR Simulator findings

- **Fixed: boxed scene copies.** `fc3fabcf3cb724b2` (identity blit) copies the 2560x720 double-width scene buffer
  (`0xc0800000`) to the scene target `0xc1ae0000` and to a main-memory buffer `0x31f00000`. That texture is not
  recognised as a render target, so with the identity matrix as the HUD block (`orthographic_block 0`) the copies
  were boxed (probe `why=` showed `box 1`): a smaller copy of the scene blended over the frame, a dark rectangle with
  a ghost of the player on the floor in the headset view. Profile `unboxed_draws` [`fc3fabcf3cb724b2`, 2560x720].
  Likely Matt's "screen effects in the wrong place" and part of the outlines.
- Not the cause: the half-resolution scene re-render (`fc1069a6fd0ec49a` into 640x360, then blurred and blended) is
  classified as a camera draw and transformed like the main pass; the shadow maps (64x64, 128x128) stay as drawn.
- Field minimap: world-fixed in the HUD box (a 25-degree turn moves it as far as the scene, image registration).
  "HUDs all over the place" must be other screens (battles, menus, pop-ups): not reachable from the savestate.

## 2026-10-01 night: menus, and the white screen

- **Menus fixed** (fork 1c082730c): on the Options screen the 2D sprite program `387450c1b505f028` counted as a camera
  draw. Its `c[0..3]` is a pixel ortho, so the second camera block `c[47]` (a stale perspective matrix) matched. In
  the field every draw with a perspective `c[47]` also has one in `c[0]`, which matches first, so `c[47]` was only
  ever matched by menus: `camera_blocks [0]`. The game overwrites rather than clears its composite buffer, so the
  automatic 2D check kept seeing 3D: `frames_without_3d_as_screen: true`. Simulator: Options is a world-fixed screen
  (before: full-view with a grey layer, likely the "white" Matt saw); the field is unchanged (minimap boxed).
- **White screen after Start on the splash: not reproduced.** Start pressed while the Namco splash shows: flat at 60
  and on the simulator at 90 the game continues to the Options screen. Matt's white screen was probably that Options
  screen drawn full-view over the headset (fixed above). Recheck in the headset.

## 2026-10-01 late: walking ripples at the wrong depth

Matt's savestate `vrtest_tox_matt_puddles` (= `BLUS31006_1_1`, Laforte Research Center sewer). The ripple rings and
other effect quads (`387450c1b505f028`, 64x64 / 128x128 textures, 4-vertex quads) are drawn with per-object MVPs in
`c[0..3]` that include the ring's own scale: w-row lengths from 0.05 to 11.6 in one frame (the scene's own draws 1.0),
all with |x row| / |w row| = 1.358 (the projection). With `eye_offset: baseline` the eye offset scales with the ring,
so a ring grown to 11x got 11x the parallax and floated in front of everything. **Fix: `"eye_offset":
"baseline_per_w"`** (offset per unit of w, as Jak 1): every draw with |w| = 1 is unchanged. Not yet seen in the
headset; a few stretched particles (|x|/|w| 0.82-1.47) keep a slightly wrong offset.
Blue floor lights brighter in one eye (Milla's intro): Matt saw it correct on the OpenXR Simulator; he rechecks
in the headset.
- **Verified on the OpenXR Simulator (2026-10-02 05:20):** walking in `vrtest_tox_matt_puddles`, the ripple ring under
  Milla measures R-L -165.6 px, her feet -165.3, the floor on either side -166.1 / -165.9 (`parallax.py` on a
  simulator capture): the ring now lies on the floor.

## 2026-10-04: community 60 FPS bundled (fork 9de7502a)

The community *60 FPS* patch (Aphelion, illusion: two words, `0x710694` and `0x23f114`) is copied into
`BLUS31006_patch.yml` as *60 FPS (VR)*, on by default, so the release needs no community patches; *Frame rate follows
VR* still scales the game's tick. From the extracted zip (no `patch.yml`) both apply.

## Slow motion on slower PCs (users, 2026-10-06), fixed (fork 147ca6fb2)

Reports: smooth in the headset, but gameplay at half speed. The profile wrote 1/(VR rate) into the frame time word
`0xf11ac8` every frame. A PC below the VR rate (the runtime then halves to ASW/SSW, which keeps head tracking smooth)
still told the game 1/120 per frame. Reproduced on the simulator at 120 Hz with Resolution Scale 800% (56 FPS): the
frame-timing object's ticks (`0xe341c0`, summed per second; 60 = real time) were 28/s. Fix: the frame-rate words use
the smoothed time between game flips when it is more than 3% below the VR rate: 60 ticks/s at 56 FPS (told 1/56);
at full rate unchanged (120 FPS, told 1/120, 60 ticks/s). Walking speed (`peekspeed.py`) is too noisy at low frame
rates to judge this; use the tick sum. Workaround for the vr8 build: VR Frame Rate = a rate the PC holds (60: 60 ticks/s,
walking at reference speed).
