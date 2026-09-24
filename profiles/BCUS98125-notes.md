# inFamous 2 (BCUS98125, disc 02.00 / APP_VER 01.00) - findings

PPU hash `PPU-ad7bfe5eb63563703c893ab10930c35cf80e8d0e`. Evidence: `plans/evidence/infamous2/`.

## Running it

- Same PKGDIR prompt as inFamous: `dev_hdd0/game/.locks/BCUS98125`.
- Boot to the main menu (~40 s), `X` = Start a New Game, ~2.5 min of intro (comic, cutscene), then the
  right-stick look tutorial (up, left, right...), then free roam on the pier.

## Frame rate (2026-09-24)

No patch needed: not vsync-locked (60 at Vblank 60; 52-72 FPS in stereo at Vblank 90 here) and real-time.
Static game-time float `0x00a083e4` (inFamous 1's is `0x008eb2c4`) advanced 1.0 s per wall second while the
stereo game ran at 28-43 FPS. `match_headset_refresh_rate: true`, `config_BCUS98125.yml` Vblank Rate 90.

## VR profile (2026-09-24)

`bin/vr_profiles/BCUS98125.json`, generated in-emulator (after the generator changes below), plus
`rotation_only_passthrough` by hand. Earlier generator outputs: `generated-v1/v2-BCUS98125.json`.

- `row_vectors`, camera at a varying base after 0-10 object-matrix slots: `[256, 262, 259, 263, 266, 261,
  260, 264]` with `require_rigid_camera` and `require_camera_aspect`. Coverage in the generator went from
  22148 of 36673 camera-view draws (non-overlapping blocks only) to 35114 of 38684. Simulated on a capture:
  0 mismatches against a test of every base.
- Camera position `c[467]`. Near plane 0.116 -> `eye_baseline` 0.074 (units ~ metres). HUD `c[256]`.
- **Camera-relative world + a view-ray composite.** Much of the world is drawn camera-relative, with a
  camera block that has no translation at all. The final full-screen composite (a 3-vertex triangle, depth
  test off) uses the same kind of block to build view rays. The eye shear shifted those rays and smeared the
  right eye's left edge and anything bright. New profile key `screen_space.rotation_only_passthrough`: a
  translation-free camera block on a draw **without depth test** follows head rotation but takes no eye
  offset, head translation or shear. (Matching on the block alone would have caught the camera-relative
  world draws too - 9,000+ vertices per program.)
- **Partial clears are now mirrored** to the right eye (the cleared rectangle of the cleared attachments;
  the full-clear mirror used to copy every attachment, cleared or not). Fixed the right eye's smearing
  when Cole was in the water.
- The game copies two 1280x720 targets to main memory each frame (1024+256-column blits,
  `0xc0010000 -> 0x37777b80`, `0xc0e3c000 -> 0x373f3b80`) for the SPUs, which write results back there
  and the frame samples them (draws ~1904+). The right eye therefore gets the left eye's SPU result. A
  right-eye substitution of the raw staged copy was tried and was wrong (the SPUs rewrite the data; the
  raw copy looks like a normal buffer: magenta/green). In the headset both eyes are rotated alike, so the
  left eye's SPU layer is off only by stereo parallax in the right eye; the 25-degree audit exaggerates it
  into a ghost (`audit-yaw25.png`).
- Stereo on the desktop (`sbs-pier-stereo.png`): far +22-24 px, Cole at the convergence depth 0 px.

Open: the SPU layer (above); headset run.
