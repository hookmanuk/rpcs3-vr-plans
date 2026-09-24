# VR profile format (schema 1)

A game gets VR when `rpcs3/bin/vr_profiles/<TITLE_ID>.json` exists and is valid. The file holds
only what the renderer reads; this page explains the fields. Loader:
`rsx::vr::load_title_profile()` in `rpcs3/Emu/RSX/Capture/rsx_camera_probe.cpp`. An invalid file is
logged (field, line, column) and the game runs in 2D; unknown keys are logged as warnings.

Measurements and reasoning behind WipEout's values:
`plans/profiles/BCES00664-evidence.json` (and `plans/evidence/gate4/analysis-stereo-fit.txt`,
`tools/fit_stereo.py`).

| Field | Required | Meaning |
|---|---|---|
| `schema` | yes | Format version; must be `1`. |
| `title_id` | yes | Must match the file name. |
| `app_version` | no | Game version the values were fitted on; a mismatch is logged, not rejected. |
| `matrix_layout` | yes | How a 4-slot matrix is stored. `row_vectors`: `clip = v.x*c[b] + v.y*c[b+1] + v.z*c[b+2] + c[b+3]`, so each slot is one row; column 0 gives clip.x, column 3 gives clip.w (WipEout). `column_vectors`: `clip[i] = dot(c[b+i], v)`, the transpose, as PSGL/Cg DP4 code does (Pure); the renderer transposes such a block, runs the same math, and writes it back. A DP4 program may omit the z slot and take clip z from the w row (Pure's sky: `c[26]`, `c[27]`, `c[29]`); the block is then used with z = w. | `column_vectors_xyw`: a DP4 camera of three slots, clip x, y and w at `b`, `b+1`, `b+2`, with z derived by the shader (NFS Most Wanted: `c[212..214]`, z parameters in `c[215]`).
| `camera_blocks` | yes | Vertex constant slots of 4-slot camera matrices, tried in order. The first whose column 3 is not `(0,0,0,1)` (i.e. perspective) is the draw's camera. WipEout: 256 is world-view-projection on its single-matrix route; 260 is view-projection on its two-matrix route, where 256 is an affine world matrix. | An entry can also be an explicit list of the block's 4 slots when they are not contiguous: MGS4's camera-relative draws use `[0, 1, 2, 7]` (translation row in `c[7]`).
| `require_rigid_camera` | no | `true`: a camera block counts only if its clip x, y and w directions are mutually orthogonal (within 0.1). Pure: keeps `c[39..42]`, which holds unrelated data in a post-process quad, from being taken as a camera. Off for WipEout, whose per-object matrices can be non-uniformly scaled. |
| `require_camera_aspect` | no | `true`: a camera block must also project square pixels at the output aspect (|clip y| / |clip x| within 10%). For engines whose camera base varies with the number of object-matrix slots before it (inFamous 1 and 2), where `camera_blocks` lists overlapping bases and some other block can pass the perspective and rigid tests. The generator sets it when it keeps overlapping blocks. |
| `output_aspect_tolerance` | yes | A draw is a camera view only if its render target's aspect is within this fraction of the output aspect. WipEout: excludes the 512x256 shadow cascades, whose perspective 260 block is shared between eyes. |
| `camera_target_aspect` | no | Aspect of the render targets that hold camera views when it is not the output's. MGS4 renders its 16:9 picture anamorphically into 1024x768 targets: 1.33333. The generator sets it from the target size with the most camera draws. |
| `camera_position.slot` | no | Slot holding the camera world position. Each eye moves it by `eye_baseline / 2` along camera right on every draw that reads it (shadow cascades included). |
| `camera_position.eye_baseline` | yes | The game's native distance between the eyes, in world units. Also the world scale for head tracking: `eye_baseline` units = the viewer's IPD. |
| `stereo.formula` | yes | Only `clip_x_shear`: `clip.x += sep * (clip.w - conv)` per eye, `sep = -/+ per_eye_separation`. The headset path keeps only the translation term (`-sep * conv`). |
| `stereo.per_eye_separation`, `stereo.convergence` | yes | The default shear. |
| `stereo.by_target_width[]` | no | Overrides for render targets exactly `output_width / output_width_divisor` wide. WipEout's 640x360 pass uses 0.75x the full shear, not 0.5x. |
| `screen_space.orthographic_block` | no | An output-aspect draw with no perspective camera block but an orthographic matrix here is HUD/menu, drawn in the fixed HUD box. |
| `screen_space.bare_projection` | no | `true`: a perspective camera block with no view rotation or translation folded in is also screen space (WipEout's main-menu particle cloud). |
| `screen_space.depth_offset_projection` | no | `true`: a perspective camera block with no view rotation and only a translation along the view axis (`w = z + d`, d != 0) is screen space too: geometry drawn in the camera's own space at a fixed depth. Blur's 3D HUD (`w = z + 42.65`). Separate from `bare_projection` because Blur's deferred light volume is an exact bare projection that must follow the head. |
| `game_camera_target_widths` | no | Render targets exactly this wide (guest pixels) keep the game's camera in both eyes: views that are not the player's own. Blur's rear-view mirror (320x180). |
| `screen_space.rotation_only_passthrough` | no | `true`: a draw **without depth test** whose camera block has no translation at all (clip w = view z) is a full-screen pass building view rays from it (inFamous 2's final composite). It follows head rotation but gets no eye offset, head translation or stereo shear. The depth-test condition matters: inFamous 2 also draws world geometry camera-relative with such blocks. |
| `screen_space.preprojected_programs` | no | List of vertex-program ucode hashes (hex strings, as in inspector captures) whose positions the game projected itself (ICO's flames: NDC with w = 1). Their draws get `B^-1 * B_eye` of the latest camera block for each eye, so they follow the head, eye offset and FOV remap like the camera draws. |
| `reference_screen_width` | no | Width in metres of the screen the game's stereo is tuned for (WipEout: a 24" TV, 0.53 m). Fixed Screen scales separation by reference / window width so far objects keep the same physical disparity. 0 or absent: no scaling. |
| `match_headset_refresh_rate` | no | `true`: the game keeps real-time speed when its vblank rate changes, so Video > VR > "Match Headset Refresh Rate" is offered (on by default) and the emulated vblank follows the headset's refresh rate while a headset runs. The saved Vblank Rate is not modified. Absent/`false`: the option is shown disabled. Check before setting it: WipEout's lap timer advanced 75.0 s in 75.03 s of wall time at 90 Hz. |
| `current_frame_copies` | no | `true`: the game composites the previous frame's scene with effects built from the current one (ICO: the scene double buffer left over from SPU MLAA, bloom from this frame). Each frame carries its own head rotation, so in the headset the two layers disagree (white glow trailing head turns). A blit whose source is a scene target drawn with an earlier pose reads its twin (same size, format, pitch) drawn in this frame. Also removes a frame of latency. Do not set it for games that read the previous frame on purpose (motion blur, frame blending). |

Not yet in the format: WipEout's infinity layers (sky/skyline) use convergence 0 natively and are
still drawn with the default rule (see the evidence file, `stereo.variants_seen`).

A game whose engine needs another `matrix_layout`, `stereo.formula` or screen-space test needs that
rule added in code under a new name; the loader rejects values it does not know.
