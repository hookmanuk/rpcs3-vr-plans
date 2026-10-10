# 2026-10-10: push descriptors and home-menu options, quick check

Build a631a734e (push descriptors) and the commit after it (home-menu options). One run per state at the rate it
sustained in 2026-10-09-2330-gt5night; a failure got one immediate re-run.

Passed: R&C 1 and 3 (90), Demon's Souls (90), God of War (90), Killzone 2 carrier (72), Bayonetta (90), GT5 race start
(90), MotorStorm PR (90, second try: first boot rebuilt the pipeline cache), SEGA Rally (90), Sonic (90), Flower (90),
SotC (90), Dragon's Dogma (90), Jak 2 (72), WipEout (90), Kingdom Hearts 2 (72).

- WipEout stalled at 32 FPS (every fourth frame 80-100 ms late, GPU and RSX thread idle) in seven runs between 08:58
  and 09:23, on this build and on last night's 7820e2159 alike; from 09:25 it ran at 90 (0-0.28% late) on both. Not a
  code change; the cause was not found (not GPU, timer resolution, settings files or the simulator's capture).
- Kingdom Hearts 2 sits on the 1% late-frame line (0.17-1.22% across runs, with push descriptors on and off).
- Folders: one per run (quick-*, ab-on/off-*, bisect-7820-*, diag*-wipeout, confirm-*, current-*).
