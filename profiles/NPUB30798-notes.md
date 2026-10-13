# NiGHTS into dreams... (NPUB30798, PSN, v01.00)

Started 2026-10-13 (Matt: "make profiles for Nights and Prince of Persia"). Boots from
`bin/dev_hdd0/game/NPUB30798/USRDIR/EBOOT.BIN`. Driving it: `scratchpad tools/nights_boot.sh` (autosave notice X,
Return x4 through the warning, logos and intro, Start at the title, X Brand New Dreams, X Claris/Spring Valley, X x3
through the Nightmaren cutscene); keyboard pad from the template (temporary, `input_configs/NPUB30798`).

## Step 0
- **Frame rate: 30.** Gameplay flips every second vblank (29.5 FPS at Vblank 60); title, menus and movies run at 60.
  No community patch (patch.yml has none). Not yet known whether the logic is frame-locked (a Saturn-era engine, very
  likely). A frame-rate patch is the main work; without it the game cannot reach 72.
- **Savestates fail**: "failed to lock SPU threads execution", also with Compatible Savestate Mode and the GETLLAR spin
  optimization off (both put back to false).
- **Green squares (RPCS3 rendering, flat, no VR):** tree billboards and the yellow orbs draw on opaque green squares.
  Not the texture colour key (`NV4097_SET_COLOR_KEY_COLOR` unimplemented in RPCS3, but control0 is `0x80060000` and the
  key registers are 0 for every texture). The sprite draws (`703c5804`, A8R8G8B8 128x128/64x64, alpha 1 in the
  background, 255 in the content) use alpha test GEQUAL 14 with SRC_ALPHA/ONE_MINUS_SRC_ALPHA blending, which should
  discard the background; the opaque D8R8G8B8 256x128 draws (437 a frame, alpha byte 255) may be the squares instead.
  Not isolated yet (RTDUMP `prog=` needs VR on; next: `hidden_draws` by texture size with the profile). Inspector
  records now carry each texture's control0/remap/filter/colour-key registers and the alpha-test and blend state.

## VR profile (hand-made, `bin/vr_profiles/NPUB30798.json`, untracked)
The generator's profile (`evidence/nights/NPUB30798.generated.json`) is wrong: `column_vectors_xyw c[68]` (indexed
light vectors at `c[60+a0]`, `c[64+a0]` looked like a camera) and projection A 0.0016; in the headset each eye showed a
small, different picture. The real pipeline (vertex program `703c5804df87ba18`): object-to-view rows `c[20..23]`, then a
**bare projection** `c[24..27]` (row vectors: A 1.206, B 2.145 = 16:9, `c[26]` = (0,0,-1,-1), `c[27].z` -0.03), position
`(clip x, y, clip z + clip w * c[32].x, clip w)`. Same scheme as God of War. 2D HUD/menus: program `277204223350d5d7`
with a pixel ortho in `c[68..71]` (row vectors, 2/1280, -2/720). Hand profile: `row_vectors`, `camera_blocks [24]`,
`orthographic_block 68`, `eye_baseline 0.064` (near 0.03: units are probably not metres; to measure).
On the simulator the world renders across the headset view in stereo (`evidence/nights/2026-10-13-sim-handprofile.png`);
yaw moves a paused menu's box with the world and roll tilts the horizon. Not yet checked properly: pitch direction,
world scale, menus (the dream-select screen draws its 3D characters out in the headset view: needs
`screen_frame_draws`), the HUD box.
