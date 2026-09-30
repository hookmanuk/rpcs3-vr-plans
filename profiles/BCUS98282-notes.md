# Ratchet & Clank Collection (BCUS98282, disc 01.00)

Added 2026-09-30. Profile `bin/vr_profiles/BCUS98282.json` (generated in Ratchet & Clank 1 on Veldin; frame-rate
fields edited). Copy in `rpcs3/vr-non-working/`. No patch. Only **Ratchet & Clank 1** was tried; R&C 2 (Going
Commando) and 3 (Up Your Arsenal) share the title ID and the profile but were not booted.

## Boot

The first boot asks (RPCS3 dialog) whether to install the disc's Digital Manual package: skip it (Escape). ~370 PPU
modules compile (~3 min). Logos, then the collection menu (R&C 1 selected: X), the R&C 1 title (Start), New Game,
a save slot, and three skippable opening cutscenes (Start) reach Veldin. `tools/re/rc_boot.ps1` does all of it.

## Frame rate (100%)

| | FPS |
|---|---|
| flat, vblank 60 | 60 |
| flat, vblank 90 | 90 (Veldin; RSX thread ~61%) |
| stereo desktop, vblank 90 | 75-80 (4,600 draws a frame, 10 right-eye batches) |

**Frame-locked.** At vblank 90 the integer frame counters run 1.5x (57 -> 86 per second) and Ratchet walks 17.9
units in a 2 s hold instead of 12.3 at 60: the game runs 1.5x fast. Four f32 1/60 constants in data
(`0x770304`, `0x770314`, `0x112c078`, `0x112c080`) set to 1/90 with `RPCS3_VR_POKE` brought the walk to 12.9 units
(real time), but other motion was not verified (a standing-still comparison was inconclusive). So the profile runs
the game at its native **60** (`max_fps 60`, `default_fps 60`) and the headset reprojects. A 90 FPS patch is the
lead for later: start from those four constants and check animation, enemies and timers.

## VR profile (generated)

`column_vectors`, camera `c[0]` (100% of depth-tested draws), HUD `c[4]`, near plane 0.1 -> metres, `eye_baseline`
0.064. Stereo and the yaw-25 audit on the title and in gameplay are clean.

## Open

- **Pause menu:** its button frames are 3D panels drawn with their own perspective camera (`ef49d731f4b4551b`,
  `d032c3b0051293db`; `c[0..3]`, clip w = x - 256) over a still of the scene. They pass as camera draws and turn with
  the head while the text stays in the HUD box (`evidence/ratchet/pause-menu-audit-yaw25.png`). Needs a way to put a
  program's camera draws into the HUD box (the GT5 mechanisms need `hud_box_after_shader`).
- R&C 2 and 3: boot each and check the profile (same engine family, may differ).
- 90 FPS patch (above); headset run.
