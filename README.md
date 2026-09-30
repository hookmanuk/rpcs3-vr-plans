# RPCS3 VR: plans, profiles and tools

This repository is the working notebook for a VR (OpenXR) fork of the RPCS3 PS3 emulator. The
emulator code is not here. It lives on the `openxr` branch of
[hookmanuk/rpcs3](https://github.com/hookmanuk/rpcs3/tree/openxr), and this repo is meant to be
checked out alongside it:

```text
<workspace>/
  rpcs3/   https://github.com/hookmanuk/rpcs3 (branch openxr)
  plans/   this repository
```

The scripts in `tools/` assume that layout with the workspace at `F:\rpsc3\source`. Edit the paths
at the top of a script if yours is elsewhere.

**Start with [1-structure.md](1-structure.md).** It lists the repositories, the toolchain and the
exact build commands.

| File | Contents |
|---|---|
| [1-structure.md](1-structure.md) | Workspace layout, repository URLs, dependencies and build commands |
| [3-investigation.md](3-investigation.md) | Background on how RPCS3 renders and where the stereo camera work hooks in |
| [4-next-steps.md](4-next-steps.md) | The gate checklist, generic renderer work and releases |
| [5-vr-profile-playbook.md](5-vr-profile-playbook.md) | How to make or fix a game's VR profile |
| [6-wip-games.md](6-wip-games.md) | State and open issues of every unreleased game |
| [profiles/](profiles/) | Per-game VR profile notes and the profile format ([profiles/README.md](profiles/README.md)) |
| `tools/` | Launch, capture and analysis scripts used by the playbook |
| `evidence/` | Screenshots, captures and measurements for each gate and game |

No game files are included. You need your own legally dumped games and PS3 firmware.
