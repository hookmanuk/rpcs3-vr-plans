# RSX-thread optimisation A/B runs (2026-10-01)

`tools/re/vr_ab.sh LABEL`: each state once at 72 Hz, desktop stereo, Resolution Scale 300% (4K per eye), Ryzen 7
9800X3D + RTX 5090. "RSX thread" = its CPU ms per frame (cycle-exact from `base1` on; `base0` used GetThreadTimes and
undercounts). Run-to-run noise is about +-0.3 ms and +-1 FPS.

| Label | Build | R&C 1 | R&C 3 | Dragon's Dogma |
|---|---|---|---|---|
| `base0` | before (GetThreadTimes, undercounted) | 66.4 FPS | 69.9 | 68.8 |
| `base1` | before | 13.17 ms, 66.8 FPS | 12.24, 69.0 | 14.12, 68.4 |
| `opt1_findslot` | camera slots by binary search | 12.78, 68.0 | 11.92, 70.1 | 14.35, 67.7 |
| `opt2_fboimages_devpoll` | + no per-draw attachment-list allocation, dev polls every 100 ms | 12.53, 67.5 | 10.18, 72.0 | 14.00, 68.9 |
| `opt3_scratchfill` | + eye-constant scratch filled with ordinary stores | 10.86, 71.3 | 9.24, 72.0 | 13.93, 68.9 |
| `opt4_hash_get` | + cached vertex-program hash, inline `camera_probe::get` | 10.71, 71.4 | 9.17, 72.0 (rerun) | 13.88, 69.0 |
| `opt5_dd_zcull_profile` | + `zcull_approximate` in Dragon's Dogma's profile | | | 7.80, 72.0 |

Also: `flat_opt2` / `flat_opt3` (PROBE=render=0: R&C 1 7.22 ms, R&C 3 6.12, Dragon's Dogma 8.04), `dd_relaxed`
(Relaxed ZCULL Sync: 13.29 ms, 70.0), `dd_inexact` (Accurate ZCULL stats off: 7.95 ms, 72.0).
