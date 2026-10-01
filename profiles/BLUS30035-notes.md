# The Darkness (BLUS30035, disc 01.03)

Added 2026-09-30. Profile `bin/vr_profiles/BLUS30035.json` (generated in the opening car scene), copy in
`rpcs3/vr-non-working/`. Desktop stereo fixed 2026-10-01; headset view still dark (below). Community **60 FPS** patch (tronuo, `patch.yml`) targets 01.03,
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
- Probe `gamecam=<hash>@nocolor` (new) keeps only that program's colour-less draws on the game camera: the stencil
  volumes alone on the game camera do not fix it. Pipeline at the test frame (capture `f14700`): z pre-pass with
  `83cbe322b3b9c82a` (no colour target), stencil volumes (`7053e6a262fcd712`, colour off), light passes with depth
  EQUAL (`7167d3a00432a346`, `3d4018ba3c70c07c`, blend), unlit/emissive LEQUAL passes, then post quads and the
  composite. RTDUMP before the first light pass: the pre-pass depth is complete in the headset view and the stencil
  holds shadow counts 0-9 (`evidence/darkness/depth-before-light-pass-fakehmd-vs-flat.png`). Next: dump depth +
  stencil right before and after one light pass in both modes and check whether its EQUAL test or its stencil test
  rejects (e.g. make a probe option that forces the light passes to depth LEQUAL / stencil ALWAYS to see which).
- **Found:** new probe switches `dev=0x100` (depth EQUAL -> LEQUAL for colour draws) and `dev=0x200` (no stencil
  test for colour draws). LEQUAL changes nothing; without the stencil test the light comes back (no shadows):
  `evidence/darkness/fakehmd-lequal-nostencil-both.png`. So with the head transform the stencil shadow volumes
  mark everything as shadowed, and the lit result is also speckled (a second fault, maybe a screen-position lookup
  in the light pass). Next: dump stencil after the volumes for one light in flat vs headset view; check whether the
  volumes are drawn with depth clamp / an infinite far plane that the headset projection breaks.

## 2026-10-01: desktop stereo fixed (fork 25ccbbe91)

- The lighting was never the problem: RTDUMP of the light buffer (RGBA16F, newly supported) right after the last
  light (`prog=7053e6a262fcd712#117`) is the same with separation 0.0134 and 0. The red came from the post chain
  (bisected with the new `prog=<hash>#n` trigger): draws 877/878 build the colour-grading LUT (324x18) in a corner
  of the 1024x576 scene buffer with bare-projection quads (depth func ALWAYS, ordinary textures), 879 tone-maps
  through it, and the HDR luminance passes read 324x18 targets. In desktop stereo the bare-projection rules only
  ran in the headset path, so these quads were sheared: LUT slices written a few texels off, exposure wrong.
- Fork: a bare-projection quad that samples any colour render target, or (desktop) has no depth test that can
  reject, or draws through a viewport much smaller than its target, is a pass and is left as drawn; with
  `hud_display_buffers_only` a depth-less bare projection outside a display buffer is a pass in the headset path.
  Today's earlier change (only view-shaped targets make a HUD draw a pass) had also made the luminance passes look
  like HUD; the bare-projection test now uses "any colour target".
- Result: desktop stereo matches flat, 90 FPS (`evidence/darkness/stereo-desktop-fixed-2026-10-01.png`).
- **Headset view still almost black** (`-FakeHmd 100`). `camera_scissor_full` (new profile key, probe `dev=0x400`:
  camera draws scissor to the viewport, scissored stencil-only clears widened) changes nothing. Lead being tested:
  the headset eye offset is `baseline/2 x |clip-x row|`, and the object scale folded into `c[0..3]` (scaled shadow
  volumes) makes it differ per object; `|x row| / |w row|` (the projection scale) is scale-independent.
- Savestate `bin/savestates/BLUS30035/dk_tutorial.SAVESTAT.zst` (static frame at "View tutorial help").

## Boot

`tools/re/dk_boot.ps1`: intro video (X), autosave notice (X), New Game, Medium, then the opening car scene.
