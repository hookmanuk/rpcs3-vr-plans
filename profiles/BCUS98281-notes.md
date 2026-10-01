# Jak and Daxter Collection (BCUS98281, disc 01.00)

Added 2026-10-01. Three games under one title ID, launched from a menu (`EBOOT.BIN`) by exitspawn into `Jak1.self`,
`Jak2.self`, `Jak3.self`. Profiles: base `bin/vr_profiles/BCUS98281.json` (so OpenXR is prepared before the switch,
as for God of War Collection) plus `BCUS98281.jak1.json` and `BCUS98281.jak2.json`; copies in `rpcs3/vr-non-working/`.
Savestates: `BCUS98281_1_0` (Jak 1, Samos' hut after the intro), `BCUS98281_1_1` (Jak II, the prison/escape area).

## Jak and Daxter: The Precursor Legacy (Jak1.self)

- 60 native; **170-180 flat** at Vblank 180 (Samos' hut / Sandover). **Real-time:** float clocks 1.00x, and object
  displacements for the same 0.7 s input match at 60 and 180 (no 3x cluster). No patch; `max_fps 0`.
- Profile (generated): `column_vectors c[0]`, 100% of depth-tested draws, `camera_target_aspect 1.42222` (the scene
  renders into 1024x720), no HUD block, metres.
- Yaw-25 audit: outdoors coherent. In Samos' hut, blended sparkles (`71e17d7f15754935`, 40-vertex draws) showed as
  black pentagons fixed on screen in the rotated eye: to fix.

## Jak II (Jak2.self)

- 60 native; **~130 flat** at Vblank 180 in the prison area. Real-time (same displacement test: no 3x cluster).
- Profile (generated): `column_vectors c[0]`, 100% coverage, `camera_target_aspect 1.42222`, HUD `c[0]` +
  `hud_skips_passes`, near 8 units -> 80 units/m (`eye_baseline` 5.12, unchecked). Yaw-25 audit coherent.

## Jak 3

Not started.

## Open

- Jak 1 sparkle particles in the rotated eye; HUD check in both; Jak 3; stereo frame rates on the headset path.
- The launcher's attract scenes are 3D (30 FPS) with the base profile = Jak 1's.
