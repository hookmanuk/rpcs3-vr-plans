# Dragon Age: Inquisition (BLUS30997) - notes (emulation blocker)

Disc 01.01 (`Dragon Age - Inquisition (USA) (En,Fr,Es).iso`), PPU hash `PPU-22a17ff565b6caaa2a6c498b7b9e9a31b4b43da2`
(ELF and imports in `tools/re/elf/BLUS30997.*`). Frostbite 3. The first boot installs 5.3 GB
(`dev_hdd0/game/BLUS30997install`) and then idles; later boots stop presenting ~26 s in, loading the start menu.

## What gets past it

- **Clocks scale 30** reaches the title screen ("Press START"), but the game then runs at 9 FPS (its pacing follows the
  scaled timebase). 50, 70 and 90 hang like 100. (RPCS3 issue #13507 lists Frostbite 3 games needing clock scale
  under 100% to get in game; Battlefield Hardline ~30%.)
- A savestate made at the title at 30% (`bin/savestates/BLUS30997/dai_title30`, made with Compatible Savestate Mode)
  loads at 100% and runs the title and character creation at 30 FPS; the next level load (after class selection)
  hangs the same way.
- Tried, all hang identically: SPU Block Size Mega, Accurate RSX reservation access, Sleep Timers As Host, PPU Threads 1,
  Cubeb audio, no headset session, Accurate SPU DMA + Cache Line Stores, SPU interpreter, Max SPURS Threads 1,
  Preferred SPU Threads 1, Accurate SPU Reservations off, SPU loop detection, GETLLAR spin optimisation off, SPU
  reservation busy waiting.

## The hang

- PPU sampling (`RPCS3_PPU_SAMPLE`): `main_thread` polls in `0x24d394`-`0x24d3f0` (a 100-try loop, then `usleep(30)`
  forever) on the job manager; `JobManager PPU` spins at `0xa10060` (`usleep(30)`) in the frame-fence wait of
  `0xa0ffd4`: it waits until the GPU label at `[obj+0x1d4]` = `0xa0300420` (label 0x42) + `[0x1dfbf58]` (2 frames in
  flight) reaches the submitted count `obj+0xac` (obj `0x84990040`). At the hang: label 0x55, submitted 0x58.
- The RSX thread is idle (`RPCS3_RSX_SAMPLE`: 92% sleeping, empty FIFO), so the commands that would write the label
  were never put into the FIFO; Frostbite builds command buffers in SPU jobs, so a job chain or its PPU proxy
  (`Job Manager - PPU Proxy` at `0xb6b090`) is the stalled side. Clock-scale dependent: some timebase-measured branch
  (a timeout or an adaptive frame budget) takes a path that never kicks the frame.
- Next: find the timebase reads (`mftb`, `sys_time_get_system_time`) in the job manager / proxy (`0xb64xxx`-`0xb6bxxx`,
  `0xa0fxxx`-`0xa10xxx`) and compare their branches at 30% and 100% with trace breakpoints.

## More attempts (2026-10-04 evening)

- Settings, all hang at ~26 s: PPU Reservation Priority Over SPUs, RSX FIFO Fetch Accuracy Atomic & Ordered, SPU
  Wake-Up Delay 100, Usleep Time Addend 100, Clocks scale 95.
- Test patch: the PPU proxy's event wait (`sys_event_queue_receive` at `0xb6b090`, timeout 1.67 s, which stamps a
  timebase heartbeat into each job context +0x330 on every timeout) cut to 10 ms (`0xb6b080` `li r5, 10000`,
  `0xb6b088` nop; patch versions must name APP_VER 01.00): still hangs. Removed.

## 2026-10-08: which time matters (experiments, reverted)

- Scaling only the SPU decrementer to 30% (`read_dec`, LLVM fast path off): hangs the same at ~26 s.
- Scaling only the lv2 sleeps/timeouts by 100/30 (`lv2_obj::wait_timeout`, `sys_timer`): hangs the same.
- So the trigger is the PPU-visible timebase (mftb / `sys_time_get_system_time`), as at Clocks scale 30.
- Timebase-read histogram (PPU interpreter, `RPCS3_TB_TRACE` test hook: per mftb site and caller): during the last load
  window the main thread calls the game-timer update `0x24c740` (timer object: last tb, total, delta s, total s at
  +0..+0x18, scale +0x20) ~775k times in 5 s from `0x86e958`, a busy-wait frame pacer (compares the timer delta `0x24c890`
  with a target in f29; config at `[r30+0x2c]+0x10/0x14/0x1c`, falls back to `[r30+0x30]` Hz); other readers in that
  window: `0x2316ec`, `0x24c8b0` (from `0x74d6b0`, `0x750dc0`), `0x2359c0`/`0x2359fc` (from the job manager `0xb64734`),
  `0x24d944` (from `0xa28bb4`), `0x706570`, `0xb674a4`. After the hang only the job manager's frame-fence wait
  (`0xa10064` from `0xa100ac`, ~26k/s), `0xf8f428`, `0x20756b4`, `0x63bfa4` and the PPU proxy `0xb6b12c` read time.
- Candidates to try next: the job manager's `0xb64734` time reads (a job timeout or a frame budget) and the pacer's
  target; compare the branch taken after each at 30% and 100% with `RPCS3_PPU_TRACE`.

## 2026-10-08: priority

Even with the load hang worked around, Inquisition is a 30 FPS Frostbite 3 game whose title screen runs 30 FPS in
RPCS3 from the 30%-made savestate; an unlocked rate plus stereo would be far below the 72 Hz bar on current hardware.
Kept as an emulation blocker; the next step (a time scale that drops only during loads, continuous across switches)
needs changes in RPCS3's timebase (`sys_time.cpp`) and only pays off if the game can also run fast enough.

## 2026-10-08: live clock scale (experiment, reverted)

A dev hook let the clock scale change while running, continuous at each change (sys_time + lv2 sleeps). From
`dai_title30` at 100%: switching 100 -> 30 -> 100 works (title, main menu at 30% 9 FPS, character creation at 100% 30
FPS). But the level load after character creation (World State > Confirm) **also hangs at 30%**: loading spinner, no
frames for 10 minutes. So a slow clock during loads is not enough; the hook was reverted. Still an emulation blocker.

## Parked (Matt, 2026-10-08)

Corrupted graphics and poor performance. Parked with The Darkness, Anarchy Reigns and X-Men Origins.
