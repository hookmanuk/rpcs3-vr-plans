# RPCS3 VR fork - next steps

Work through these in order. Do not start the RSX inspector until Gate 1 is complete.

## Gate 1 - prove our build and edit loop

- [x] Confirm the existing MSVC x64 toolchain, CMake, Python, and the RPCS3 submodules are available.
- [x] Attempt the documented `msvc` CMake configuration.
- [x] Install the supported Qt 6.11.2 MSVC 2022 package, including Multimedia and SVG modules.
- [x] Install the supported Vulkan SDK 1.4.341.1 and validate its headers and import library.
- [x] Configure a clean Vulkan-enabled build; disable OpenAL's optional C++20 modules and its accidental SDL package lookup.
- [x] Install Visual Studio 2026 with Desktop development with C++, x64/x86 MSVC tools, a Windows 11 SDK, and C++ CMake tools for Windows.
- [x] Restore packages/dependencies and build the `Release|x64` target from `rpcs3.sln` with Visual Studio 2026 (the preferred and CI-matching route).
- [x] Launch `rpcs3/bin/rpcs3.exe` and confirm Vulkan is available as a renderer.
- [x] Make one harmless, unmistakable source change: append `[VR DEV]` to the main-window title in `rpcs3/rpcs3/rpcs3qt/main_window.cpp`.
- [x] Rebuild the RPCS3 application project, launch the newly built executable, and visibly confirm `[VR DEV]` is present.
- [x] Record the RPCS3 commit, build command, executable path, and build date here.

Gate 1 result (2026-09-21): complete. Visual Studio Community 2026 Insiders 18.11,
MSVC 14.51, Qt 6.11.2 and Vulkan SDK 1.4.341.1 built the full `Release|x64` solution
successfully at RPCS3 commit `9e86f165d1711b9429d48b0487e7bc5ba0cc9c6c`.
The marked incremental build compiled `main_window.cpp`, relinked the application in
24 seconds, and launched with the title `RPCS3 0.0.42-20024-9e86f165 Alpha | master |
local_build [VR DEV]`. Its Vulkan configuration was created with `Renderer: Vulkan`.

Output: `F:\rpsc3\source\rpcs3\bin\rpcs3.exe`

Marked build time: `2026-09-21 11:05:32`

Marked executable SHA-256:
`A3A29B8C0519E24E5C1A43C1DBEE3CD6F95B0A817820C4AF8C789BC3CA776E4E`

After the one-time solution build, use the targeted application-project command in
`1-structure.md` for normal source edits. Do not rebuild the whole solution when only
RPCS3 application files have changed.

## Gate 2 - establish WipEout baselines

- [x] Run BCES00664 v2.51 in ordinary 2D mode with the new build and confirm the expected 60-fps route.
- [x] Record the exact RPCS3 game configuration, renderer, resolution scale, patches, and performance.
- [x] From the same save/scene, run native PS3 3D and record the known-good 30-fps stereo output.
- [x] Save matching 2D, left-eye, and right-eye screenshots/captures for comparison.

Gate 2 result (2026-09-21): complete. Both baselines were captured with the Gate 1
executable (`rpcs3/bin/rpcs3.exe`, commit `9e86f165`, `[VR DEV]` title marker). No
source was changed for this gate.

### Game build - v2.51 is a hard prerequisite for native 3D

*Correction (2026-09-27, Matt): WipEout does not need the 2.51 update; the claim below is historical.*

The disc ISO alone boots as `APP_VER=02.00`, and **that version contains no
stereoscopic code at all**. At 2.00 the game only ever calls
`cellVideoOutGetResolutionAvailability(resolutionId=0x2)` (plain 720p); it never
queries a 3D frame-packing mode, so no amount of emulator configuration will
produce the in-game 3D prompt.

The four update packages were installed in order (2.10, 2.30, 2.50, 2.51) via
`rpcs3.exe --installpkg "<dir>"`, producing `dev_hdd0/game/BCES00664` with
`APP_VER=02.51`. Only then does the game offer 3D.

```text
Disc:    F:\rpsc3\games\<WipEout HD Fury disc>.iso
Updates: F:\rpsc3\games\updates\WipEout® HD\  (v02.10, v02.30, v02.50, v02.51)
Booted:  Title 'WipEout® HD', APP_VER=02.51, VERSION=01.00
```

### Deterministic scene anchor (identical for both runs)

Racebox -> Speed Lap -> Venom -> Weapons OFF -> AI None -> Vineta K (forward)
-> FEISAR -> stationary on the start line at `0 KM/H`. Speed Lap has no AI ships
and no weapons, so the scene is reproducible from the menu path alone with no
save state.

### Configuration

Both runs used Vulkan on an NVIDIA RTX 5090 (driver 596.49), `Resolution: 1280x720`,
`Resolution Scale: 100`, `Frame limit: Auto`, `VSync Mode: Disabled`,
`Write Color Buffers: false`, `Shader Mode: Async Recompiler with Shader Interpreter`,
firmware 4.93, default keyboard pad. **No patches were applied** - `rpcs3/bin/patches/`
is empty and no per-title `patch.yml` exists.

The two runs differ in exactly two settings:

| Setting | 2D baseline | Native 3D |
|---|---|---|
| `3D Display Enabled` | `false` | `true` |
| `3D Display Mode` | `Disabled` | `Side-by-Side` |

The 2D run used the global `config/config.yml`; the 3D run used a per-game
`config/custom_configs/config_BCES00664.yml`. Both files are archived under
`plans/evidence/gate2/`.

### Measured performance

- **2D route: 60 fps.** Stationary on the grid 59.97-60.03; under throttle over a
  ~10 s sample 59.95-60.05, with a single 57.71 dip attributable to a first-run
  shader compile.
- **Native 3D route: 30 fps.** 29.92-30.08 across all samples, stationary on the
  same grid.

Native 3D is confirmed at the emulator level, not merely visually:

```text
cellSysutil: cellVideoOutGetResolutionAvailability(videoOut=0, resolutionId=0x81, ...)
cellSysutil: Selected video configuration: resolutionId=0x81, aspect=0x0=>0x2, format=0x0
```

`0x81` is `CELL_VIDEO_OUT_RESOLUTION_720_3D_FRAME_PACKING` - the 1280x1470
frame-packed mode (720 + 30-line spacer + 720). The game itself prompts
"3D display detected, Switch to 3D mode?" at startup; answering Cross/Yes is what
switches it onto the 30-fps stereo route.

### Evidence

```text
plans/evidence/gate2/
  claude-2d-vinetak-grid-60fps.png            2D, stationary on grid (1280x720, F12)
  claude-2d-vinetak-motion-60fps.png          2D, under throttle (1280x720, F12)
  claude-3d-vinetak-grid-sbs.png              native 3D, both eyes side-by-side
  claude-3d-vinetak-grid-left.png             left eye  (1280x720)
  claude-3d-vinetak-grid-right.png            right eye (1280x720)
  claude-3d-vinetak-grid-framebuffer-eye0.png native 3D F12 capture (1280x720)
  claude-gate2-config-global-2d.yml           exact 2D configuration
  claude-gate2-config-BCES00664-3d.yml        exact 3D configuration
```

### Carry-forward finding for Gate 3

RPCS3's F12 screenshot is **not** a stereo capture. In `VKGSRender::flip()` the
screenshot copy is taken from `image_to_flip` at
`rpcs3/rpcs3/Emu/RSX/VK/VKPresent.cpp:705`, which is the eye-0 source *before*
`video_out_calibration_pass` composes the two eyes. The stereo F12 capture is
1280x720, confirming it holds one eye only. The right eye therefore has to come
from the composed side-by-side presentation (captured here from the game window and
split at the exact midpoint), or from a future inspector hook. Do not assume an F12
PNG taken in 3D mode contains both views.

## Gate 3 - build the RSX Stereo Inspector

- [x] Add a default-off, one-frame capture trigger.
- [x] Capture draw order, vertex-program identity, original RSX transform constants, render-target identity, and render state.
- [x] Capture the same deterministic scene in native 3D and 2D/60-fps modes.
- [x] Pair native left/right draws and map the surviving program/pass families back to the 2D route.

Gate 3 result (2026-09-21): complete. The inspector found WipEout's camera, and it
is present on the 2D/60-fps route.

### The instrument

`rpcs3/rpcs3/Emu/RSX/Capture/rsx_stereo_inspector.{h,cpp}`, plus three hooks:

| Hook | Location | Purpose |
|---|---|---|
| `on_frame_end()` | `RSXThread.cpp`, `rsx::thread::on_frame_end()` | finalize, then arm one frame |
| `begin_draw_clause()` | `VKDraw.cpp`, `VKGSRender::end()` | assign the logical RSX draw ordinal |
| `record_draw()` | `VKDraw.cpp`, `VKGSRender::emit_geometry()` | emit the record before `vkCmdDraw*` |

Default-off: without `RPCS3_STEREO_INSPECT` the hooks cost one bool load and write
nothing. Enable by setting that variable to an output directory; arm exactly one
frame by creating a file named `ARM` in it, which the inspector consumes at the
next frame boundary. Guest state is never modified.

The record is emitted from `emit_geometry()` *after* vertex upload and *before* the
Vulkan draw, because that is the only point where program, constants, framebuffer
layout and subdraw state all describe the draw that is about to execute. Hooking
`upload_transform_constants()` instead would miss every draw that reuses an
unchanged constant allocation. Constants are read from the pristine
`method_registers.transform_constants` bank by ORIGINAL guest index, not from the
compacted host buffer, and are stored as raw `u32` bits alongside decoded floats.

Build note: this adds a file to `emucore.vcxproj`, so `emucore` and `VKGSRender`
must be rebuilt before the app project. A full solution build is still unnecessary.

### Captures

Same Gate 2 scene anchor (Speed Lap / Vineta K / FEISAR / stationary on the line):

| | draws | subdraws | unique vertex programs |
|---|---|---|---|
| 2D @ 60 fps | 827 | 827 | 49 |
| Native 3D @ 30 fps | 1667 | 1667 | 50 |

1667 ≈ 2 × 827. The native-3D frame renders the whole scene **twice, sequentially**,
reusing the *same* offscreen targets, then composites each pass into the
frame-packed 1280x1470 display buffer. That answers two open questions from
`3-investigation.md` §11: eye passes are whole-scene sequential (not interleaved),
and render-target address alone cannot label an eye - provenance comes from draw
order. 49 of the 50 vertex programs are shared with the 2D route; the single
3D-only program is the frame-pack composite.

### Result: the camera is c[465] and the clip-X column of c[256..259]

`tools/pair_eyes.py` aligns the two eye passes and diffs constants by original RSX
index. Alignment deliberately ignores vertex counts, because view-dependent culling
legitimately changes them per eye; 787 of 833 draws (94.5%) paired.

**`c[465]` is the camera world position.** It differs on 682 of 699 paired draws
(97.6%) across 40 different vertex programs, and takes exactly **one** left/right
value pair across all of them - shared per-eye state, not per-object data. `w` is
exactly 1.0, so it is a point, not a direction:

```text
left   [+47.162544, +39.925369, -96.552742, +1.0]
right  [+47.164234, +39.924870, -96.792740, +1.0]
delta  [ +0.001690,  -0.000500,  -0.239998,  0.0]   magnitude 0.240004
```

That offset is the interocular separation, and it points along the camera's right
axis: the normalised delta dotted against **column 0** of the `c[256..258]` 3x3
block gives **+0.99913** (rows give +0.939 / +0.119 / -0.000). So `c[256..259]` is
a column-major world-view-projection matrix whose column 0 produces clip-space X.

Between eyes, `c[256..259]` changes in **component [0] only** - the clip-X column -
with `c[259][0]` (its translation term) shifting by +4.135. A pure horizontal
frustum shift, which is exactly what stereo is. The 3x3 basis and all other
components are untouched.

`c[466]` is effectively eye-invariant (0.3%) and `c[467]` varies per object
(141 distinct value pairs), so neither is camera state.

### Mapping back to the 2D/60-fps route

This is the part that matters for the product target:

```text
c[465]      read by 739 of 827 draws on the 2D route   -> injection seam exists
c[256..259] read by 809 of 827 draws on the 2D route   -> injection seam exists
c[260..263] read by 273 of 827 draws on the 2D route   -> secondary matrix block
```

The camera representation is therefore **not** confined to the 30-fps native path.
The same program families and the same guest constant slots carry it on the
ordinary 60-fps route, which is where Gate 5 must inject eye-specific transforms.

### Evidence

```text
plans/evidence/gate3/
  capture-2d-vinetak-grid.jsonl      2D one-frame capture (827 draws)
  capture-3d-vinetak-grid.jsonl      native 3D one-frame capture (1667 draws)
  analysis-eye-pairing.txt           pair_eyes.py report
  config-BCES00664-3d-capture.yml    config used for the 3D capture
tools/pair_eyes.py                   offline pairing/diff tool
```

### Carried into Gate 4

`c[465]` and the clip-X column of `c[256..259]` are *correlational* evidence: they
are what changed between two known-good eyes. Gate 4 must still prove causation by
perturbing one slot at a time in a transient copy and checking that world geometry
moves coherently while HUD, shadows and reflections behave as their class requires.
`c[256..259]` is per-object (21 distinct left/right pairs), so it is a
world-view-projection, not a bare view matrix - perturbing it needs a per-draw
route, whereas `c[465]` is global and is the cheaper first probe.

## Gate 4 - prove the camera seam

- [x] Perturb one candidate constant at a time in a transient 2D draw copy.
- [x] Prove yaw, pitch, roll, and X/Y/Z translation affect the intended world geometry.
- [x] Confirm HUD, shadows, reflections, and unrelated objects are not incorrectly transformed.
- [x] Store the proven shader, slot, transform route, and draw classification as WipEout profile data.

Gate 4 result (2026-09-21): complete, on the `openxr` branch. Gate 3's correlation is
now causation, and the stereo transform is no longer a guess: it is the game's own
formula, fitted exactly from its native eyes, applied on the 2D/60-fps route, and it
reproduces native disparity within 0-4 px at every measured depth.

### Branching

Fork work lives on `openxr`, not `master`. `master` tracks upstream `origin/master`
and was reset to `9e86f165d` (4 behind, 0 ahead - clean). The Gate 3 commit moved to
`openxr` unchanged in authorship. While moving it, its `emucore.vcxproj` was repaired:
an earlier edit had rewritten the whole file from CRLF to LF, a 2330-line diff for a
2-line change. It is now CRLF with exactly the 2 added lines.

### The instrument

`rpcs3/rpcs3/Emu/RSX/Capture/rsx_camera_probe.{h,cpp}`, hooked at the end of
`draw_command_processor::fill_vertex_program_constants_data()` in
`Core/RSXDrawCommands.cpp` and polled from `rsx::thread::on_frame_end()`.

It modifies **only the transient per-draw constant copy**, after it is filled from the
guest bank. `method_registers.transform_constants` is never written, so guest
simulation, FIFO progression and savestates are unaffected. Default-off; title-gated
to `BCES00664`. The probe held 60 fps throughout.

`RPCS3_VR_PROBE_FILE=<path>` is re-read at every frame end, so every probe in a series
runs against **one booted scene** and the probe is the only thing that changes. On the
first full frame after arming, it logs a classifier report (draws perturbed / rejected
and why), so coverage is proven at runtime, not just predicted from a capture.

Modes: `stereo=<sep>,conv=<c>` (the game's own shear, below); `yaw/pitch/roll/tx/ty/tz`
(a camera delta `M' = D * M` pivoting on `c[465]`); `slot/comp/add` for raw controls.

### Controls first

The scene is not static - ambient animation and a running lap timer mean two
unperturbed frames already differ - so the noise floor was measured before any claim
(mean absolute RGB difference, 4x4 sample grid):

| | mean | range |
|---|---|---|
| baseline vs baseline (n=4) | 74.4 | 57.5 - 88.5 |
| **negative control** `c[400]+=100` (n=5) | 70.6 | 34.5 - 95.4 |

The negative control sits inside the noise distribution, and is structurally a no-op:
`c[400]` is read by 0 of 827 draws. At runtime its classifier report is 0/0/0.

### Every axis moves the world, coherently

yaw, pitch, roll and X/Y/Z translation each change 85-96% of the frame (mean diff
152-256, 2-3x the noise mean). `gate4-probe-contact-sheet.png` shows all of them:
geometry moves as a camera move should - no tearing, no exploded vertices, correct
perspective and occlusion - while the HUD stays where it is.

### The stereo transform is the game's own formula

Diffing the two native eyes block by block showed the per-eye change is confined to
**column 0** (clip X) and is proportional to **column 3** (clip W). Fitting
`clip.x += sep * (clip.w - conv)` to every per-eye camera block
(`tools/fit_stereo.py`):

```text
blocks fitted 641   max residual 3.81e-06   columns 1..3 unchanged
sep=0.08125 conv=2.878   1280x720 world         619 draws
sep=0.06094 conv=2.878   640x360 pass            10 draws   (0.75 x sep)
sep=0.08125 conv=0       layers at infinity       6 draws
sep=0.06094 conv=0       infinity, 640x360        6 draws
```

A 4e-6 residual is float precision: this *is* WipEout's stereo. It is an off-axis
(converged) camera - zero disparity at depth 2.878, `sep * 640 = 52 px` at infinity -
and because it is applied in clip space it does not care what world or object matrix
is folded into the block. The 2D camera sits at the midpoint of the two native eyes,
so each generated eye uses `sep = +/-0.040625`.

**Validated on the 2D route.** Generated left/right frames against the native eyes,
horizontal disparity at 1280x720:

| feature | generated from 2D | native 3D |
|---|---|---|
| ship (near, animated) | +23 | +24 |
| left barrier | +42 | +46 |
| harimau sign | +49 | +50 |
| right building | +48 | +48 |
| track, far | +50 | +50 |

This supersedes the earlier idea of a parallel `eye = +/-0.12` world translation: that
has no image-shift term, so it gives zero disparity at infinity where the game gives
52 px.

### Two camera routes

Gate 3 saw only `c[256..259]`. The per-eye draws it missed use a second route:

| route | camera block | `c[256..259]` is | per-eye draws |
|---|---|---|---|
| single-matrix | `c[256..259]` | world-view-projection | 485 |
| two-matrix | `c[260..263]` | an affine world matrix | 156 |

The probe selects the first *perspective* block of the two, per program.

### The draw classifier, scored against the game

A blanket injection **rotated the HUD with the world** (`superseded/probe-05-roll10.png`):
the HUD reads `c[256..259]` too, holding an orthographic screen-space matrix. An
intermediate classifier ("program also reads `c[465]`") fixed the HUD but was
over-broad. Rather than argue about rules, every candidate was scored against the
game's own per-eye labels from the native capture:

| classifier | TP | FP | FN | TN |
|---|---|---|---|---|
| reads `c[465]` | 532 | **153** | 14 | 41 |
| perspective camera block only | 641 | **58** | 0 | 41 |
| **aspect-matched target AND perspective block** | **641** | **0** | **0** | **99** |

The 58 false positives of the perspective-only rule are the five 512x256 cascade
passes: their `c[260..263]` is perspective, but the game never changes it between
eyes. The build had exactly this bug until a runtime coverage check caught it; the
aspect gate removes it. Runtime report on the fixed build, per frame: ~505 fills
perturbed, **76 rejected as off-aspect targets**, 2 rejected for having no perspective
block.

HUD, measured by template-matching opaque HUD features rather than region diffs (the
world shows through translucent panels): the lap counter is at (0,0) in all eight
probe frames, and the "BEST" box is at (0,0) for stereo and all rotations. For the
three large translations the "BEST" match hits the search boundary - a failed match,
because the world behind that translucent box changes completely - and the contact
sheet shows it in place.

### Per-pass policy (measured, not chosen)

| pass | matrix | `c[465]` | why |
|---|---|---|---|
| 1280x720 world | per eye | per eye | oracle changes both |
| 640x360 half-res | per eye | per eye | oracle changes both |
| 512x256 x5 cascades | **shared** | per eye | oracle changes `c[465]` only |
| 512x512, 256x256 | shared | - | eye-invariant |
| HUD / display | shared | - | orthographic |
| 320x180 / 160x90 post | shared | - | no camera matrix |

`c[465]` is per-eye global camera state (one value pair across 40 programs, baseline
0.240 world units), so it needs its own policy with its own draw set. The probe applies
the matrix shear only; `c[465]` is recorded as policy for Gate 5.

### Profile data

`rpcs3/bin/vr_profiles/BCES00664.json` (deploys beside `rpcs3.exe`; `.gitignore` gains
`!/bin/vr_profiles/`, the same pattern that keeps `bin/GuiConfigs/` tracked): slots and
matrix convention, both camera routes, the classifier and its oracle score, the stereo
formula with all four fitted variants, the camera-position policy, the per-pass table,
keying rules (never render-target addresses - the world pass moved from `0xc1680000`
to `0xc0f50000` between modes - never shader hash alone), and the Gate 5 hazards below.
Every number is regenerated by `tools/fit_stereo.py`.

### Evidence

```text
plans/evidence/gate4/
  v2-*.png                       final validation set (fixed build)
  gate4-probe-contact-sheet.png  all axes + stereo pair at a glance
  analysis-stereo-fit.txt        fit_stereo.py output
  superseded/                    earlier iterations; probe-05-roll10 shows the HUD bug
tools/fit_stereo.py              classifier scoring + stereo fit
rpcs3/bin/vr_profiles/BCES00664.json
```

### Carried into Gate 5

- **Render twice, classify per draw.** RPCS3 refills transform constants only on a
  guest constant write, a vertex-program ucode change or an interpreter swap - *not*
  on a render-target change. The probe classifies at fill time; in this scene 0 of 827
  draws inherit a stale classification, but that is this scene, not a guarantee.
- Per eye: shear the selected camera block with `sep = +/-0.040625, conv = 2.878` (or
  the pass's fitted variant), and offset `c[465]` by `+/-0.120` along camera right on
  every draw that reads it.
- The 640x360 pass and infinity layers use their own `sep`/`conv`; reproduce the four
  variants or derive them per draw.
- Instanced draws: the initial fill in `fill_constants_instancing_buffer()` goes
  through the probe, but mid-clause patches replayed via `translate_constants_range()`
  do not. This scene emitted no instanced draws, so it is unproven rather than broken.

## Gate 5 - generate stereo from one 2D guest frame

- [x] Render classified world draws into separate left and right host targets using eye-specific transient camera constants.
- [x] Keep guest simulation, FIFO progression, queries, statistics, and frame accounting single-shot.
- [x] Define explicit policies for HUD, post-processing, shadows, reflections, and render-target feedback.
- [ ] Compare generated eyes against native-3D disparity, scale, convergence, occlusion, and HUD behavior.
- [x] Confirm the game remains on its ordinary 60-fps route.

Gate 5 implementation status (2026-09-21): first-light Vulkan path is implemented
and builds, pending runtime validation. The BCES00664 profile is temporarily armed
by default in code; `RPCS3_VR_PROBE=render=1` and `RPCS3_VR_PROBE_FILE` remain
available for explicit probe overrides. It creates a
second host-only surface cache keyed by the same guest target layouts, clones the
current transform-constant allocation per emitted draw, applies `eye_sign=-1/+1`,
renders both host eyes, and supplies the right display surface to RPCS3's existing
two-image stereo compositor. Guest constants, FIFO execution, draw/frame accounting,
and guest-visible render-target memory remain single-shot.

Current fail-closed limits: instanced draws
are not amplified (draws inside an active occlusion query now are - see below); partial clears are not mirrored (full clears are); blit/copy and
render-target-feedback propagation still require runtime evidence before this gate can
be checked complete. The environment variable is therefore an explicit development
gate, not a user-facing option.

### First-light runtime result (2026-09-21)

The composed output works, but the visible race eyes are not stereo yet. Following the
Gate 2 method, the RPCS3 client was resized to exactly 1280x720, captured from the
window, and split at x=640. Only 432 of 460,800 pixels differ (0.0938%), and the
central 560x500 world crop is byte-identical at zero horizontal shift. Mean absolute
RGB difference is `[0.089, 0.104, 0.110]`; the native Gate 2 eye pair measures
`[52.012, 46.359, 43.280]`.

Evidence is in `plans/evidence/gate5/`: `generated-race-sbs-720p.png`, the split
`generated-race-left.png` / `generated-race-right.png`, and
`generated-race-diff-x12.png`. The loading-screen capture also shows an incomplete
right target, confirming that two distinct compositor inputs exist.

The leading failure hypothesis is render-target feedback: the right-eye replay writes
isolated intermediate surfaces, but later post-processing draws still resolve their
textures through the ordinary guest-authoritative texture cache. They therefore sample
the left intermediate into both final targets, erasing the camera disparity. Gate 5's
next implementation step is to substitute matching `m_vr_right_rtts` surfaces while
binding textures for the right-eye replay, then repeat this exact window comparison.

### Occlusion-query fix and second runtime result (2026-09-21)

The feedback fix (right-eye texture binds resolve to `m_vr_right_rtts`) left the right
eye's world black while the HUD survived (`feedback-fix-check.png`): the world pass is
drawn inside guest occlusion queries, and those draws were fail-closed. `emit_geometry`
now splits the open guest query around the right-eye replay: it reserves a continuation
slot before the left draw, ends the guest query, replays the right eye outside it, then
begins the continuation slot and appends it to the query's `indices`. Result collection
(`get_occlusion_query_result` and the conditional-render aggregation) already sums every
slot, so the guest still sees left-eye-only samples. If no slot is free, that draw falls
back to mono.

Runtime (Vineta K start line, 0 KM/H, window client 1920x1200 captured DPI-aware, each
eye 960x1080 and resampled to 1280x720 for comparison against the Gate 2 native pair):

| Region            | Native R-L shift | Generated R-L shift |
|-------------------|------------------|---------------------|
| Far horizon/tower | +50 px           | +51 px              |
| Mid track rail    | +49 px           | +49 px              |
| Near track edge   | +26 px           | +27 px              |
| Ship nose         | +26 px           | +26 px              |
| Ship body         | +19 px           | +19 px              |
| HUD (LAP, speed)  | 0 px             | 0 px                |

Mean absolute RGB eye difference is `[48.95, 44.93, 44.17]` (native `[52.01, 46.36, 43.28]`;
first light was `[0.09, 0.10, 0.11]`). The game held 60 fps on the ordinary 2D route.
Evidence: `query-fix-race-client.png`, `query-fix-race-left.png`, `query-fix-race-right.png`.

The per-pass policy is Gate 4's measured table, and `camera_probe::apply_render_eye`
implements it: the world and 640x360 passes get the per-eye shear plus the `c[465]` offset;
the 512x256 shadow cascades get only `c[465]` (non-output aspect); the 512x512/256x256
reflection passes, the HUD and post-processing are eye-invariant (orthographic or no camera
matrix) and are replayed unchanged. Render-target feedback is handled by resolving right-eye
texture binds through `m_vr_right_rtts`.

Still open for this gate: the infinity layers are left on the converged shear rather than
Gate 4's `conv=0` variants (6+6 draws, awaiting program/pass keys in the profile), instanced
draws, partial-clear mirroring, and an occlusion/convergence comparison beyond this one scene.

## Gate 6 - presentation and optimization

- [x] Add OpenXR submission only after the generated eye images are correct.
- [ ] Establish a correct render-twice implementation before considering Vulkan multiview.
- [ ] Measure CPU/GPU cost, frame pacing, latency, and headset comfort.

### OpenXR first light (2026-09-21)

`rpcs3/Emu/RSX/VK/VKOpenXR.{h,cpp}` presents the generated eyes to the headset as a
world-locked **stereo quad** (a virtual 3D screen, 3.0 m wide at 2.0 m in LOCAL space;
`RPCS3_OPENXR_WIDTH` / `RPCS3_OPENXR_DISTANCE` override). Head motion is reprojected by
the compositor at headset rate; the game camera does not yet follow the head.

- Loader: `openxr_loader.dll` (Khronos release 1.1.63, SHA-256 of the zip
  `01c631ae...b771`) is loaded dynamically from beside `rpcs3.exe`; if it is absent,
  RPCS3 runs normally. Headers are vendored in `rpcs3/3rdparty/OpenXR/include/openxr/`.
- Armed only when the stereo render path is (`camera_probe::render_enabled()`, i.e.
  BCES00664); `RPCS3_OPENXR=0` disables.
- `XR_KHR_vulkan_enable`: the runtime's extensions are merged into RPCS3's own
  `vkCreateInstance` / `vkCreateDevice`, and the GPU is the one the runtime names.
- Per flip: `xrWaitFrame`/`xrBeginFrame`, acquire both eye swapchain images, record
  `vkCmdCopyImage` from the generated eyes into them **inside RPCS3's flip command
  buffer**, then `xrReleaseSwapchainImage`/`xrEndFrame` after RPCS3 submits. Every XR
  call that may touch the queue holds `vk::g_submit_mutex`. Copy (not blit) into an sRGB
  swapchain of the same channel order, because the eyes already hold gamma-encoded bytes.
- Runtime: SteamVR (lighthouse) reached FOCUSED; 3840x2160 `B8G8R8A8_SRGB` swapchains
  at 300% scale; first stereo frame submitted; no XR errors over a minute of running.

### Projection layer with head rotation (2026-09-21, pending headset validation)

Default mode now (`RPCS3_OPENXR_MODE=quad` restores the virtual screen).

- **Rotation in clip space.** The camera blocks are object-to-clip products, so the head
  rotation is applied as `M' = M * P^-1 R P` without knowing the world or object matrix.
  For `M = L * P` with `L` affine: `c/e = col2.col3 / col3.col3` exactly (rows 0-2), and
  for rigid `L`, `a/|e| = |col0|/|col3|`, `b/|e| = |col1|/|col3|` (cached from blocks
  with orthogonal columns, reused for scaled objects). Near/far are never needed, and
  moving objects (the ship) rotate about the camera, not their own origin - unlike the
  Gate 4 probe's object-space `D * M`, which is not reused.
- **Parallel eyes.** Only the translation term of the game's formula is kept
  (`clip.x -= sep*conv`, i.e. the same 0.120-unit eye offset as `c[465]`); the
  convergence image shift is dropped. `RPCS3_OPENXR_EYE_SCALE` scales it.
- **Pose timing.** After each flip's `xrEndFrame`, the head is located one 60 Hz frame
  after that display time; the next frame's draws are rotated by it and it is declared
  (with the located eye positions) in that frame's projection views. FOV is the game's
  own, measured from the draws each frame (`RPCS3_OPENXR_FOV_SCALE` widens it).
- First runtime: session FOCUSED, projection layer active; first measured FOV (menu
  camera) 50.9 x 30.0 degrees.

**Headset FOV (default; `RPCS3_OPENXR_FOV=game` reverts).** Each eye's located
(asymmetric) FOV is applied to every camera draw as a clip-space remap from the game
frustum, `X' = X*sx + W*ox` with `sx = 2/(A*(r-l))`, `ox = -(r+l)/(r-l)` (likewise Y), and
declared unchanged in the projection view. First run: 92.0 x 92.0 degrees per eye
(SteamVR lighthouse); the game camera measured 43-102 degrees wide depending on camera
and speed.

**Screen space stays screen space.** Classifier measured on the Gate 3 2D capture: of the
49 non-perspective draws on 16:9 targets, all 31 HUD draws (797-827) read `c[256..259]`
as an orthographic pixel matrix (`[0.00104, -0.00185, ...]`, translation
`(-0.961, 0.961)`), and all 18 post-process draws (779-796: bloom chain, full-screen
composite) read no `c[256..259]` at all. So an output-aspect draw with an orthographic
`c[256..259]` is HUD/menu; it is mapped into a fixed 16:9 box fitted inside the central
symmetric part of the headset frustum, times `RPCS3_OPENXR_HUD_SCALE` (default 0.65: at 1 the box
spans the full render FOV, whose edges are outside what the lenses show) - independent
of the game FOV, which varies with speed and would make the HUD breathe or leave the view.
This corrects the Gate 4 note that one program serves both post-process and HUD: in the
captured frame, `8a3e5582` is HUD-only.

**Pacing: the RSX thread never waits on the headset.** Races with AI ships dropped
below 60 fps (solo races did not) while RPCS3 used under half a core and the GPU ~33%, at
any resolution scale. Diagnostic logging showed the RSX thread blocked in `xrWaitFrame`
for ~400 ms of every second: two independent 60 Hz clocks (emulated vblank, headset
display) drift in and out of phase, and every blocked millisecond was taken from guest
command processing, which doubles per draw in stereo. fpsVR reports that lateness as "CPU
frametime" because SteamVR cannot see what the app waited on. Fix: a dedicated OpenXR
frame thread owns `xrWaitFrame/xrBeginFrame/xrEndFrame`, its own command pool and fence,
and submits its swapchain copies under `vk::g_submit_mutex`. At each flip the RSX thread
only records a copy into one of three eye buffers (`publish_eyes`), submits, and commits
it tagged with the pose/FOV its draws used (`commit_eyes`); the frame thread presents the
newest committed pair, re-presenting the previous one when none is new.

**Races with AI ships below 60 fps: a config setting, not the VR path.** The same build
with stereo and OpenXR off (`RPCS3_VR_PROBE=render=0`) also dropped below 60, at ~2% system
CPU. The cause was `Preferred SPU Threads: 1` in `config_BCES00664.yml` (changed from the
default 0 after Gate 3; every archived config through Gate 3 has 0): it lets only one SPU
thread run heavy work at a time, so the extra AI/physics SPU jobs queued behind each other
with cores idle. Restored to 0: races with ships hold 60. `Relaxed ZCULL Sync` was tried
first and made no difference (reverted).

### Open investigation (paused 2026-09-21): 60 fps holds at 150-200% but not 250%

Measured with per-second `Pacing:` / `Replay parts` log lines (temporary diagnostics in
`VKPresent.cpp`, `VKDraw.cpp`, `vkutils/sync.cpp`, `VKCommandStream.cpp`, `VKOpenXR.cpp`):

- No GPU fence waits at any resolution (0 waits/s); desktop acquire ~0.3 ms/s; OpenXR
  thread holds the submit lock ~33 ms/s. Host GPU labels are off.
- Right-eye replay costs ~210 ms/s of RSX-thread time in scenes with ships (vs ~5 ms/s in
  menus), **identical at 150% and 250%**, so it is real overhead but not what scales with
  resolution. ~125 ms/s of it is two `m_program->bind + update_draw_state +
  begin_render_pass` sequences (right eye, then restoring the left) per draw.
- Readback of the write-combined constant ring was removed (`bind_vr_eye_constants` now
  refills from guest registers into a CPU scratch buffer); no measurable change.
- Next step (instrumented, not yet run): RSX-side time waiting for the submit lock and
  inside `vkQueueSubmit`, compared at 250% vs 150% using the attract-mode race (~30 s after
  boot, has AI ships, needs no input). Then cut the replay overhead (avoid the second
  descriptor/pipeline/render-pass round trip per draw, e.g. batch right-eye draws).
- Temporary diagnostics removed in `79e052991` ("VR: game profiles utilised"); re-add from git history if this investigation resumes.

### OFXR Bridge frame generation: tried, removed (2026-09-22)

OFXR Bridge (optical-flow frame generation API layer) only handles D3D11/D3D12 sessions; with
our Vulkan binding it logs `no_d3d12_binding` and passes frames through. A D3D12 session binding
(shared eye buffers imported into Vulkan) was built and worked (`session_binding result=2`,
frames generated), but OFXR paces the app at half the headset rate (36 fps at 72 Hz, 45 at 90 Hz),
so a 60 fps game loses real frames and judders. Only a >= 120 Hz headset would suit it. The D3D12
code was reverted; the Vulkan binding is unchanged.

### 90 Hz native: `Vblank Rate: 90` (2026-09-22)

`config_BCES00664.yml` now has `Vblank Rate: 90` (original saved as
`config_BCES00664.yml.vblank60.bak`). WipEout runs 90 flips/s and its clock stays real-time (lap
timer advanced 75.0 s in 75.03 s of wall time), so one real frame per 90 Hz headset refresh.
Ship speed was not independently confirmed.

### Race-start drops: measured (2026-09-22)

Scripted Racebox single race (Vineta K, FEISAR), per-second diagnostics now include RSX idle
time (`performance_counters.idle_total`), zcull read time, readback faults, desktop present and
`wait_for_event` time (temporary, Gate 6 diagnostics).

1. **ZCULL reads.** With strict ZCULL sync the pre-race flyover at 350% ran 52-61 fps with RSX
   blocked 470-520 ms/s in `get_occlusion_query_result` (waiting for the GPU). `Relaxed ZCULL
   Sync: true` (now set) removes it: zcull ~0 ms/s, flyover 81-90 fps.
2. **Grid start (~8 s, ~1500 draws/frame).** Still 52-54 fps at 350%, 77-83 at 125%, 90 once the
   pack spreads (~450 draws/frame). GPU shows 98% busy but only ~212 W on the RTX 5090, i.e.
   stalled, not shading-bound. Cause: right-eye replay ends and restarts the render pass twice per
   draw (~3000 extra pass switches per frame), whose GPU cost grows with render-target size.
   The fix is batching the right-eye draws or Vulkan multiview (Gate 6 checklist item). Sampled
   RSX thread stacks confirm RSX itself is blocked on the GPU there, not CPU-bound.

### Right-eye batching (2026-09-22, built, measured, confirmed working in the headset)

The right-eye draws of one left render pass are recorded into a Vulkan secondary command
buffer and executed in one right-eye pass when the left pass ends, instead of ending and
restarting render passes twice per draw. `vk::end_renderpass` calls
`vk::g_end_renderpass_hook`, so every left-pass end (for any reason) runs the batch first and
ordering is preserved; `prepare_rtts`, the full-clear mirror and `flip` flush explicitly. A
batch is only open while the left pass is open. Right-eye texture binding stays on the primary
(its barriers end the left pass, flushing first); push constants, pipeline, dynamic state and
the draw go into the secondary. Open guest occlusion queries are split around the right-eye
pass. Programmable-blending and conditional-render draws keep the per-draw replay.
`RPCS3_VR_BATCH=0` restores per-draw replay. Code: `VKGSRender::vr_batch_*`, `VKDraw.cpp`
`emit_geometry`, `VKRenderPass.cpp`.

Same build, 350%, Racebox single race, grid start (OpenXR off, 90 Hz vblank):

| | per-draw (`RPCS3_VR_BATCH=0`) | batched |
|---|---|---|
| grid start fps | 50-51 | 86-90 |
| right-eye passes | ~2 per draw (~1500 draws/frame) | ~78 per frame (~17 draws each) |

With OpenXR on: 87-90 fps on the grid, 90 once racing. Both eyes verified side by side
(`evidence/gate6/batch-on-sbs-350.png` vs `batch-off-sbs-350.png`). Remaining grid headroom is
small (RSX idle ~120 ms/s).

Evidence and tools in `plans/evidence/gate6/`: `tools/race.ps1` (scripted race; needs a
temporary keyboard pad profile at `bin/config/input_configs/BCES00664/Default.yml` mapping
Cross=X, arrows; delete it afterwards), `keys.ps1`, `sampler.ps1` (RSX-thread stack sampler),
`sbsshot.ps1`.

**Menu background is screen space (2026-09-22).** The main-menu particle cloud (one ~320k-vertex
draw, program `c16fdc1a`) was head-rotated and stretched to the headset FOV while the menu stayed
in its box. A menu inspector capture shows its camera block `c[260..263]` is a *bare projection*
(no view rotation or translation; the view is in `c[256..259]`, and `c[465].w = 0`). No camera
block of the ~1500 race draws in either Gate 3 capture has that form. Such draws now go through
the HUD's fixed-box mapping (`camera_probe::map_vr_screen_box`, which also corrects depth for the
W change), so the cloud stays fixed in the menu. 3D menu models with a real camera, such as the
Track Select circuit model, still follow the head.

### Head position tracking (2026-09-22, pending headset validation)

Only head rotation was applied, so leaning or moving toward an object did not change its size.
`locate_render_pose` now also returns the head position in LOCAL space, and `set_vr_view` converts
it to game units. The scale comes from the game's own stereo: 0.240 units is the native eye
separation, which is the measured `ipd` in metres, so 1 m is about 3.8 units at the default
eye scale, and `RPCS3_OPENXR_EYE_SCALE` scales head motion and stereo together.

In `apply_vr_rotation` the offset is subtracted from the *point* term (row 3) only, since rows
0..2 carry the object's own x/y/z and a camera move does not touch them; the existing
`Z += k*(W' - W)` keeps depth consistent. The fixed HUD/menu box translates too, with the head
offset divided by its 2 m distance, so leaning shifts the view across it. `RPCS3_OPENXR_POSITION=0`
falls back to rotation only.

**Camera Depth Offset** (`Video > VR`, default 0, -100..+100 cm) adds a constant forward offset
along the head's forward axis through the same path.

**VR is offered only for profiled titles.** `rsx::vr::title_has_profile()` (BCES00664) gates the
checkbox in the settings dialog, which is only reachable from a game's custom configuration; the
tooltip says so.

Known limits: the game still culls to its own camera frustum, so large head turns (or a
widened FOV) reveal missing geometry at the edges; shadow cascades are fitted to the
unrotated camera. `RPCS3_OPENXR_FLIP_Y=1` if pitch/roll come out inverted.

### RPCS3 overlays in the headset (2026-09-22, confirmed in the headset)

RPCS3's own overlays (the home menu on Back+Start, i.e. `PS Button: "Back&Start,Guide"` or
Shift+F10; boot notifications, dialogs, trophies, the perf overlay) were drawn only on the desktop
swapchain. At each flip with a visible overlay, RSX now draws them into a transparent 1920x1080
image with `vk::ui_overlay_renderer_xr` (same shaders, alpha blended "over" so the result is
premultiplied) and publishes it (`vk::xr::publish_overlay`, own triple buffer). The frame thread
copies it into its own swapchain and submits an `XrCompositionLayerQuad` over the eyes
(`XR_COMPOSITION_LAYER_BLEND_TEXTURE_SOURCE_ALPHA_BIT`). It uses the HUD box's size and position:
at 2 m, HUD Scale and offsets, world-locked when "HUD Fixed In Front" is set, otherwise following the head.
The overlay is shown with the eye pair of the same flip (`commit_eyes`) or on its own
(`commit_overlay`, which wakes the frame thread) when emulation is paused.

Also fixed: overlay-requested flips (`emu_flip == false`, e.g. while the home menu pauses
emulation) re-published the last game frame tagged with a newer head pose, so the world would
follow the head. Only game flips now publish eyes and locate the next pose.

First run: overlay swapchain created at boot (boot notification), home menu opened at 90 fps
with no OpenXR/Vulkan errors (`Pause Emulation During Home Menu: false` in this config).

### VR tab in the home menu settings (2026-09-22)

Home menu > Settings has a **VR** tab below Video (only when `Video > VR > Enabled`; that switch
itself needs a restart so it is not on the tab). It carries every other VR setting from the Qt
dialog: Fixed Screen, HUD Fixed In Front, HUD Scale, HUD Horizontal/Vertical Offset, Screen 3D
Depth, Camera Depth Offset. All are dynamic `g_cfg` entries read at every flip, so changes apply on
the next frame; Save/Discard behave like the other tabs. Code: `home_menu_settings_vr` in
`overlay_home_menu_settings.{h,cpp}`, strings in `localized_string_id.h` / `localized_emu.h`, icon
`fa_icon::vr` -> `bin/Icons/ui/home/{32,256}/vr-headset-solid.png` (drawn to match the set).
Verified: tab and values render; HUD Scale 65 -> 70 -> 65 logged live.

### Game-specific values moved into the VR profile (2026-09-22)

Before this, nothing read `bin/vr_profiles/BCES00664.json`: `title_has_profile()` compared against
`"BCES00664"`, and every value was a literal in `rsx_camera_probe.cpp`/`VKPresent.cpp`. The profile is
now a minimal published config (schema 1) holding only what the renderer reads, loaded for the booted
title by `rsx::vr::load_title_profile()` (parsed with RPCS3's yaml-cpp, which reads JSON; emucore is
built without exceptions so all lookups go through `get_yaml_node_value`). Unknown keys are warned
about. Field reference: `plans/profiles/README.md`; WipEout's measurements and reasoning:
`plans/profiles/BCES00664-evidence.json`.

The HUD box aspect now comes from the output size instead of 16:9. VR is offered for any title with a
valid profile; probe experiments (`RPCS3_VR_PROBE`) default to the profile's slots and accept
`base=`/`cam=` for unprofiled games.

Verified on WipEout: profile loads before the renderer, stereo + OpenXR run as before; every parsed
float equals the old literal bit-for-bit (as do eye_baseline/2 and 1280/720 vs 16/9), so per-draw
output is unchanged by construction. A corrupted value gives
`VR profile ... is invalid: "per_eye_separation": ... bad conversion` with line/column, VR stays off and
the game runs in 2D.

### Match Headset Refresh Rate (2026-09-22)

Video > VR > "Match Headset Refresh Rate" (also in the home menu's VR tab). While a headset session
runs, the emulated vblank follows the headset's refresh rate; the saved Vblank Rate is never modified
and applies again without a headset. All vblank reads in `RSXThread.cpp` (vblank thread, frame limiter
Auto/none, CPU preemption tuning) go through `rsx::vr::effective_vblank_rate()`. Offered only when
the VR profile has `"match_headset_refresh_rate": true` (WipEout: yes); then it is on by default.
Otherwise the settings checkbox is shown disabled with a "not supported in this game" tooltip, and
the home menu omits it.

The rate comes only from `XR_FB_display_refresh_rate` (SteamVR supports it; change events are
followed). A first version used `XrFrameState::predictedDisplayPeriod`, but that is the app's pacing:
SteamVR reported 45/30/22.5 Hz whenever the game ran late, and the vblank spiralled WipEout down to
23 fps. Without the extension the option keeps the configured Vblank Rate (logged).

`config_BCES00664.yml` is back to `Vblank Rate: 60`; with the option on, WipEout ran 90-91 flips/s
from the headset's 90 Hz. Toggling in the home menu switched the vblank 90 -> 60 -> 90 Hz within a
second each way.

## Second title: Pure (BLUS30182) VR profile (2026-09-22)

Profile `bin/vr_profiles/BLUS30182.json` added; details and evidence in `plans/profiles/BLUS30182-notes.md`
and `plans/evidence/pure/`. Two renderer changes were needed and apply to any title:

- Profile format: `matrix_layout: "column_vectors"` (PSGL/Cg DP4 matrices, the transpose of WipEout's).
  `rsx_camera_probe.cpp` binds camera/HUD blocks through `matrix_block`, which transposes into a local
  copy and writes back; probe key `layout=columns` does the same for unprofiled games.
- Right-eye blit mirror (`VKGSRender::vr_mirror_blit`): 1:1 NV3089 copies between render targets are
  repeated in `m_vr_right_rtts`. Partial clears are still not mirrored.

Verified on the desktop (OpenXR off): stereo disparity as predicted, HUD at zero disparity, pause menu
identical in both eyes, 80-90 fps at 300%. Pending: headset run.

### In-emulator VR profile generation (2026-09-23)

Home menu > Settings > VR is always shown. Without a profile it holds only **Generate VR Profile**,
which samples a couple of seconds of gameplay, writes `bin/vr_profiles/<TITLE_ID>.json`, and enables VR
(`rsx::vr::profile_generator`; a new `page_navigation::exit_menu` closes the menu from inside a settings
tab). Verified on Pure: the generated profile equals the hand-made one apart from an equivalent
sep/conv split. Details and limits: `plans/5-vr-profile-playbook.md`, "In-emulator generation".

## Unreleased games

Per-game state for everything not yet released (Split/Second, Blur, inFamous 1 and 2, MGS4, NFS Most Wanted,
GT5, MotorStorm, God of War Collection, Killzone 2, and the rest) is in **`plans/6-wip-games.md`**, with detail
in `plans/profiles/<TITLE_ID>-notes.md`. Game-specific progress is recorded there, not here. This file keeps
the generic renderer, profile-format and tooling work, plus releases.

An in-emulator "generate frame-rate patch" button was considered and dropped (2026-09-23). The swap-interval
half is a findable PSGL pattern, but the game-speed half is engine-specific code (Split/Second's tick-count dt
at `0x509a4`), so it can't be generated reliably.

## Generic work from the five-title pass (2026-09-23/24)

Renderer/profile-format additions (documented in `plans/profiles/README.md`): scaled-blit mirroring
(`texture_cache::blit_vr_right`), partial-clear mirroring, right-eye rebuild of deferred texture copies,
`column_vectors_xyw`, `require_camera_aspect`, `camera_target_aspect`, explicit slot lists in
`camera_blocks`, `game_camera_target_widths`, `screen_space.depth_offset_projection` (incl. x/y-shifted
planes) and `screen_space.rotation_only_passthrough`. Generator: three layouts, 5% view-target tolerance,
overlapping blocks, anamorphic targets, reversed-depth near plane, 200x world-scale clamp.

Dev hooks (environment variables, for unattended runs): `RPCS3_VR_GEN_TRIGGER`, `RPCS3_VR_KEYS` (key
script into the keyboard pad), `RPCS3_VR_SHOT` (screenshot, both eyes when stereo), `RPCS3_VR_MEMDUMP`
(guest memory snapshot), `RPCS3_USLEEP_STATS`; inspector captures now include blit/NV0039 notes.

### Low frame rates with headset reprojection (2026-09-24)

Direction: keep the PS3's 60 Hz vblank (no frame-rate patches) and let the headset runtime fill the
gaps (SteamVR Motion Smoothing / reprojection at 1/2, 1/3 of the headset rate). Changing the vblank rate
itself is per-game risky: WipEout at Vblank 45 made menu transitions ~10x slower. SteamVR's own throttle
does not slow the game (the OpenXR frame thread is decoupled from RSX), so it saves no rendering; a
vblank-aligned in-emulator VR frame cap (Off/30/60) was designed but not built, pending headset tests.

**Reprojection Margin** (`Video > VR`, home menu VR tab, 0-30 degrees, default 0): at low frame rates
the runtime turns an older frame to the current head pose and showed black at the view edges on head
turns (Ico at 30 FPS). Each eye is now rendered and declared (`XrCompositionLayerProjectionView::fov`)
with its FOV widened by the margin on every side (capped at 80 degrees); the HUD box and overlays stay
sized from the visible FOV (`camera_probe::m_vr_eye_fov_visible`). Costs pixel density (same eye image
size over a wider FOV). Confirmed in the headset: fixes the black edges (Ico, 30 FPS). Commit `d0b87b06a`.

**Pose per frame (built, pending headset validation).** Ico head turns felt like the world dragged
against the head at 30 FPS (confirmed as a pose mismatch: it happens with the game camera still). Ico
flips from its vblank handler (`cellGcmSetFlipImmediate`), so the flip, where the pose was sampled and
the frame declared, could land mid-frame: one frame drawn with two poses, declared with the wrong one.
Now (`VKPresent.cpp` `vr_update_view` / `vr_track_frame_boundary`): locate_render_pose returns an id
(last 8 kept in VKOpenXR); when the game moves its colour target away from a display buffer (a frame
boundary, in `prepare_rtts`) the next pose is located and applied for the whole next frame; each display
buffer records the pose of the camera draws before it was written, and the flip declares that pose.
Games that never render into a display buffer, or show no boundary for two flips, keep the old
per-flip update. Log line: "VR: head pose changes at frame boundaries".

**Ico: game frustum culling widened (patch, pending headset validation).** Ico culls to its own camera
frustum, so head turns showed the skybox where objects were skipped. The patch "Wider view (VR culling)"
scales the game's PS2-style screen distance, widening its render and cull frustum together (default 3.0);
the headset remap keeps the image scale. Verified by the yaw-40 audit (`plans/evidence/ico/`). Draw
distance (pop-in) not addressed yet: the projection far plane is 262144, so it is per-object. Details in
`plans/profiles/BCUS98259-notes.md`. New dev hook: `RPCS3_PPU_WATCH` (write watch, interpreter only).

**Pre-projected sprites follow the eye transform (built, confirmed in the headset on Ico).** Ico's flames are
projected by the game on the CPU and drawn with w = 1, so they stayed in game-screen space. New profile
field `screen_space.preprojected_programs` (vertex ucode hashes): those draws get `B^-1 * B_eye` of the
latest camera block per eye (`camera_probe::map_vr_preprojected`, bound like the HUD box in
`VKGSRender::vr_hud_vertex_env`).

**Frames without 3D are shown as the fixed screen (built, pending headset check).** ICO's splash screens,
videos and the collection launcher filled the whole view (no camera draws, so neither the HUD box nor the
head transform applied). `VKGSRender::vr_update_view` now counts camera draws per game frame; after 3
frames without any it presents that frame as the fixed screen (HUD size/offset settings), and returns to
the headset view on the first frame with a camera draw. Log: "VR: frames without camera draws: shown as
the fixed screen". Note: `plans/tools/launch.ps1` without `-Probe 'render=1'` leaves VR rendering off.

### Release readiness (2026-09-24)

- Shipped games: WipEout HD Fury (BCES00664), Pure (BLUS30182), Ico (BCUS98259). The other seven profiles and
  their patches moved to `rpcs3/vr-non-working/` (not in `bin/`, so not packaged). `rpcs3/vr-games.md` lists
  all ten by playability; the Windows deploy scripts copy it into the package.
- Defaults: `Video > VR > Enabled` and `HUD Fixed In Front` on; Reprojection Margin -1 = Auto.
- Profile `max_fps` replaces `match_headset_refresh_rate`: 0 = syncs the vblank to the headset (WipEout,
  Pure), otherwise (or unset) capped: configured vblank and margin Auto 10 degrees (Ico: 30).
- Profile `game_refresh_rate_f32`: Pure's refresh variable (`[0x1050300]+0x14`) gets the effective vblank rate
  every frame, so Pure follows any headset rate; its patch is now only the swap interval (verified 59.94 -> 90,
  90 FPS with Vblank 90).
- Patch key `Enabled By Default: true` (fork): on unless the user's `patch_config.yml` says otherwise; switching
  one off is saved as `Enabled: false`. On by default: Pure's frame-rate patch; Ico's Disable MLAA (fork copy,
  1.1, supersedes the community 1.0), Full Pixel Mode always on, Wider view (x20). Verified with no
  `patch_config.yml`. Ico's unlocked frame-rate patch is not shipped (game runs 3x fast).

**Release procedure.** Versions are upstream's plus a fork tag: `0.0.42-vrN-<commit> Alpha` in the app,
GitHub release tag `v0.0.42-vrN`, zip `rpcs3-v0.0.42-vrN-<commit>_win64.zip`. For each release: bump
`RPCS3_VR_VERSION` in `rpcs3/rpcs3/rpcs3_version.cpp` (vr7 tagged 2026-10-02; the next is vr8), commit,
build emucore/VKGSRender/rpcs3 so the exe carries that commit, run `plans/tools/package_release.py`, smoke-test
the zip from a non-temporary folder, push `openxr` and the annotated tag; Matt tests the zip and publishes the GitHub release himself. After merging a newer upstream
version, restart at vr1.

**Headset regressions found by the first release test (2026-09-24), fixed.** A fresh install froze Pure and
WipEout once the headset was worn ("invalid layout": realign copied into a fresh UNDEFINED helper image).
The per-frame pose machinery from the Ico pass (frame-boundary poses, blend-target realignment, feedback
reprojection) then broke Pure (flashes, a bright square, the paused frame as a head-locked quad because its
pose left the 8-entry history); it is now profile-gated (`reproject_older_frames`, Ico only), and an expired
pose falls back to the newest. Pure's sky (far-plane DP4 block) now takes no eye offset. The no-3D fixed
screen is profile-gated (`frames_without_3d_as_screen`, Ico only). Confirmed in the headset: Pure (sky,
pause, gameplay). WipEout's slow menu in the dev setup was video memory at 750% (106%, 20 GB texture cache).
Not yet re-checked after these changes: Ico. Release zip `rpcs3-v0.0.42-vr1-925a3f98_win64.zip` (rebuilt after the vr-games.md playable table; supersedes 33b341b6).

**Shadow of the Colossus (vr2, 2026-09-25, desktop-verified).** Executable-specific VR profiles
(`<TITLE_ID>.<executable>.json`) so SotC and ICO can differ under one title ID; `BCUS98259.shadow.json`
(camera c[60] + c[64], metres). Patches: Disable MLAA, Full Pixel Mode always on (k 1.19 -> 1.00), frame
interval 1 at both init sites + the profile's live refresh float -> 90 FPS at real-time speed (memclock
1.0x), Wider view x3 (44 -> ~150 degrees). Details: `plans/profiles/BCUS98259-shadow-notes.md`.
Release zip `rpcs3-v0.0.42-vr2-334d5e1c_win64.zip` (2026-09-25). The first vr2 build (f44b619e) showed Ico's
menus unscaled (not in the HUD box). SotC's HUD keep-depth (z scaled by w'/w, ad01b9083) applied to every game;
it is now the profile flag `screen_space.hud_keep_depth` (SotC only). But the Ico failure then recurred on the
first run of a fresh install of 06f95396 and was gone on the second run with no changes: it tracks the empty
shader cache (draws through the shader interpreter until compiled?), not keep-depth. Untested hypothesis:
"Shader Interpreter only" should reproduce it every time. Shipped as a known issue in vr-games.md (Ico).
Tag `v0.0.42-vr2` still points at f44b619e: move it to 334d5e1c before publishing (a forced tag push).

**Profile generator and Demon's Souls (2026-09-25, after vr2; fork commits 5052f024..bb248cd7, not pushed).**
The generator now writes frame rate (`max_fps`/`default_fps`/`vblanks_per_frame`), handles camera-relative
engines (indexed-constant programs, origin cameras), HUD blocks without a z slot and HUD blocks shared with
post passes (`hud_skips_passes`), and always writes `eye_offset: "baseline"`. New renderer flags:
`clip_space_scene_draws` (experimental, unused by shipped profiles), `hud_skips_passes`; fixed-box HUD draws
without depth test get z = w/2. Demon's Souls (BLUS30443) generated from scratch renders correctly in the
headset (desktop captures of the headset session); Wider view patch at 130 degrees. Details and known issues:
`plans/profiles/BLUS30443-notes.md`. To check in the headset before the next release: WipEout and Pure HUD
(renderer HUD changes), Demon's Souls menus and play.

**Ridge Racer 7 (BCAS20001, 2026-09-25, fork bbc406ae, not pushed).** Generated from scratch: camera `c[4]`, HUD
found by the new matrix-less HUD detection (`passthrough_hud` + `hud_programs`), metres. The simulation is
frame-locked (1.49x speed at 90 Hz); benchmark 140 FPS stereo at 300% (vblank 144), no performance work needed.
**2026-09-26, fork f6c31d0d (pushed): runs at the headset rate.** Patch "Frame rate follows VR"
(`bin/patches/BCAS20001_patch.yml`, on by default) plus the new profile fields `game_frame_time_f32`,
`game_frame_ms_u32`, `game_fps_u32`; profile `max_fps 0`, `default_fps 0`. Measured at 90 Hz: physics, race timer,
lap/race/time-limit clocks 0.99-1.0x real time; 60 Hz unchanged; 2D vs VR same-moment captures match. New dev
hooks: PPU read watch, in-run watch file, full-range memory dumps. Not yet checked in the headset. Open:
screenshot crash in a headset session with no profile; a full race to the finish (the test driver stalls on a
wall). Details: `plans/profiles/BCAS20001-notes.md`. Demon's Souls profile eye_baseline
now 0.064 (metres rule).
**2026-09-26, fork 50f7c0ea:** headset report fixed on the desktop: wheels and light glows were head-locked
(scaled object matrices rejected by `require_rigid_camera`; now off, and the generator no longer sets it from
depth-tested scene draws); Xevious loader and intro movies black in the right eye (right-eye surfaces never
initialized, stale depth; renderer now initializes them on bind, affects every game). To check in the headset:
wheels/lights at the countdown, movies, and one other game for regressions from the surface change.
**2026-09-26, fork 243a7ad2:** start-grid frame drops fixed: the right eye rebuilt the car reflections' cube map on
every draw (36 uncached copies a frame); off-aspect copies are now shared with the left eye. Grid countdown
88-90 FPS at 400% in headset mode (was 49-61). New tools `tools/threadcycles.py`, `tools/rsx_sample.py`.
Headset check pending; the change applies to every game (copies from off-aspect targets).
**2026-09-26, fork 6e0d69cd:** scene sharpness at high resolution scales: the scene-resolve filter's tap offsets
(vertex constants in texture coordinates) now scale with the resolution via the new profile field
`resolution_scaled_constants`; 600% scene gradient energy x1.9-2.2. Stereo screenshots keep full resolution.
**2026-09-27, fork 50896fa2 + c480a370 (pushed, headset-confirmed by Matt):** road/wall reflections and light
glows no longer follow the head (profile `offaspect_player_views`, `bare_projection` off; generator writes
`bare_projection` only without depth test). Ridge Racer 7's known VR issues are all fixed; open: an intermittent
menu-video freeze during unattended captures (notes).

**OFXR Bridge frame generation and SotC head-turn swim (2026-09-27, fork cd2dfff4, 44a6613f, c14aaeef, not
pushed; headset-confirmed by Matt).** OFXR Bridge v0.2.7 (OpenXR implicit layer, `%LOCALAPPDATA%\OFXR Bridge`,
tray option "Vulkan support") never engaged: SteamVR's `xrGetVulkanDeviceExtensionsKHR` count is two bytes past
the text and OFXR appends `VK_KHR_external_semaphore_win32` after the first NUL, so we never enabled it. We now
read the whole buffer; eye swapchains also take TRANSFER_SRC (OFXR `vkCmdCopyImage`s each eye). OFXR is fixed
2x: it throttles the app's `xrWaitFrame` to half the refresh, and RPCS3's game clock does not follow
`xrWaitFrame`, so the game must run at exactly half the refresh (new VR Frame Rate "45 FPS" at 90 Hz, or 60 at
120 Hz) or frames are dropped unevenly (judder). Its flight logs (`RuntimeLayer\v336\*.log`) show
`swapchain_eligibility result=0` when armed. WipEout at 425% (5440x3060 eyes) failed: SteamVR
`vkAllocateMemory -2` for OFXR's private swapchains. Worth reporting upstream: the embedded-NUL append.
SotC, with or without OFXR: the world slid on head turns and snapped back when the head stopped. SotC displays
the scene drawn two frames earlier, re-aimed by `vr_realign_blend_targets`; its whole-pixel shift was exact only
at the view centre (a rotation moves the edges up to 2x as far at ~90 degrees). Now an exact homography warp
(`vr_homography_warp_pass`); trace `A{addr:dx,dy h}`. Ico uses the same path: recheck Ico in the headset.

**SotC camera bounce (2026-09-27, fork 1cb72c1f + 16a7e549, not pushed; headset-confirmed by Matt).** The camera pushed into walls and snapped back: the Wider view patch's 3x FOV reached the camera framing logic. Patch 1.2 gives that logic fov / Scale and keeps the render view wide. New dev hook `RPCS3_VR_POKE=<file>` (lines `<addr> f32|u32 <value>`; code too under the static interpreter) for trying patches on savestates, which keep their old code. Details: `plans/profiles/BCUS98259-shadow-notes.md`; trap added to the playbook.

**vr3 release (2026-09-27).** Tag `v0.0.42-vr3` at fork 5b6ddf80 (openxr pushed), zip `release/rpcs3-v0.0.42-vr3-5b6ddf80_win64.zip` (271 files; vr2 + Ridge Racer 7 and Demon's Souls profiles/patches). Since vr2: Ridge Racer 7 playable, SotC exact realign warp and camera-bounce fix (Wider view 1.2), OFXR Bridge frame generation + 45 FPS option, Demon's Souls profile, generator improvements. vr-games.md: OFXR section; WipEout no longer claims the 2.51 update is required (Matt: not true). Smoke test: packaged exe starts (first-run dialog) and carries vr3-5b6ddf80. Matt tests and publishes.

**Demon's Souls depth of field off (2026-09-27, fork 5274a303, not pushed; headset-confirmed by Matt).** The "translucent HUD blur" Matt saw on the floor and the top of the view was the game's depth of field, whose blur grows from the screen centre (so it covered the headset's wider view). New profile field `fragment_constant_overrides` (vertex program, fragment constant, value); BLUS30443 sets the DoF composite `73cbac9f` `fc[0]` = 0. Checked on the headset path with the SHOT hook (both eyes sharp, HUD intact). Details: `profiles/BLUS30443-notes.md`. `launch.ps1` now sets `RPCS3_VR_SHOT`.

**Demon's Souls at the headset rate (2026-09-27, fork 2801eea39, not pushed).** Community Unlock FPS carried in `BLUS30443_patch.yml` (on by default), profile `max_fps`/`default_fps` 0; running and roll distances equal at 60 and 90 FPS (`profiles/BLUS30443-notes.md`). Demon's Souls added to `vr-games.md` as game 6. `launch.ps1` sets `RPCS3_VR_KEYS` (`$Work\KEYS`). To check in the headset: combat and falling at 90.

**Left-eye particles (2026-09-28, fork 2dc5848f, not pushed).** Demon's Souls soft particles (glows, torch flames) drew with other draws' sprites or stretched in the left eye in about half the frames. The left eye's vertex env push constant was lost when the right-eye batch ran mid-draw; now pushed after the render pass change. Affects every game with right-eye batching. Details: `profiles/BLUS30443-notes.md`. Open: in-engine cutscenes jerky (Matt; needs a cutscene savestate).

**Demon's Souls fog gates, HUD box clipping (2026-09-28, fork 2f18a88b..1c5d9a61, not pushed).** HUD-box draws are clipped to the box (game scissor mapped per eye): parked off-screen HUD elements no longer show. Profile camera block `c[4]` for the fog gate distortion layer (was head-locked). Dev hook `RPCS3_STATS_PERIOD_MS`. Cutscenes still 30 FPS (time-based cap; investigation in `profiles/BLUS30443-notes.md`). Black title menu not reproduced.

**Demon's Souls cutscenes (2026-09-28, fork 77382a4b + 2045a8c7, not pushed).** The "30 FPS cutscenes" are pre-rendered videos: no draws and no game flips while they play; RPCS3 re-shows the display buffer by its UI refresh (~31/s). Cannot be unlocked. They now play on the fixed screen in the headset (UI refreshes during a >200 ms flip gap count as frames without camera draws; profile `frames_without_3d_as_screen`). New dev hooks: `RPCS3_VR_PEEK`, `RPCS3_PPU_SAMPLE_STACK`, `RPCS3_PPU_WATCH_EVERY`. To check in the headset: the video screen, and the switch back at the end of a cutscene.

**Demon's Souls in-engine cutscenes (2026-09-28, fork 5f274fb3, not pushed).** Correction to the entry above: 1_5 has a short video and then an in-engine cutscene, whose tracks were sampled nearest-key at 30 Hz (camera still on 2 of 3 frames at 90 Hz). New patch "Smooth cutscenes" (calloc cave interpolating the sampler) and video frames now published to the headset's fixed screen. Needs a fresh boot. Open: portal doubled in the headset (not reproduced on the desktop); character animation in cutscenes not checked.

**Demon's Souls fog gate portal (2026-09-28, fork d7a597e54, not pushed).** The doubled portal was the distortion layer on the game camera: its block `c[4]` fails the rigid test (object scale folded in). New profile field `nonrigid_camera_blocks`; BLUS30443 `[4]`. Verified on the headset path (same pose, before/after).


**vr4 release (2026-09-28).** Tag `v0.0.42-vr4` at fork 607086ef (openxr pushed), zip `release/rpcs3-v0.0.42-vr4-607086ef_win64.zip` (277 files). Since vr3, all Demon's Souls: depth of field off (`fragment_constant_overrides`), unlocked frame rate at the headset rate, left-eye particle fix (affects every game with right-eye batching), HUD-box draws clipped to the box, fog gate layer (`nonrigid_camera_blocks`), smooth in-engine cutscenes patch, pre-rendered videos on the fixed screen; plus the VR settings guide (`vr-settings.md`). Smoke test: packaged exe starts (first-run dialog) and carries 607086ef. Still unchecked in the headset: Demon's Souls combat/falling at 90, cutscene video screen and switch back. Matt tests and publishes.

**vr5 release (2026-09-29).** Tag `v0.0.42-vr5` at fork aaef58ad (openxr pushed), zip `release/rpcs3-v0.0.42-vr5-aaef58ad_win64.zip` (279 files). Since vr4: Bayonetta playable at the headset refresh rate (profile with `row_vector_blocks`, `linked_camera_blocks`; patch *Unlocked frame rate (real-time above 60 FPS)*, confirmed by Matt in the headset); right-eye twins for blit destinations the left texture cache promotes to render targets; stereo RSX-thread cuts (per-primary secondaries, per-frame profile cache, dynamic state reload only on change); generator fixes (xyw, row/linked/nonrigid blocks, camera position precision); GT5 (BCUS98114) parked in `vr-non-working/` (not ready). vr-games.md notes Bayonetta's menu glitches and the screen-space magic wisps. Smoke test: packaged exe starts (first-run dialog) and carries vr5-aaef58ad. Matt tests and publishes.

**OFXR v365 still needs the whole-buffer extension read (2026-09-28).** Reverting to the C-string parse with OFXR Bridge v365: 6 instance / 7 device extensions, no `VK_KHR_external_semaphore_win32`, no `vulkan_interop` or private swapchains in the flight log (no frame generation). With the fix: 7 / 8, semaphore_win32 used, `swapchain_eligibility result=0`. OFXR's own negotiation record is unchanged (`vulkan_negotiation result=3 a=7 b=125 c=189`), so the extensions still sit past an embedded NUL. The fix stays.

**Generic work from GT5 (2026-09-29, fork e1648a6dd..dcb87dde3).** Four new `screen_space` options for games that
draw HUD and menus straight into display buffers: `hud_display_buffers_only`, `hud_box_after_shader`,
`output_pixel_draws_not_hud`, `subviewport_cameras_in_box` (`profiles/README.md`). GT5 itself: `6-wip-games.md`.

**Night of 2026-09-30: Killzone HD (desktop only; shipped in vr6).**
- **Killzone HD (BCES01743):** needs Write + Read Color Buffers (world black otherwise). Patch "Frame rate 90 FPS"
  (tick rate fps/1000 and step factor 30/fps; 60/72/120 variants): 90 FPS, clocks 1.00x. Generated profile
  (`row_vectors c[256, 258]`, HUD c[256], metres); stereo, yaw and pitch audits clean; 88-90 FPS stereo at 300% on
  the headset path. `profiles/BCES01743-notes.md`.
- **Generic, from GT5 and MotorStorm (see `6-wip-games.md`):** unimplemented FP opcodes (POW, BEM class,
  TIMESWTEX) log instead of throwing (garbage programs had reached the shader cache); RSX-side render-target
  readbacks join the stereo early-copy list; off-aspect mip-chain gathers are shared by the right eye.

**vr6 release (2026-09-30).** Tag `v0.0.42-vr6` at fork c39a80e6 (openxr pushed), zip `release/rpcs3-v0.0.42-vr6-c39a80e6_win64.zip` (281 files). Since vr5: Killzone HD (BCES01743) playable as game 8 (90 FPS patch, VR profile; needs Write + Read Color Buffers, documented in vr-games.md; film grain hidden via profile `hidden_draws`, reticule at 35% via `scaled_draws`, HUD at 4 m via `hud_depth`, movies at 60 via `video_vblank_rate`, full-resolution left eye via `keep_rendered_display_buffers`, no head-turn ghosting via `reproject_older_frames`). Generic: HUD Depth setting (Auto = profile, else 2 m; home menu slider), projection layer from the first frame (menus world-fixed and 16:9 before any 3D), HUD box from the first headset frame with a validated FOV, headset overlay renderer's built-in images (button icons), depth test with no depth buffer/ALWAYS no longer keeps HUD z, RSX-side readbacks copied early before the right eye, faster camera-block slot lookup, off-aspect mip-chain gathers shared, unimplemented FP opcodes logged instead of fatal. MotorStorm moved to vr-non-working/ (stereo frame rate at race starts). Smoke test: packaged exe starts (first-run dialog) and carries vr6-c39a80e6. Matt tests and publishes.

**vr7 release (2026-10-02).** Tag `v0.0.42-vr7` at fork 22458e7b (openxr pushed), zip `release/rpcs3-v0.0.42-vr7-22458e7b_win64.zip` (284 files). New playable games (Matt: ready): **Tales of Xillia** (BLUS31006: profile + fork patch *Frame rate follows VR*, on by default, with the community *60 FPS*; menus on the fixed screen; 120 Hz sustained at 300%) and **Super Stardust HD** (NPUA80068, PSN: real-time without a patch, front end on the fixed screen via the new key `screen_frames_when`; 120 Hz). God of War Collection and Killzone 2 profiles moved from `bin/` to `vr-non-working/` so they do not ship. Generic since vr6: profile keys `screen_frame_draws`, `screen_frames_when`, `boxed_cameras` (replaces `boxed_camera_programs`), `camera_palette`, `texture_redirects`, `game_frame_ms_f32`, `game_vblank_frames_f32`, `game_camera_programs`, stereo `eye_offset: baseline_per_w`; frames without 3D on the fixed screen by default; RSX-thread stereo cost work; stencil-only clears no longer copy left depth to the right eye; flip uploads kept alive until the next flip; generator improvements (rigid cameras for sheared matches, per-object blocks, camera palettes); dev hooks FRAMESTATS, FAKE_HMD, SAVESTATE. Smoke test: packaged exe starts (first-run dialog) and carries vr7-22458e7b. Matt tests and publishes.

**New titles triaged (2026-09-30):** Uncharted, God of War Collection, Killzone 2: results and state in
`6-wip-games.md`. Generic changes from that work: profile field `screen_space.offaspect_projection` (and its
generator detection); `max_fps 0` multiplies the headset rate by `vblanks_per_frame` (fork d12f50a6e).

- **Boot crash in flip, fixed (fork 4704701a2).** `upload_image_simple` disposed the flip's uploaded display buffer at
  once; any submit before the present blit freed it, crashing in `VKGSRender::flip` -> `scale_output` (image
  `push_layout` or inside the NVIDIA driver) at boot loading screens: Uncharted 2 of 2 boots with Frame limit Auto,
  Killzone 2 once in a stereo audit, and the first SHOT screenshot at Uncharted's boot. The uploads are now kept until
  the next flip; Uncharted with Auto survives 2 of 2. Minidumps in `%LOCALAPPDATA%\CrashDumps` were read with
  `tools/re/dmpstack.py` + `tools/re/sym.py` (no debugger on this machine).

**Generic, from Dragon's Dogma (2026-09-30; game state in `6-wip-games.md`).**
- Clear mirroring copied the whole depth-stencil image into the right eye for a depth-only or stencil-only clear.
  A game that clears only the stencil between passes (Dragon's Dogma, before its light volumes) had its right-eye
  depth replaced by the left eye's: large black areas in the right eye wherever the scene shifts. Only the cleared
  aspects are copied now. Affects every game.
- Profile flag `camera_slots_read_directly` (bone palettes in whole-bank programs no longer match camera blocks);
  the generator writes it when it sampled indexed programs.
- Dev hooks: `RPCS3_VR_RTDUMP` dumps depth surfaces too, and `prog=<vertex hash>` in the request dumps just before
  that program's next draw (both eyes); probe `gamecam=<hash>[+<hash>]` keeps programs on the game camera.

**Generic, from Anarchy Reigns (2026-10-01; game state in `6-wip-games.md`).**
- Generator: the camera test rejects a projection with A > 30 (under 3.8 degrees: a HUD ortho read as x/y/w rows
  had won); when bare projections are most camera draws they set the projection and near plane (object-scaled MVPs
  gave near 0.0017); camera blocks that no sampled draw binds are left out; the HUD search covers output-aspect
  targets when `camera_target_aspect` differs; HUD draws sampling a small render target write `hud_box_after_shader`.
- Renderer: the HUD box applies on output-aspect targets as well as view targets; a HUD draw is a pass for
  `hud_skips_passes` only when it samples a view-shaped target (new texture kind `vr_texture_view_target`); the
  after-shader HUD box works with `RPCS3_VR_FAKE_HMD`. (A change that stopped host instancing of draw clauses
  while VR renders was reverted: it did not fix what it was made for, and a count over 17 games' savestates found
  no instanceable clauses in VR, so it had no tested use.)

**Generic, from Dante's Inferno (2026-10-01).** Profile key `game_frame_ms_f32` (float milliseconds per frame,
written with 1000/fps). Generator: a depth-less draw whose first matching camera block is strongly sheared
(|cos| > 0.5) is stray data, so it writes `require_rigid_camera` (the HUD's UV/colour parameters in a camera
block's slots had vanished the HUD in stereo).

**Generic, from The Darkness and Dragon's Dogma (2026-10-01, fork 25ccbbe91).** Bare-projection quads that sample
any colour render target, or (desktop stereo) have no rejecting depth test, are passes left as drawn (post chains,
LUT builds); the passthrough HUD accepts draws
sampling small render targets; the fake headset records camera targets; dev tools: probe `why=<hash>`,
RTDUMP of RGBA16F targets and `prog=<hash>#n`.

**Generic: RSX-thread cost of stereo (2026-10-01, uncommitted build under test by Matt; games in `6-wip-games.md`).**
The RSX thread is the stereo bottleneck in draw-heavy games: measured cycle-exact, Ratchet & Clank 1 used 13.2 ms
of a 15 ms frame at 72 Hz (7.2 ms flat). Changes, each A/B-measured on the same savestates at 72 Hz, 4K per eye
(`tools/re/vr_ab.sh`, `evidence/vrperf/`, index in `evidence/vrperf/README.md`):
- The eye constants' CPU scratch is filled with ordinary stores. `fill_vertex_program_constants_data` streams
  (non-temporal stores, right for the write-combined ring); the camera classification then read the streamed
  buffer straight back, stalling on memory twice per draw. R&C 1 12.5 -> 10.9 ms, R&C 3 10.2 -> 9.2 ms.
- Camera slots are found by binary search in the program's sorted `constant_ids` (an 8-entry cache of
  468-entry tables thrashed). R&C 1 13.2 -> 12.8 ms.
- The right eye's attachment list is copied into a member vector instead of reallocating per draw; dev trigger
  files (SHOT, MEMDUMP, POKE, WATCH, RTDUMP, the probe file) are checked at most every 100 ms (test runs only).
  R&C 3 11.9 -> 10.2 ms.
- Vertex-program ucode hash cached per compiled program for the VR checks; `camera_probe::get()` inline (small).
- Profile key `zcull_approximate` (ZCULL Accuracy "Approximate" while VR renders): Dragon's Dogma waited 41% of
  its RSX thread for exact occlusion counts covering both eyes' GPU work. 13.9 -> 7.8 ms.
- Measurement: `RPCS3_VR_FRAMESTATS` logs the RSX thread's CPU ms per frame (`QueryThreadCycleTime`; the GPU
  profile's field used GetThreadTimes and undercounted by more than half, now fixed too); `RPCS3_RSX_SAMPLE=1|2|3`
  in-process sampler with inline-aware source lines. Playbook: "Finding and measuring RSX-thread cost".
- Remaining stereo cost in R&C 1: ~2.5-3.5 ms per frame over flat, mostly recording each draw a second time
  (driver time, descriptor sets, push constants). Further large cuts need Vulkan multiview (Gate 6 item).
- Not yet done: a full `vr_regress.sh` pass on this build (stopped after R&C 1 and R&C 2 for Matt's testing).
