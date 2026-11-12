ICO in VR: the first release of the VR fork, built on ico-pc v0.11.4.

The whole game in stereo 3D in a PC VR headset through OpenXR, on Windows. The flat game is still in the same download and runs as before.

## Download

**ico-pc-v0.11.4-vr-0.1-win.zip**. Saves and settings go in `%APPDATA%\ico-pc`.

## Playing in VR

1. Unzip it.
2. Start your headset's OpenXR runtime. SteamVR is the one this was tested on.
3. Double-click `ico_vr.cmd` in the unzipped folder.

**Your disc image.** The game itself is not included: you need your own disc image of ICO, one file ending in `.iso`, `.chd` or `.bin` (the README lists the discs that work). The first time you start it, a window on the desktop asks for that file. Pick it, and the game copies what it needs from it once and starts. It does not ask again.

**The VR mode has only been tested with the European disc** (SCES-50760). The other discs play as the flat game does, but nobody has checked them in a headset yet.

You play seated with a gamepad or the keyboard. Motion controllers are not used. **F8** puts the view straight ahead of you again.

**With a gamepad, turn on Analogue stick fix** (Options > Controls > Analogue stick fix). With it on, Ico runs in whichever direction you push the stick; without it he only knows the original game's eight directions and can walk when you mean him to run.

## What the VR mode does

- The whole game in 3D from the game's own cameras, with your head's position and turn added, both eyes drawn in one pass.
- A new picture for every headset frame, at the headset's refresh rate: the motion between the game's 30 updates a second is filled in, and each picture is drawn for where your head will be when it is shown.
- Shadows, water reflections, fog, glow and depth of field are drawn for each eye.
- Menus, subtitles, the title's logo and the Options pages sit on a fixed screen two metres in front of you. Movies and the pause screen are shown on a larger flat screen.
- Options > Display > **VR resolution**: 50 % to 200 % of the size the headset asks for, changed as you press.
- The Options rows that do nothing in a headset are hidden while VR is on. Screen softening and Motion blur start off, and the title no longer drops back into the opening demo while you wait on its menu.
- The desktop window shows the left eye.

## What it needs

- Windows 10 or 11, 64-bit, with a Vulkan graphics card.
- A PC VR headset whose OpenXR runtime is the system's (SteamVR or the headset maker's own).

## Known problems

- VR is Windows only. This release has no builds for the other platforms.
