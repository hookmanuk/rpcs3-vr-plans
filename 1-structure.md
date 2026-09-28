# Workspace structure and build reference

## Repositories

| Folder | Repository | Notes |
|---|---|---|
| `rpcs3/` | https://github.com/hookmanuk/rpcs3 | The VR fork. Work is on the `openxr` branch. |
| (upstream) | https://github.com/RPCS3/rpcs3 | Remote `upstream` in `rpcs3/`. The fork's `master` tracks it. |
| `plans/` | https://github.com/hookmanuk/rpcs3-vr-plans | These plans, profile notes, evidence and tools (`main`). |
| `vr-modding-playbook/` | https://github.com/phunkaeg/vr-modding-playbook | Methodology reference. |

To set up the workspace, clone `rpcs3` (branch `openxr`, with submodules) and `rpcs3-vr-plans`
(as `plans/`) side by side, then follow the build baseline below.

## Reference repositories

1. rpcs3/
   This is authoritative for RPCS3 implementation details.

2. hindsightvr-dev/
   Study its emulator integrations, especially Tier-2 camera
   discovery, draw classification, profiles, stereo generation,
   Vulkan multiview and OpenXR architecture.

3. vr-modding-playbook/
   Read AGENTS.md and use its evidence/proof methodology,
   failure atlas, pattern catalog and reference transform/stereo
   mathematics when planning and validating experiments.

External projects are prior art, not proof that an approach
works in RPCS3. Verify all relevant assumptions against RPCS3
source and runtime behaviour.

## Windows build baseline

The authoritative instructions are `rpcs3/BUILDING.md`, the checked-in
Visual Studio solution, CMake presets, and Windows CI workflow. For the
current checkout (`9e86f165`, 2026-09-19), use:

- Visual Studio 2026 with Desktop development with C++, the latest x64/x86
  MSVC tools, a Windows 11 SDK, and C++ CMake tools for Windows.
- CMake 4.2 or newer when configuring for Visual Studio 2026.
- Qt 6.11.2 `msvc2022_64`, including Qt Multimedia and Qt SVG. This remains
  the correct Qt ABI package with Visual Studio 2026 and is also what RPCS3
  Windows CI uses.
- Vulkan SDK 1.4.341.1. Do not silently substitute a newer SDK because
  `BUILDING.md` warns that future SDK versions may not work.
- Python 3 and all Git submodules initialized recursively.

The validated local Visual Studio installation is Community 2026 Insiders 18.11.0
with MSBuild 18.11.0, MSVC 14.51.36231 and Windows SDK 10.0.26100.0. The older
10.0.22621.0 SDK is also installed.

Validated local dependency paths:

```text
Qt:     C:\Qt611\6.11.2\msvc2022_64
Vulkan: C:\VulkanSDK\1.4.341.1
```

For the Visual Studio solution route, set `QTDIR` to the Qt path above and
`VULKAN_SDK` to the Vulkan path. For a CMake route, use `Qt6_ROOT` instead
of (or as well as) `QTDIR`.

## Preferred VS 2026 build route

RPCS3 documents `rpcs3/rpcs3.sln` as the preferred Windows build and its
current CI builds that solution with Visual Studio 2026. Use the `Release`
and `x64` configuration. Restore the solution's NuGet packages before the
first build. LLVM must either be built through the solution's `llvm_build`
project or supplied as the matching RPCS3 precompiled LLVM package described
in `BUILDING.md`.

The one-time restore and full build were validated with:

```powershell
F:\rpsc3\source\.tools\nuget\nuget.exe restore rpcs3.sln -NonInteractive

$env:QTDIR = 'C:\Qt611\6.11.2\msvc2022_64'
$env:VULKAN_SDK = 'C:\VulkanSDK\1.4.341.1'
& 'C:\Program Files\Microsoft Visual Studio\18\Insiders\MSBuild\Current\Bin\amd64\MSBuild.exe' `
  rpcs3.sln /p:Configuration=Release /p:Platform=x64 `
  /p:PreferredToolArchitecture=x64 /m:16 /nr:false /v:minimal /nologo
```

NuGet 7.9.0 was downloaded from the official NuGet distribution. The validated
precompiled LLVM archive was RPCS3's `custom-build-win-22.1.8/llvmlibs_mt.7z`:

```text
Archive SHA-256: 6E6DCDF0216EA5C95262E7BED9FFCFF60D5994AC6091376BE43852B63E9BB9E9
Extracted to:    rpcs3/build/lib_ext/Release-x64/llvm_build
```

For normal edits to files owned by the `rpcs3` application project, do not build the
whole solution again. Build that project without traversing its already-built project
references:

```powershell
$env:QTDIR = 'C:\Qt611\6.11.2\msvc2022_64'
$env:VULKAN_SDK = 'C:\VulkanSDK\1.4.341.1'
& 'C:\Program Files\Microsoft Visual Studio\18\Insiders\MSBuild\Current\Bin\amd64\MSBuild.exe' `
  rpcs3\rpcs3.vcxproj /t:Build /p:Configuration=Release /p:Platform=x64 `
  /p:PreferredToolArchitecture=x64 /p:BuildProjectReferences=false `
  '/p:SolutionDir=F:\rpsc3\source\rpcs3\' /m:1 /nr:false /v:minimal /nologo
```

This incremental command was verified after changing `main_window.cpp`: it compiled
that file and relinked `rpcs3.exe` in about 24 seconds. A solution-wide incremental
build unnecessarily revisited third-party CMake projects and attempted to fetch
Abseil, so reserve solution builds for dependency/project changes.

Expected solution-build executable:

```text
rpcs3/bin/rpcs3.exe
```

Do not assume the checked-in `msvc` CMake preset selects VS 2026: at this
commit it explicitly names the `Visual Studio 17 2022` generator. If we use
CMake with VS 2026, first confirm the generator exposed by `cmake --help`
and configure with CMake 4.2 or newer. Do not edit the upstream preset merely
to get a local build unless we intentionally want that change in the fork.

## Verified CMake findings and troubleshooting

The VS 2022 CMake tree successfully detected Qt and Vulkan with:

```powershell
$env:Qt6_ROOT = 'C:\Qt611\6.11.2\msvc2022_64'
$env:VULKAN_SDK = 'C:\VulkanSDK\1.4.341.1'
cmake --fresh --preset msvc -DUSE_SYSTEM_SDL=OFF `
  -DALSOFT_ENABLE_MODULES=OFF `
  -DCMAKE_DISABLE_FIND_PACKAGE_SDL3=TRUE
```

Those two extra cache settings came from observed failures when reusing the
generated tree:

- `ALSOFT_ENABLE_MODULES=OFF` avoids an OpenAL/MSVC C++20 module dependency
  race (`could not find module 'alc.context'`). RPCS3 does not require the
  optional OpenAL module form.
- `CMAKE_DISABLE_FIND_PACKAGE_SDL3=TRUE` prevents OpenAL from trying to
  include SDL's in-tree generated export as if it were an installed package.
  A genuinely new build directory may not need this workaround, but it is
  safe for RPCS3's bundled Windows audio configuration.

Use bounded MSBuild parallelism and disable reusable nodes. An unbounded
`--parallel` launch created about 190 MSBuild worker processes on this machine
and failed around named-pipe communication. The stable form was:

```powershell
cmake --build --preset msvc-release --target rpcs3 --parallel 16 -- /nr:false
```

Expected CMake-build executable:

```text
rpcs3/build-msvc/bin/rpcs3.exe
```

The VS 2022 14.43 toolset compiled the large bundled dependency set, including
LLVM and OpenAL, but could not compile this checkout's newer C++ source in
`cellVdec.cpp`. A temporary change to `Utilities/JIT.h` was tested and then
fully reverted. Treat that failure as a toolchain mismatch, not an RPCS3 or
VR-fork source defect.

Build directories contain generated files and downloaded dependencies. Do not
mistake changes under them for intentional VR source changes. Before the first
VR edit, verify the RPCS3 Git worktree is clean; after editing, verify the
newly built executable and its visible `[VR DEV]` title marker.
