# The Darkness (BLUS30035, disc 01.03)

Added 2026-09-30. Profile `bin/vr_profiles/BLUS30035.json` (generated in the opening car scene), copy in
`rpcs3/vr-non-working/`. **Stereo is broken** (below). Community **60 FPS** patch (tronuo, `patch.yml`) targets 01.03,
which is the disc version, and is enabled in Matt's `patch_config.yml`.

## Frame rate

With the 60 FPS patch the opening runs 150-180 FPS flat at Vblank 180, and the f64 game clocks advance 1.0/s at
180 (memory dumps): real-time, so `max_fps 0`. Stereo on the desktop: 75-80.

## Renderer layout

Starbreeze engine: 1024x576 scene targets, composited to 1280x720 in one draw. Depth pre-pass (`6e7c3c2a`,
colour off), then most material and light passes with **depth EQUAL**. Positions are camera-relative:
`r = pos * c[scale] + c[offset] + c[7]`, clip = DP4 rows `c[0..3]` (object rotation folded into them, so `c[0..3]`
differs per object). Skinned programs index the bank. Program `6ae71959` draws scaled unit boxes with colour off,
some with depth write and some without (probably stencil shadow volumes or occlusion boxes); hiding it in flat
changes nothing visible.

## Profile (generated)

`column_vectors`, camera `c[0]` (100% of depth-tested draws), `camera_slots_read_directly`, HUD `c[31]`,
`bare_projection`, near 0.9 -> metres.

## Stereo problem (open)

With stereo on, both eyes show red light leaking over surfaces and, after keeping `6ae71959` on the game camera,
a dark band and missing lighting on the car door (`evidence/darkness/`). Separation 0 is clean, so the shear
itself breaks the lighting. The flat-route probe (`stereo=0.0134,conv=2.56`, a single sheared view, no right eye)
blows the lighting out completely, so it is not a right-eye surface problem. Tried without success: LEQUAL
instead of EQUAL for sheared passes (no change; the code was removed), adding `c[29]` (the light matrices) as a
camera block (worse). New generic knobs from this work: profile `game_camera_programs` and probe `gamecam=`.

Next: find the pass whose output changes with the shear in a static scene (the opening car ride is scripted and
animated, which made A/B metrics unreliable): get to a stationary point in the first level, then bisect with
`gamecam=` and read the light passes' fragment shaders (they may reconstruct position from `gl_FragCoord` with a
fragment constant that the shear does not update).

## 2026-10-01 (headset view on the desktop, `-FakeHmd 100`)

- Draw 1 (`efdffb82a28ba329`, a screen-filling background quad with a bare projection) was rotated away by the head
  transform and left the edges unwritten: `game_camera_programs: ["efdffb82a28ba329"]`.
- The final composite (1024x576 scene into the 1280x720 display buffer) and the post passes are bare-projection quads
  drawn with the generic vertex program `7053e6a262fcd712`; `bare_projection` put them into the HUD box (the whole
  scene in a small box). Fork change: with `hud_skips_passes` (now in the profile) a bare-projection draw that samples
  a colour target is a pass and stays as drawn. The composite now fills the view and the HUD text is boxed.
- **Still broken:** with the head transform the shading passes are almost black (only rim light), flat is lit
  (`evidence/darkness/fakehmd-composite-unboxed-dark.png` vs `flat-same-moment-2.png`). `7053e6a262fcd712` is used
  by most draws (shadow volumes, world, post, composite), so per-ucode `gamecam`/`hide` tests are too coarse here
  (keeping it on the game camera just disables VR). Next: a probe filter by storage hash or by target + depth state
  to isolate the stencil shadow volumes (z-only `6ae71959` storage variant), then compare stencil per eye with RTDUMP
  (depth-stencil dumps work, `prog=` trigger). The opening car scene sits still at the "View tutorial help" prompt,
  which makes a good static test frame.

## Boot

`tools/re/dk_boot.ps1`: intro video (X), autosave notice (X), New Game, Medium, then the opening car scene.
