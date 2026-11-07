// vrstats SECONDS [DLL]: SteamVR's own account of the running app, as a background OpenVR client: what it presented, dropped and reprojected, and its
// per-frame timings (app CPU and GPU before and after submit, the compositor's own GPU and CPU). Believe this over the game's counters.
// Build: clang-cl /EHsc /O2 /I H:\UEVRMods\openvr\headers vrstats.cpp /Fe:vrstats.exe
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <cstdio>
#include <cstdlib>
#include <vector>
#include <algorithm>
#include "openvr.h"

typedef void* (*GetGeneric)(const char*, vr::EVRInitError*);
typedef uint32_t (*InitInternal)(vr::EVRInitError*, vr::EVRApplicationType);

static double Mean(std::vector<float>& v)
{
    if (v.empty()) return 0;
    double s = 0;
    for (float x : v) s += x;
    return s / v.size();
}
static double Pct(std::vector<float> v, double p)
{
    if (v.empty()) return 0;
    std::sort(v.begin(), v.end());
    return v[std::min(v.size() - 1, size_t(v.size() * p))];
}

int main(int argc, char** argv)
{
    const int seconds = argc > 1 ? atoi(argv[1]) : 10;
    const char* dll = argc > 2 ? argv[2] : "H:\\UEVRMods\\openvr\\bin\\win64\\openvr_api.dll";
    HMODULE m = LoadLibraryA(dll);
    if (!m) { printf("no %s\n", dll); return 1; }
    auto init = (InitInternal)GetProcAddress(m, "VR_InitInternal");
    auto get = (GetGeneric)GetProcAddress(m, "VR_GetGenericInterface");
    vr::EVRInitError e = vr::VRInitError_None;
    init(&e, vr::VRApplication_Background);
    if (e != vr::VRInitError_None) { printf("init failed: %d\n", int(e)); return 1; }
    auto* c = static_cast<vr::IVRCompositor*>(get(vr::IVRCompositor_Version, &e));
    auto* sys = static_cast<vr::IVRSystem*>(get(vr::IVRSystem_Version, &e));
    if (!c) { printf("no compositor interface: %d\n", int(e)); return 1; }
    if (sys)
        printf("display %.1f Hz\n", sys->GetFloatTrackedDeviceProperty(0, vr::Prop_DisplayFrequency_Float));
    vr::Compositor_CumulativeStats a{}, b{};
    c->GetCumulativeStats(&a, sizeof(a));
    std::vector<float> interval, pre, post, total, compGpu, compCpu, idle, wait;
    uint32_t last = 0, reprojected = 0, misPresented = 0, dropped = 0, presents = 0, n = 0;
    const ULONGLONG end = GetTickCount64() + seconds * 1000ull;
    while (GetTickCount64() < end)
    {
        vr::Compositor_FrameTiming t{};
        t.m_nSize = sizeof(t);
        if (c->GetFrameTiming(&t, 0) && t.m_nFrameIndex != last)
        {
            last = t.m_nFrameIndex;
            n++;
            interval.push_back(t.m_flClientFrameIntervalMs);
            pre.push_back(t.m_flPreSubmitGpuMs);
            post.push_back(t.m_flPostSubmitGpuMs);
            total.push_back(t.m_flTotalRenderGpuMs);
            compGpu.push_back(t.m_flCompositorRenderGpuMs);
            compCpu.push_back(t.m_flCompositorRenderCpuMs);
            idle.push_back(t.m_flCompositorIdleCpuMs);
            wait.push_back(t.m_flWaitForPresentCpuMs);
            presents += t.m_nNumFramePresents > 1 ? 1 : 0;
            misPresented += t.m_nNumMisPresented;
            dropped += t.m_nNumDroppedFrames;
            reprojected += t.m_nReprojectionFlags != 0 ? 1 : 0;
        }
        Sleep(2);
    }
    c->GetCumulativeStats(&b, sizeof(b));
    const double s = seconds;
    printf("cumulative per second: presents %.1f, dropped %.1f, reprojected %.1f, loading %.1f (pid %u -> %u)\n", (b.m_nNumFramePresents - a.m_nNumFramePresents) / s,
        (b.m_nNumDroppedFrames - a.m_nNumDroppedFrames) / s, (b.m_nNumReprojectedFrames - a.m_nNumReprojectedFrames) / s, (b.m_nNumLoading - a.m_nNumLoading) / s, a.m_nPid, b.m_nPid);
    printf("frames seen %u in %d s (%.1f/s): shown more than once %u, mispresented %u, dropped %u, reprojection flags on %u\n", n, seconds, n / s, presents, misPresented, dropped, reprojected);
    printf("app frame interval ms mean %.2f p99 %.2f | GPU before submit mean %.2f p99 %.2f | after submit mean %.2f p99 %.2f | app GPU total mean %.2f p99 %.2f\n", Mean(interval), Pct(interval, .99), Mean(pre), Pct(pre, .99), Mean(post), Pct(post, .99), Mean(total), Pct(total, .99));
    printf("compositor GPU ms mean %.2f p99 %.2f max %.2f | compositor CPU mean %.2f | idle CPU mean %.2f | wait for present mean %.2f\n", Mean(compGpu), Pct(compGpu, .99), Pct(compGpu, 1.0), Mean(compCpu), Mean(idle), Mean(wait));
    typedef void (*Shut)();
    if (auto sh = (Shut)GetProcAddress(m, "VR_ShutdownInternal")) sh();
    return 0;
}
