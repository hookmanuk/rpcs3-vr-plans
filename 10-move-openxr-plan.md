# PlayStation Move from OpenXR controllers

Plan for a new Move handler that drives the PS3's Move API (`cellGem`) from the headset's own motion
controllers, so that Move games (light-gun shooters, Sports Champions, Sorcery) can be played in VR
without a PS Eye or real Move controllers. Written 2026-10-05 against fork commit `9373d21` on the
`openxr` branch of hookmanuk/rpcs3. **Status: draft, nothing implemented.** Evidence labels as in
[3-investigation.md](3-investigation.md): `[SOURCE]` verified in the checked-out code, `[SPEC]` from
the OpenXR specification (re-check during bring-up), `[INFERENCE]` expected but not yet proven.

## 1. Why

- Move is the one PS3 input that already describes a hand in 3D. A VR controller can supply it more
  accurately than any existing RPCS3 Move source.
- Today a VR player can't use a Move game in any practical way. `real` needs a PS Eye and Move
  controllers and a view of the TV. `fake` and `mouse` invent orientation from a 2D cursor, and `gun`
  is Linux-only (evdev).
- The Move library includes some of the PS3's best-suited VR content: Time Crisis: Razing Storm, House
  of the Dead: Overkill Extended Cut, Dead Space Extraction, Killzone 3, Resistance 3, Sports Champions
  1/2 and Sorcery.

## 2. How Move reaches a game today `[SOURCE]`

All in `rpcs3/Emu/Cell/Modules/cellGem.cpp` unless noted.

- `g_cfg.io.move` selects the handler: `null`, `real`, `fake`, `mouse`, `raw_mouse`, `gun`
  (`Emu/system_config_types.h:141`). Each `switch (g_cfg.io.move)` in `cellGem.cpp` handles
  connection, calibration, state, image state and ext/buttons per handler. The UI name is in
  `rpcs3qt/emu_settings.cpp`, the string in `Emu/system_config_types.cpp` and the cursor handling in
  `rpcs3qt/gs_frame.cpp`.
- `cellGemGetState` (line 3420) fills `CellGemState`: buttons and trigger (`*_input_to_pad`), then pose
  (`*_pos_to_gem_state`). The `flag` / `time_parameter` arguments (state at a given time) are ignored
  (TODO in the code).
- `pos_to_gem_state` (line 1844) is shared by every handler. It takes a **2D image position**
  (x, y in camera pixels) plus `controller.distance_mm` and `controller.radius`, and rebuilds the 3D
  position from those (`mmPerPixel = CELL_GEM_SPHERE_RADIUS_MM / radius`). Orientation comes from
  `move_data.quaternion` for `real` (and `fake` with orientation enabled). Otherwise it is synthesised
  from the cursor position inside a cone (`fake_move_rotation_cone_h/v`). `handle_pos` is the sphere
  position minus the quaternion-rotated 45 mm handle offset. Velocity and acceleration are
  differentiated from position (`ps_move_data::update_velocity`; IMU velocity is off because of drift).
- `cellGemGetImageState` (line 3190) gives the 2D sphere position in the camera image
  (`pos_to_gem_image_state`).
- Calibration (`cellGemCalibrate`, line 2737) is a 0.5 s timer that ends in
  `CELL_GEM_FLAG_CALIBRATION_SUCCEEDED` (`update_calibration_status`).
- Coordinate frame (`cellGem.h:243`): origin at the camera centre, **x to the right as the user faces
  the camera, y up, z towards the user**, in mm. Quaternion relative to "facing the camera, buttons
  up". `ps_move_data::default_quaternion` is identity.

OpenXR side (`rpcs3/Emu/RSX/VK/VKOpenXR.{h,cpp}`): the loader is loaded at runtime, there is one
`XrSession`, a `LOCAL` reference space plus a `VIEW` space, and a dedicated frame thread runs
`xrWaitFrame` / `xrEndFrame` and polls events. **There are no action sets, actions or
interaction-profile bindings yet.** The fixed screen (`set_screen`) and overlay quad
(`set_overlay_placement`) are placed in `LOCAL` space by width, x, y and distance.

## 3. The core observation

The `cellGem` frame and OpenXR's `LOCAL` space have the same handedness and axis meaning for a player
facing −Z: x right, y up, z towards the player. A PS Eye standing in front of the player looks back
along +Z. So **gem space = LOCAL space, translated to a virtual camera position, rotated by its yaw and
scaled to mm**. There is no axis flip, and the neutral orientations match: OpenXR's aim pose points
along −Z with +Y up, which is the Move "pointing at the camera, buttons up" pose. `[INFERENCE]`: check
the x sign against the gem sample or a real Move capture on day one (§7, P0 gate).

```text
p_gem  = 1000 * R_cam^-1 * (p_aim - c_cam)        (mm)
q_gem  = q_cam^-1 * q_aim
v_gem  = 1000 * R_cam^-1 * v_aim                   (XrSpaceVelocity linear)
w_gem  = R_cam^-1 * w_aim                          (XrSpaceVelocity angular, rad/s)
```

`c_cam` / `q_cam` is the virtual PS Eye's pose in LOCAL space (yaw only). §5 covers where to put it,
which is the real design question.

## 4. Design

### 4.1 OpenXR actions (in `VKOpenXR`)

- One action set `move`, created after `xrCreateSession` and before the session begins. Actions:
  - `aim` (pose) and `grip` (pose), subaction paths `/user/hand/left` and `/user/hand/right`
  - `trigger` (float)
  - `move_btn`, `cross`, `circle`, `square`, `triangle`, `start`, `select`, `ps` (boolean)
  - `stick` (vector2, for the Navigation controller, §4.5)
  - `haptic` (vibration output, for Move rumble)
- Suggested bindings for `khr/simple_controller`, `oculus/touch_controller`, `valve/index_controller`,
  `htc/vive_controller` and `microsoft/motion_controller`. Default Touch layout per hand:

  | Move | Touch / Index |
  |---|---|
  | T (trigger) | trigger value |
  | Move button | grip / squeeze (click or value > 0.5) |
  | Cross / Circle | A / B (right hand), X / Y (left hand) |
  | Square / Triangle | thumbstick left / up (as buttons), or thumbstick click / thumbrest |
  | Start | menu (left) |
  | Select | thumbstick click (left) |
  | PS | not bound (the runtime reserves the system button) |

  The face-button pairs follow what the Move button is used for: it is the main "use" button in most
  games, so it goes on the grip, not a face button. SteamVR users can rebind everything in the
  runtime's binding UI, so the defaults only need to be sensible.
- `xrAttachSessionActionSets` once, after the session is created `[SPEC]`: it can't be called twice,
  so the set must be complete at session creation, whether or not the game uses Move.
- **Everything runs on the frame thread.** Each headset frame, after `xrWaitFrame`: `xrSyncActions`,
  then `xrLocateSpace(aim_space[hand], g_xr.space, predictedDisplayTime)` with a chained
  `XrSpaceVelocity`, then read the action states. The results go into a small snapshot struct per
  hand, published under a mutex (or seqlock):
  `{pose, lin_vel, ang_vel, flags, trigger, buttons, stick, display_time, active}`. `cellGem` only ever
  reads the snapshot and never calls OpenXR. This avoids any question of OpenXR calls from the PPU
  thread, and the poses are predicted for display time, which offsets some of the game's input latency.
- `active` = the session is `FOCUSED` and the pose has `ORIENTATION_VALID | POSITION_VALID`. Tracked
  vs. valid maps onto `CELL_GEM_TRACKING_FLAG_VISIBLE` (a controller out of the headset's tracking
  volume reads as "sphere not visible", which is what games already handle).
- Rumble: `cellGemSetRumble` → `xrApplyHapticFeedback` (queued to the frame thread).
- Public API sketch, `vk::xr` namespace:
  ```cpp
  struct hand_state { f32 pos[3]; f32 quat[4]; f32 lin_vel[3]; f32 ang_vel[3];
                      f32 trigger; u32 buttons; f32 stick[2]; u64 display_time_ns; bool active; };
  bool get_hand_state(u32 hand, hand_state& out);   // false if no session
  void set_rumble(u32 hand, f32 amplitude);
  f32  current_head_yaw(); void head_position(f32 out[3]); // for anchoring §5
  ```

### 4.2 The handler (`cellGem.cpp`)

- New `move_handler::openxr` (`"OpenXR"`). It's available when the build has OpenXR, which is every
  fork build. Also add it in the UI.
- Per `switch`:
  - **connection**: gem 0 = dominant hand, gem 1 = other hand (setting: right-handed by default).
    `connected = i < attribute.max_connect && session running`. Gems 2-3 stay disconnected.
  - **calibration**: as `fake`. Additionally, `cellGemCalibrate` / `cellGemReset` re-anchor the virtual
    camera in projection mode (§5.2), which is when games tell the player to "point at the camera".
  - **state**: `openxr_input_to_pad` (buttons, trigger) and `openxr_pos_to_gem_state`.
  - **image state**: project `p_gem` with the PS Eye model below and fill `CellGemImageState`
    (u, v, r, `distance`, visible).
  - **ext**: none (no Sharpshooter or Racing Wheel ext device), or later a "Sharpshooter" toggle.
- `openxr_pos_to_gem_state` writes `pos`, `quat`, `vel`, `angvel`, `handle_pos` directly from §3, and
  differentiates the snapshot for `accel` / `angaccel` (the PS Move API values are noisy anyway). It
  must **not** go through `pos_to_gem_state`: that function's 2D-to-3D rebuild would throw away depth.
  Factor its handle-offset and overlay-cursor tails into helpers that both paths call.
- Sphere vs. aim pose: the Move's sphere is about 10 cm forward of the hand. The aim pose's origin is
  runtime-defined (usually at the controller tip). Add a configurable `sphere_offset` along the aim's
  −Z axis (default 0) and leave the existing 45 mm sphere-to-handle offset.
- PS Eye model, so the 2D values agree with the 3D ones: 640x480. The horizontal FOV is 56° or 75°
  (the PS Eye's two zoom settings; `[INFERENCE]` 75° is what Move games set, check with
  `cellCameraGetAttribute`). `f = 320 / tan(hfov/2)`, `u = 320 + f*x/z`, `v = 240 - f*y/z`,
  `radius = f*22.5/z`. Also update `controller.radius` and `distance_mm` so `paint_move_spheres` and
  the fake camera image still work.
- `cellGemGetInertialState`: the accelerometer is `q_gem^-1 * (a_world + g)` in G and the gyro is
  `q_gem^-1 * w`. Both are in the sensor frame used by `PadHandler.cpp:918-923`. Few games read it,
  but it's cheap.
- Camera: Move games call `cellCamera` too. Keep `camera_handler::fake` (black image plus painted
  spheres). Nothing needs a real image except the AR titles (§8).

### 4.3 Settings

Per game custom config (and home menu VR tab where marked):

| Setting | Default | Meaning |
|---|---|---|
| Move handler = OpenXR | off | Selects the handler (existing I/O tab dropdown) |
| Dominant hand | right | Which hand is gem 0 |
| Camera anchor | auto | `screen` (quad mode), `view` (projection mode), `fixed` (§5) |
| Camera distance | profile, else 2.0 m | How far in front of the player the virtual PS Eye sits |
| Sphere offset | 0 cm | §4.2 |
| Recenter Move (home menu) | - | Re-anchor the virtual camera now |

### 4.4 VR profile keys (`profiles/README.md`, schema 1, all optional)

- `move.camera_distance`: metres. This is also the depth at which aim is exact in projection mode (§5.2).
- `move.camera_height`: metres above (or below) the screen centre or the eye line.
- `move.aim_sphere_offset`: as the setting, for games that aim from the sphere's position rather
  than its ray.
- `move.navigation`: `true` if the game expects a Navigation controller (§4.5).

### 4.5 The Navigation controller (shooters)

Killzone 3 and Resistance 3 (and SOCOM 4, Dead Space Extraction's movement) are played with a Move in
one hand and a **Navigation controller** in the other. The game reads the Navigation controller as an
ordinary pad (stick, L1/L2, Cross/Circle, D-pad), not through `cellGem`. So the off hand needs to
appear as a pad too:

- Option A (first): an `openxr` **pad handler** in `rpcs3/Input/` that exposes the off-hand stick,
  trigger, grip and face buttons as a DS3 on player 1. It reads the same snapshot.
- Option B: tell players to keep a gamepad in the off hand. This needs no work but isn't comfortable
  in a headset.

When `move.navigation` is on, the off hand is the Navigation pad and only gem 0 is connected.

## 5. Making aim line up with what you see

The handler alone makes the game *respond* to the controllers. Whether the shot lands where the
player is pointing in the headset depends on where the virtual PS Eye is relative to what the headset
shows. A Move game assumes a PS Eye on top of (or under) a TV. It intersects the Move's ray with the
TV plane, which it learned from calibration, and that gives it a 2D screen point. Light-gun games
then shoot through that 2D point with the game camera.

### 5.1 Fixed-screen (quad) mode: easy

The fixed screen is a known rectangle in LOCAL space (`set_screen`: width, x, y, distance). Put the
virtual PS Eye at the screen's top centre facing the player: `c_cam = screen centre + (0, h/2, 0)`,
`q_cam` = screen yaw. This is exactly the real living-room geometry, so in-game calibration ("point
at the camera", "aim at the screen corners") works unchanged. The aim matches what the player sees,
within the game's own calibration accuracy. **Start here.**

### 5.2 Projection (headset FOV) mode: needs the game camera

In projection mode there is no TV. The game's 2D frame is spread around the player as the world, and
head rotation is applied on top of the game camera. The trick is to put the "TV" where the game's
2D frame would be if it were a screen:

- At each re-anchor (`cellGemCalibrate`, `cellGemReset`, home menu recenter, OpenXR
  `REFERENCE_SPACE_CHANGE_PENDING`), take the player's current head position and yaw. Define a virtual
  screen there: `D = move.camera_distance` in front, square to the game camera's forward direction,
  and `2 * D * tan(game_hfov / 2)` wide. The renderer already measures the game's FOV from the draws
  each frame (4-next-steps, headset FOV section). Put the PS Eye at its top centre.
- A point the player aims at that sits at depth D then lands on the right 2D screen point, and so on
  the right object. At other depths the error is the parallax between the controller's ray and the
  eye's ray. It's small for targets beyond D and grows for close ones. Light-gun games mostly shoot
  at middle distance, so set D per game (profile key).
- Head turning: the head transform rotates the world in the headset but not the game's camera. So the
  virtual screen stays where it was anchored, and the world under the player's aim is still the
  game's frame at that place. Aim stays correct while the head turns. **But** things outside the game
  camera's original FOV can't be aimed at (the game never drew them as screen points), which matches
  the flat game.
- Games that turn the camera when the cursor nears a screen edge (Killzone 3, Resistance 3 "bounding
  box" aiming) still do so. The world then rotates in the headset without the head moving, which is a
  comfort issue to note per game. These games usually have a bounding-box size option, so set it wide
  in the profile notes.
- An exact correction for depth (cast the controller ray into the game's depth buffer and put the
  cursor where it hits) is possible later, but not part of this plan.

### 5.3 Aim feedback

Most light-gun games draw their own crosshair, so the player sees where the game thinks they're
aiming. A laser or cursor drawn by the fork isn't needed at first. If it is wanted, draw the existing
`show_move_cursor` overlay in the HUD layer.

## 6. Test titles

Pick the first test titles by the shape of their input, not by popularity:

| Title | Why | What it proves |
|---|---|---|
| Time Crisis: Razing Storm (also has TC4, Deadstorm Pirates) | Pure pointer + trigger, fixed camera, own calibration screen | P1: quad-mode aim |
| House of the Dead: Overkill Extended Cut | Pointer + trigger, rail camera | P1 / P2: aim with a moving camera |
| Sports Champions | Two-handed 1:1 position and orientation (table tennis, archery, gladiator) | P3: 6DoF and two gems |
| Dead Space Extraction | Pointer plus wrist-twist (orientation) gestures | Orientation in a light-gun game |
| Killzone 3 / Resistance 3 | Move + Navigation, bounding-box turning | P4: Navigation pad, comfort |

Each needs a VR profile in the usual way ([5-vr-profile-playbook.md](5-vr-profile-playbook.md))
before projection-mode work. Quad mode needs none. Title IDs to be filled in when the dumps are
checked.

## 7. Phases and gates

### P0 - plumbing (no game)

- Action set, bindings, snapshot on the frame thread; `move_handler::openxr`; state, image state and
  calibration paths; settings entry.
- Gate: a debug log (or the `paint_move_spheres` image) shows both hands. Moving the right hand right
  gives +x, up gives +y, towards the face gives +z (decides the x-sign question in §3). Pointing at the
  virtual camera gives an identity quaternion within a few degrees. Disconnecting a controller or
  opening the SteamVR dashboard clears `VISIBLE`.

### P1 - quad mode, one light-gun game

- §5.1 anchoring, then Time Crisis: Razing Storm through its calibration screen.
- Gate: the in-game crosshair stays on whatever the controller points at across the screen, within
  about 2% of screen width. Trigger and reload (Move button) work. No visible lag compared with the
  head-locked view.

### P2 - projection mode aim

- §5.2 anchoring, using the game FOV from the renderer, re-anchor events and `move.camera_distance`.
- Gate: House of the Dead Overkill in the headset. Shots land on what the controller points at for
  middle-distance enemies, with the head turned up to 30° left and right of the anchor.

### P3 - both hands, 6DoF

- Two gems, `cellGemGetInertialState`, `angvel`, rumble.
- Gate: Sports Champions table tennis and archery are playable. Paddle angle follows the wrist,
  drawing the bow uses both hands' positions, and rumble fires.

### P4 - Navigation controller

- Off-hand `openxr` pad handler (§4.5, option A) and the `move.navigation` profile key.
- Gate: Killzone 3 or Resistance 3 is played with the right hand aiming and the left stick moving,
  without a gamepad.

### P5 - cleanup and release

- Defaults per test title, `vr-games.md` column "Move", user notes in `vr-settings.md`. Keep the change
  footprint in upstream files small ([8-upstream-merge-audit.md](8-upstream-merge-audit.md)): the
  handler's body goes in fork-only files (`Emu/Io/openxr_move.{h,cpp}`), and `cellGem.cpp` only gets
  the `case move_handler::openxr:` lines.

## 8. Risks and open points

- **x sign / orientation basis** (§3): one test resolves it, but it's the first thing to verify.
- **What games use from `CellGemState`.** Some read `pos` (3D), some read the image state (2D), and
  some read the quaternion and ignore position. All three must be consistent, which §4.2 ensures by
  deriving the 2D values from the 3D ones with one camera model.
- **Calibration flows.** Some games check that the sphere is visible and at a sensible distance (about
  1-3 m) during calibration. A virtual camera that is too close or far may fail it. Default 2 m.
- **Hue tracking.** Games call `cellGemTrackHues` / `cellGemGetHuePixels` and some show the camera
  image with the sphere. The fake camera's painted spheres already cover this `[SOURCE]` (line 1332).
- **Timing.** `cellGemGetState` ignores its time arguments today. The snapshot is for predicted
  display time, which is slightly ahead of the guest frame. That's probably better than real hardware
  (the PS Eye adds about 30-60 ms), but with a fast swing (Sports Champions) a game might double-count
  velocity. Test in P3.
- **Comfort.** Bounding-box turning (§5.2) moves the world without head motion. List it per game.
- **AR titles** (EyePet, Start the Party!, Kung Fu Rider's full-body video). They composite the live
  camera feed, so they make no sense in a headset. Out of scope.
- **Upstream.** RPCS3 upstream has no OpenXR dependency, so this handler stays fork-only like the rest
  of `VKOpenXR`.

## 9. Size

| Part | Estimate |
|---|---|
| P0 actions + snapshot + handler | ~500-700 lines, 2-3 days |
| P1 quad anchoring + first game | 1-2 days |
| P2 projection anchoring | 2-4 days, mostly per-game tuning |
| P3 two hands, inertial, rumble | 1-2 days |
| P4 Navigation pad handler | 2-3 days |

The input plumbing is small because `cellGem` already has the right shape. Nearly all the
uncertainty is in §5.2 and per-game behaviour.

## 10. Decisions needed (Matt)

1. Default dominant hand, and whether gem 1 (the second hand) is on by default or only for two-handed
   games.
2. Navigation controller: option A (pad handler, P4) or B (gamepad), and whether P4 is needed before
   the first release.
3. First release target: quad mode only (P1) or wait for projection mode (P2).
4. Which test titles are available as dumps (§6).
