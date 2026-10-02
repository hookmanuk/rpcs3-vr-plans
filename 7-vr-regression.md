# VR regression savestates: how to recreate them on another PC

The VR regression run (`tools/re/vr_regress.sh`, method in `5-vr-profile-playbook.md` > VR frame-rate
measurement) boots one savestate per game, listed in `tools/re/vrtest_states.txt`. The savestates are 20-300 MB
each and live only in `rpcs3/bin/savestates/<ID>/` on the PC that made them, so another PC has to recreate them.
Frame rates also differ between PCs: keep each PC's own baseline (`evidence/vrtest/<date-time>/results.txt`) and
compare runs on the same PC.

## Before making any savestate

1. Build the fork (`1-structure.md`) and use the game files listed in `rpcs3/bin/config/games.yml` (disc
   versions; only Dragon's Dogma uses an update, 01.02).
2. Copy the game's VR profile(s) to `bin/vr_profiles/` and its patch file (if any) to `bin/patches/`, from
   `rpcs3/vr-non-working/` (or the release package), and enable the patches named below in
   `bin/config/patch_config.yml` (Manage > Game Patches). A savestate keeps the patched code, so make it with the
   same patches the test will run with.
3. Keyboard pad: copy `tools/keyboard-pad-template.yml` to `bin/config/input_configs/<ID>/Default.yml` (left stick
   I/J/K/L, Cross X, Circle C, Square Z, Triangle V, Start Return). The steps below use these keys;
   `tools/re/keys.sh '<key> <hold ms> <gap ms>\n...'` sends them to the game window.
4. Make the savestate with **Ctrl+S in the game window** (`powershell -File tools/keys.ps1 -Keys "Ctrl+S"`). RPCS3
   writes `bin/savestates/<ID>/<ID>_1_<n>.SAVESTAT.zst`; rename it to the `vrtest_...` name in the table. Wait
   until the file stops growing before quitting.
5. Make it in **flat** mode (no `render=1`) at the vblank in the table, then delete the temporary pad and custom
   config (`tools/re/gclean.sh <ID>`).
6. Check it: `sh tools/re/vr_regress.sh <state name>` should boot it, walk, and print frame stats.

Manifest columns (`tools/re/vrtest_states.txt`): `ID STATE VPF WALK SETTLE scene`. WALK is 1 (walk back and forth with
the left stick), 0 (no input), a pad key to hold for 25 s (`W` = R2, accelerate in Pure) or `script`: the key script
`tools/re/vrtest_boot/<STATE>.walk`, played from the boot on (Super Stardust HD fires in circles to stay alive). The pad
template maps the right stick to T/F/G/H. A `rates=30` tag in the
scene text replaces the default rates 72/90/120 (frame-locked games). A game that cannot savestate gets a disc-boot
key script `tools/re/vrtest_boot/<STATE>.keys` instead (Ridge Racer 7).

Vblank matters for **Anarchy Reigns** only: each character copies the frame time when it is created, so the
characters in a savestate keep the step of the rate it was made at. The original was made at Vblank 180 (90 FPS).
That does not affect the frame-rate measurement, only game speed; make the state at the rate you want to check
speed at. The other games read their frame time every frame.

## Per game

| State (`vrtest_...`) | ID | Patches | How to reach it |
|---|---|---|---|
| `rc1_veldin` | BCUS98282 | none | `tools/re/rc_boot.ps1` (collection menu, R&C 1, New Game, save slot, skips the cutscenes) reaches Veldin; press X once to close the HelpDesk tip, Ctrl+S. |
| `rc2_aranos` | BCUS98282 | none | Boot the collection, Right (R&C 2), X; Return and X through the intro; X x3 to create a save; Return x3 to skip the opening cutscenes: first control on Aranos (inside the ship hangar). Ctrl+S. |
| `rc2_aranos_hall` | BCUS98282 | none | Made by Matt: R&C 2 played on from the start to the large machinery hall on Aranos (16 bolts), Ctrl+S. Any busier R&C 2 scene will do; the hangar state (`rc2_aranos`) is too light (543 draws/frame) to show performance. |
| `rc3_veldin_battle` | BCUS98282 | none | Collection, Right x2 (R&C 3), X; at the title Return, Down + X (New Game), X x3 (save), Return x4 to skip cutscenes: the Veldin battle with the Rangers. Ctrl+S at the first control. |
| `anarchy_practice` | BLUS30632 | fork *Frame rate follows VR* (`BLUS30632_patch.yml`, on by default); community *60 FPS* **off** | First boot: X, X (install data and save). Intro text pages X; PSN dialogs X; title Return; main menu Down x2 = TRAINING, X; PRACTICE X; tip X. `tools/re/ar_boot.sh 180` does most of it (menu input is laggy: screenshot between steps). Ctrl+S once Jack is in the arena, at Vblank 180. |
| `dante_acre` | BLUS30405 | none (disc 01.00) | Logos X/Return; PSN notice X; Start Game X; video calibration X; difficulty X; wait out the ~90 s intro movie; Ctrl+S at the first fight in Acre. |
| `darkness_opening` | BLUS30035 | community *60 FPS* (01.03) | `tools/re/dk_boot.ps1`: intro video X, autosave notice X, New Game, Medium; the opening car scene stops at "View tutorial help": Ctrl+S there. No walking (WALK=0). |
| `puppeteer_cage` | BCUS98227 | none (optional *Disable SPU MLAA*) | First boot: dismiss the "install manual" PKG dialog (`tools/launch.ps1` does it). Title: X (New Game), X (One player), X; the prologue is in-engine (Return/X skip what can be skipped); Ctrl+S at the first control, Kutaro in the cage. |
| `xillia_field` | BLUS31006 | community *60 FPS* + fork *Frame rate follows VR* (`BLUS31006_patch.yml`) | `tools/re/tox_boot.ps1` (first-run options, opening movie, Jude, cutscene skip, tutorials) reaches the first field; X to close the controls screen; Ctrl+S. |
| `ddda_prologue` | BLUS31155 | update **01.02**; community *Unlock FPS*; fork *Full screen (no letterbox)* (`BLUS31155_patch.yml`) | New Game; the prologue begins after the opening (Ctrl+S at the first control in the prologue dungeon). `tools/re/dd_boot.ps1` loads an existing save to the same point. |
| `jak1_hut` | BCUS98281 | none | Collection menu: Jak and Daxter (first entry), X; New Game; let the intro play (X skips text); Ctrl+S at the first control in Samos' hut. |
| `jak2_prison` | BCUS98281 | none | Collection menu: Down (Jak II), X; New Game; through the intro to the first control in the prison/escape area; Ctrl+S. |
| `jak3_spargus` | BCUS98281 | none | Collection menu: Down x2 (Jak 3), X; the opening cutscene cannot be skipped (Start pauses it: wait ~2 min); title Return; New Game, Yes (create save, Left + X), slot 1; wait for the Spargus cutscene to end (X past the autosave notice); Ctrl+S at the first control in the palace. |
| `dw6e_battle` | BLUS30306 | none | Boot at Vblank 60 (the intro movie stalls at a higher rate). Empire Mode > New > Normal > Yellow Turban Rebellion > Ahui Nan > Battle > Mercenary > Shao Hua Bandits; Ctrl+S at the start of the battle. |
| `ssd_lave` | NPUA80068 | none (PSN 06.00) | Needs the game licence (.rap). Title Return; Single Player X; Arcade X; Up (Easy) X; Lave X; the controls and tips screens X, X; Ctrl+S (or the `RPCS3_VR_SAVESTATE` hook) in the first second of play. The ship dies without input: the run fires in circles (`vrtest_boot/vrtest_ssd_lave.walk`, SETTLE 5). |
| released games | | | see below |

### Released and other games

| State (`vrtest_...`) | ID | Patches / config | How to reach it |
|---|---|---|---|
| `wipeout_race` | BCES00664 | released profile + patches; your custom config | Start any single race; once the ship is moving (hold X to accelerate), Ctrl+S. WALK=0 (the stick keys do nothing useful). |
| `gowc_boat` | BCES00800 | released profile; set **Compatible Savestate Mode** to true in the game's custom config while saving, then set it back | `tools/re/gow_boot.ps1` (God of War 1, new game); wait out the ~90 s intro video, X; Ctrl+S at the first fight on the boat. |
| `icosotc_1` | BCUS98259 | released profiles (`BCUS98259*.json`) | Shadow of the Colossus, an open valley while riding/walking. (The original was made by hand; any open-world scene in SotC will do, numbers then differ from the old baseline.) |
| `ico_bridge` | BCUS98259 | released profiles + patches (as in `vr-games.md`) | Collection launcher: ICO; title Return; Continue, file 1 (a save at the Old Bridge; any save point works); X, then walk a step so the camera follows; Ctrl+S. Measured at 30 FPS only (`rates=30` in the manifest: ICO is frame-locked at 30 in VR). |
| `demons_1` | BLUS30443 | released profile + patches | New character; Ctrl+S in the tutorial corridor (first steps of the Boletarian Palace tutorial). |
| `bayonetta_play` | BLUS30367 | profile + patches as in `vr-games.md` | New game; Ctrl+S during the graveyard fight in the Prologue. |
| `gt5_race_start` | BCUS98114 | `BCUS98114_patch.yml`; your custom config (300% works, **200% freezes**) | Arcade > single race; Ctrl+S on the grid right after the start. SETTLE 40 (GT5 stalls for ~30 s after the savestate loads). WALK=0. |
| `pure_race` | BLUS30182 | released profile; set **Compatible Savestate Mode** while saving (as for God of War) | Warnings X, X, Return; autosave notice X; title Return; Main Menu Down (Single Event), X; Race, X; track (Alto Vista), rider and ATV: X each; wait ~40 s for the intro flyby; Ctrl+S on the start line. R2 (W) accelerates, so WALK=W. |
| `rr7_boot` (no savestate) | BCAS20001 | released profile | Ridge Racer 7 **cannot savestate** ("HLE VDEC (video decoder) context(s) exist": the menu video's decoder stays open). The run boots the disc from `games.yml` and plays `tools/re/vrtest_boot/vrtest_rr7_boot.keys` (Arcade > Single Race > Rave City Riverfront, holds Cross); nothing to recreate. |
| `kz_trench` | BCES01743 | released profile + `BCES01743_patch.yml`; make it with **Frame rate 120 FPS** on and *90 FPS* off (Manage > Game Patches), then switch back | Savestates keep the patched code, and the 120 entry's loop takes up to 4 fixed steps a frame, so one state measures 72, 90 and 120. Boot; Return; X (skips the intro movie to the menu); X GAME, X Campaign, X Helghast Assault, X Easy, X Templar; ~20 s, then Return and X to skip the intro movie; Ctrl+S at the first control in the trench. |
| `asura_space` | BLUS30721 | community *Unlock FPS*, *Disable Motion Blur*, *Disable Depth of Field*; a temporary custom config with only `Savestate: Compatible Savestate Mode: true` while saving (delete it after) | PSN notice X; Return through the logos; title Return; "Load successful" X; NEW GAME, EASY, Yes (overwrites the save); "Save successful" X; the Episode 1 opening cannot be skipped (Start pauses it: X resumes); Return at the in-episode PRESS START title; Ctrl+S in the space battle (rail shooter). |
| (NFS Most Wanted) | BLUS31010 | | Skipped: the disc image is no longer in `F:/rpsc3/games`. |

## RPCS3 savestate gotchas

- **Names:** RPCS3 keeps at most 4 savestates per game (`Savestate > Maximum SaveState Files`) and deletes the
  oldest `<TITLE_ID>_*.SAVESTAT.zst` when you save a new one. Files whose names do **not** start with the title ID
  (`vrtest_...`) are never touched, so always rename. (On the original PC the `vrtest_` files are hard links to
  RPCS3's own files, so they survive its cleanup.)
- **"Failed to savestate: HLE VDEC (video decoder) context(s) exist"** (Ridge Racer 7): no workaround without
  changing the game's library settings; such games get a `vrtest_boot/<STATE>.keys` disc-boot script instead
  (`vr1pct.sh` boots the disc when that file exists; SETTLE must cover the menus).
- **"Failed to savestate: failed to lock SPU threads execution"** (God of War Collection, Pure, Asura's Wrath): set
  `Savestate > Compatible Savestate Mode: true` in the game's custom config, boot again, save, then set it back.
- Savestates may stop loading after large emulator updates (the log says so); recreate them then.
- A savestate refuses to load if the disc image is no longer at the path it was made from
  ("Disc directory not found").
