**Title:** Ridge Racer 7: nitro/boost screen effect centred off straight-ahead in the headset

**Game:** Ridge Racer 7 (BCAS20001), VR profile `BCAS20001.json`

**Reported:** A user says the nitro (turbo boost) effect looks wrong in the headset, and puts it down to the HUD being off-centre.

**Background**

Each eye's view on a headset is asymmetric: it reaches further to the outside than towards the nose. On a Quest 3 it is about 54° outward and 40° inward. Straight ahead is therefore not the middle of each eye's image. It sits about 60% of the way across the left eye's image and 40% across the right eye's.

The fork places the HUD box straight ahead. In a flat screenshot of the eye images it looks shifted towards the nose in each eye, but in the headset it appears centred. The 3D scene is remapped the same way, so its vanishing point is straight ahead too.

**Likely cause (not yet confirmed)**

The boost effect is probably a full-screen post-processing pass, such as a radial blur or speed lines, centred on the middle of the game's frame. If that pass is drawn into each eye image without the headset remap, its centre lands in the middle of each eye's image instead of straight ahead. That puts it about 7-10° off to the outside in each eye, in opposite directions. Both eyes then disagree with the scene's vanishing point and with each other, which would be uncomfortable and would look off-centre next to the HUD.

The HUD itself is placed correctly. It's the reference that makes the effect's offset visible.

**To check**

1. On the OpenXR Simulator with a Quest 3 or MeganeX profile, start a race and trigger nitro. Compare both eyes' captures with flat play at the same moment.
2. Find the effect's draws (probe `hide=<program>` sweep during nitro, or an inspector capture). Note whether they are boxed as HUD or drawn full-screen, and whether the effect centre comes from a vertex/fragment constant or from the clip-space quad.
3. Fix by placing the effect's centre straight ahead in each eye:
   - Remap the centre constant with the eye's FOV mapping, the same `remap_to_eye_fov` the scene gets.
   - Or, if the pass only samples the scene at screen positions, draw it so that sampling follows the scene remap.

**Asking the reporter**

- Headset model and runtime (Quest Link / Virtual Desktop / SteamVR).
- A photo through the lens or a mirror capture during nitro.
- Whether the effect is wrong in both eyes or one, and whether it feels like double vision or just looks off-centre.
