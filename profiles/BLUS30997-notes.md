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
