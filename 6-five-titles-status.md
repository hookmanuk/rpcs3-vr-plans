# Five more titles: state for headset testing (2026-09-24)

Blur, inFamous, inFamous 2, Metal Gear Solid 4 and Need for Speed Most Wanted (2012). All five have a
VR profile and reach 90 FPS (mono) with the patches below. Everything was verified on the desktop (both
eyes side by side, a 25-degree rotation audit, game-clock measurements). **Nothing has been run in the
headset yet.** Per-game detail: `plans/profiles/<TITLE_ID>-notes.md`. Evidence: `plans/evidence/<game>/`.

The work is **not committed**. `rpcs3.exe` in `rpcs3/bin/` is built from the current working tree.

## What to test

Start SteamVR, launch each game normally from RPCS3 (no dev environment variables). Each game's custom
config already has `Video > VR > Enabled`, `Vblank Rate: 90`, Cubeb audio and fullscreen on; the frame-rate
patches are enabled in `bin/config/patch_config.yml`.

| Game | ID | VR profile | Frame rate | How to reach gameplay |
|---|---|---|---|---|
| Blur | BLUS30295 | yes | patch "Unlocked frame rate (follows Vblank Rate)": 1 vblank per flip; real-time clock | Career > Proving Grounds > Barcelona Oval |
| inFamous | BCUS98119 | yes | no patch needed (uncapped, real-time) | Continue from the title |
| inFamous 2 | BCUS98125 | yes | no patch needed | New Game (~2.5 min intro) |
| MGS4 | BLUS30109 | yes | patch "Frame rate follows Vblank Rate": 1 vblank per frame; real-time | Virtual Range (quick) or New Game / Act 1 |
| NFS Most Wanted | BLUS31010 | yes | patch "Frame rate 90 FPS (set Vblank Rate 90)" | title > Start > decline PSN > intro hands over to driving |

Match Headset Refresh Rate: Blur, both inFamous and MGS4 set `match_headset_refresh_rate: true` (their
speed follows real time). NFS does not: its patch is fixed per rate, so keep the headset at 90 Hz, or pick
the 72/80/120 FPS entry in the patch manager and set Vblank Rate to match.

Things to look at in the headset (not verifiable on the desktop):

- **HUD box.** Blur's and NFS's HUDs are 3D planes at a fixed depth; they go into the HUD box only on the
  headset path (`screen_space.depth_offset_projection`). MGS4's HUD is on the final 1280x720 target and
  should behave like a normal HUD.
- **World scale.** Chosen from the near plane; MGS4 (millimetres, `eye_baseline` 64) and inFamous
  (centimetres, 6.4) are the least certain. Use World Scale in the home menu's VR tab.
- **Comfort and frame pacing.** Stereo costs a lot in inFamous 1 (~25 FPS, 13,500 draws/frame) and MGS4
  Act 1 (~35); Blur ~45-50 and inFamous 2 52-72 at 100% resolution.
- **Blur:** the car's shadow may lag under large head turns; the mirror's motion blur streaks in one eye.
- **inFamous 2:** a layer processed on the SPUs from a copy of the frame is correct only for the left
  eye (a slight ghost in the right eye under stereo parallax).
- **MGS4:** once saw a `_sys_lwmutex_lock CELL_ESRCH` ~8 min into Act 1 followed by a black screen (during
  memory dumps); a clean run carried on. Not yet checked with the patch off.
- **NFS:** the 90 FPS patch was confirmed at 90 FPS with real-time clocks on the title screen; the
  in-gameplay clock check was interrupted. Previously, gameplay at 60 FPS with the pacer patch measured
  real time. If driving feels 1.5x fast, disable the patch (see below).

## Frame-rate patches (`bin/patches/<ID>_patch.yml`, copies in `plans/profiles/`)

- **Blur** `0x349f80`: vblank countdown between flips = 1. Game time is wall-clock based.
- **MGS4** `0xfa33c`: the frame wait `0xdb720(n)` counts `n` vblanks; `n = 1`. (The community Unlock FPS
  patch removes the wait instead.)
- **NFS** (hardest): three separate 30 FPS mechanisms.
  1. A 2-vblank flip gate through RSX labels: `0x7400cc` writes 1.
  2. The game's own timer pacer `0x635a20` (spins on `mftb` until N periods of 1/60 s): `0x678cc` N = 1,
     period constant `0x667f4` = 60000/rate.
  3. A fixed 1/60 s simulation step read from `frame+0x9c` (plus a 2-step catch-up `+0xa0`, and the
     game-time accumulator). The three loads (`0x69658`, `0x69644`, `0x67960`) branch to a code cave at
     `0xa5a000` (zero padding in .rodata) that loads 1/rate and 2/rate instead.
  Found with the new sampling profiler (`RPCS3_PPU_SAMPLE`): 83% of the main thread's time was in the
  `0x635a20` spin.
- **inFamous 1/2**: none needed.

## How much of this is generic emulator code vs per game

Per-game knowledge lives only in **data**: the VR profile JSON and the frame-rate patch YAML. Everything
else is generic code that any later game can use:

**Renderer (VK), generic:**
- Scaled NV3089 blits mirrored to the right eye (`vk::texture_cache::blit_vr_right`) - MSAA resolves
  (Blur).
- Partial (scissored) clears mirrored to the right eye, and only the attachments actually cleared.
- Right-eye rebuild of deferred texture copies (format-converting views of render targets) from the
  right-eye surfaces (NFS lighting).
- Staged-copy mirror handles column-chunked copies into one image.

**Profile format (renderer), generic options** - `plans/profiles/README.md`:
`matrix_layout: column_vectors_xyw`, `require_camera_aspect`, `camera_target_aspect`, explicit slot lists
in `camera_blocks`, `game_camera_target_widths`, `screen_space.depth_offset_projection` (incl. x/y-shifted
planes), `screen_space.rotation_only_passthrough`.

**In-emulator profile generator, generic:** now detects the three matrix layouts, targets within 5% of
16:9 (and writes a matching tolerance), overlapping camera blocks (and sets `require_camera_aspect`),
anamorphic camera targets (`camera_target_aspect`), 3D HUD planes (`depth_offset_projection`), reversed-depth
near planes, and worlds up to 200x (centimetre/millimetre units). With these, the generator produced
usable first profiles for all five games; hand edits were: dropping a stray block (NFS c[0]), MGS4's
explicit `[0,1,2,7]` slot list, Blur's mirror width, inFamous 2's passthrough, world-scale fixes,
`match_headset_refresh_rate`.

**Frame-rate patches: not automated.** They stay per-game YAML (as concluded for Split/Second). What is
new is tooling that makes finding them much faster:
- `RPCS3_PPU_SAMPLE=1`: per-thread sampling profiler (current function + caller), logged every 5 s.
  This found NFS's pacer directly.
- `RPCS3_USLEEP_STATS=1`: sleep call sites with counts/durations.
- `RPCS3_VR_MEMDUMP=<file>`: guest memory snapshots; `plans/tools/re/memclock.py` finds clock variables
  and their rate vs wall time (real-time check at 60 vs 90), `ratediff.py` finds values that change
  60->30 between two states.
- `plans/tools/re/ps3elf.py`: ELF/import-stub helper for capstone disassembly (dump the ELF with
  `RPCS3_DUMP_ELF`; imports from the RPCS3 log).
A plausible next step toward automation: a "frame-rate probe" that combines the sampler and the clock
check to *report* the pacer type (vblank interval / vblank-count dt / timer pacer / fixed step) for a
new game, which is most of the manual work. Writing the patch would still be manual.

## Dev hooks added (all environment variables, off by default)

`RPCS3_VR_GEN_TRIGGER=<file>` (run the profile generator), `RPCS3_VR_KEYS=<file>` (key script into the
keyboard pad: lines `X 300 5000`, `wait 2000`), `RPCS3_VR_SHOT=<file>` (screenshot; both eyes when stereo),
`RPCS3_VR_MEMDUMP=<file>`, `RPCS3_USLEEP_STATS`, `RPCS3_PPU_SAMPLE`; inspector captures now include blit
and NV0039 "note" records. `plans/tools/re/shot.py` wraps the screenshot hook.

## Config and machine notes

- MGS4: `LLVM Precompilation: false` (first boot otherwise precompiles the whole 400 MB mself, 20+ min).
- Blur: needs `Write Color Buffers: true` (black screen otherwise).
- inFamous 1/2 and MGS4: `dev_hdd0/game/.locks/<ID>` suppresses the disc PKGDIR install prompt.
- The leftover Split/Second keyboard pad (`input_configs/BLUS30300`) was deleted on 2026-09-24.
- When the RDP desktop locks, desktop capture and injected keys stop working and Cubeb audio crashes the
  emulator: use the hooks above and Null audio for unattended runs.

## Open

1. Headset runs of all five.
2. NFS: confirm real-time speed in gameplay with the 90 FPS patch (memclock or a timed lap).
3. inFamous 2 SPU layer for the right eye.
4. Commit the work: source and `bin/vr_profiles/*.json`. `bin/patches/` and `bin/config/` are gitignored,
   so the patch YAMLs are kept as copies in `plans/profiles/<ID>-patch.yml`.
