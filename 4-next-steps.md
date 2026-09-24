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

## Third title: Split/Second (BLUS30300) frame-rate patch (2026-09-23)

Hand-made patch `plans/profiles/BLUS30300-patch.yml` (installed as `bin/patches/BLUS30300_patch.yml`,
Refresh Rate 90, `config_BLUS30300.yml` Vblank Rate 90). Same PSGL swap-interval sites as Pure, plus the
game's own dt: it runs one 1/60 s tick per vblank, so the patch makes `dt = ticks / Refresh Rate`. Game
time measured at 1.00x wall time at 90/90 (1.50x at 90/60). Details: `plans/profiles/BLUS30300-notes.md`.

An in-emulator "generate frame-rate patch" button was considered and dropped: the swap-interval half is
a findable PSGL pattern, but the game-speed half is engine-specific code (here a tick-count dt in
`0x509a4`), so it can't be generated reliably.

## Five more titles: Blur, inFamous, inFamous 2, MGS4, NFS Most Wanted (2026-09-23/24)

Profiles in `bin/vr_profiles/`, notes in `plans/profiles/<TITLE_ID>-notes.md`, evidence in
`plans/evidence/{blur,infamous,infamous2,mgs4,nfsmw}/`. All desktop-verified (stereo + yaw audit); none
run in the headset yet.

| Title | VR profile | 90 FPS |
|---|---|---|
| Blur BLUS30295 | yes | patch `BLUS30295-patch.yml` (flip every vblank); real-time clock; 80-84 mono / 45-50 stereo at 90 |
| inFamous BCUS98119 | yes | no patch needed (uncapped, real-time); load-bound ~55 mono |
| inFamous 2 BCUS98125 | yes | no patch needed; 52-72 stereo at 90 |
| MGS4 BLUS30109 | yes | patch `BLUS30109-patch.yml` (one vblank per frame); real-time; 90 mono in Virtual Range, 45 in Act 1 |
| NFS MW BLUS31010 | yes | patch `BLUS31010-patch.yml` (flip gate + timer pacer + 1/rate sim step via code cave); 90 FPS; see `plans/6-five-titles-status.md` |

Renderer/profile-format additions (documented in `plans/profiles/README.md`): scaled-blit mirroring
(`texture_cache::blit_vr_right`), partial-clear mirroring, right-eye rebuild of deferred texture copies,
`column_vectors_xyw`, `require_camera_aspect`, `camera_target_aspect`, explicit slot lists in
`camera_blocks`, `game_camera_target_widths`, `screen_space.depth_offset_projection` (incl. x/y-shifted
planes) and `screen_space.rotation_only_passthrough`. Generator: three layouts, 5% view-target tolerance,
overlapping blocks, anamorphic targets, reversed-depth near plane, 200x world-scale clamp.

Dev hooks (environment variables, for unattended runs): `RPCS3_VR_GEN_TRIGGER`, `RPCS3_VR_KEYS` (key
script into the keyboard pad), `RPCS3_VR_SHOT` (screenshot, both eyes when stereo), `RPCS3_VR_MEMDUMP`
(guest memory snapshot), `RPCS3_USLEEP_STATS`; inspector captures now include blit/NV0039 notes.

Not yet done: headset runs; NFS 30 FPS limiter; inFamous 2's SPU-processed layer is left-eye only;
restore `Audio: Cubeb` and remove the temporary keyboard pads in `input_configs/<id>/`; commit.

Current state and headset-test instructions: `plans/6-five-titles-status.md`.

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
