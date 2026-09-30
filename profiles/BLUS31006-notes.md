# Tales of Xillia (BLUS31006, disc 01.00)

Added 2026-09-30. Profile `bin/vr_profiles/BLUS31006.json` (generated in the first field area, Fennmont academy;
frame-rate fields edited). Copy in `rpcs3/vr-non-working/`. Needs the community **60 FPS** patch (Aphelion,
illusion; in `patch.yml`, enabled in Matt's `patch_config.yml`). Desktop only.

## Frame rate (100%)

Native 30. With the community 60 FPS patch the game renders every vblank, but its world advances one 60 Hz tick
per frame, so it is **frame-locked at 60** (the patch notes say to keep Vblank at 60; it slows down below 60).
Headroom is large: at Vblank 180 the field ran at 180 flat and 130-150 in desktop stereo. Profile `max_fps 60`,
`default_fps 60` (the headset reprojects).

**Attempted 90 FPS patch (not working, kept as `evidence/xillia/frame-step-patch-attempt.yml.txt`).** The frame
step is computed at `0x23f114..0x23f134`: `r20 = ticks + 1` (the community patch sets `addi r20, r16, 1`), then
`f13 = float(ticks) * k` stored to the frame-timing object `+0xa4` and `float(ticks)` to `+0xa8`, with `60` (`u32`)
at `+0xa0`. A code cave scaling `f13` by `60 * W` (`W` at bss `0xf11ac8`, meant for `game_frame_time_f32`) applied
and ran, but the timing objects found by signature (`60, dt, 1.0f`) kept `dt` unchanged and walking distances did
not settle (the test corridor turns, so the walk measurements were too noisy to conclude). Next step: a PPU write
watch (`RPCS3_PPU_WATCH`) on the real timing object's `+0xa4` to find where it lives and who reads it, then verify
with a fixed, repeatable walk.

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

## Open

- A real 90 FPS patch (above); until then 60 with reprojection.
- World scale (50 units/m assumed), battles (a separate camera and HUD), menus and skits in the headset.
