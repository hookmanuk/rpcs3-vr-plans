// freezecheck [SECONDS=30] [CORES=0,8] [THRESHOLD_MS=0.8]: one TIME_CRITICAL thread pinned to each core spins reading the
// clock and records every gap over the threshold. A gap seen on every core at the same instant is a machine-wide freeze
// (SMI, hypervisor, a driver holding all cores); a gap on one core is that core's DPC/ISR or a preempting thread.
// Build (env.cmd): clang-cl /EHsc /O2 freezecheck.cpp /Fe:freezecheck.exe
#define NOMINMAX
#include <windows.h>

#include <algorithm>
#include <atomic>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <thread>
#include <vector>

struct Gap
{
    double atMs, lengthMs;
    int core;
};

int main(int argc, char** argv)
{
    const double seconds = argc > 1 ? atof(argv[1]) : 30.0;
    std::vector<int> cores;
    {
        std::string list = argc > 2 ? argv[2] : "0,8";
        for (size_t i = 0; i < list.size();)
        {
            size_t j = list.find(',', i);
            if (j == std::string::npos)
                j = list.size();
            cores.push_back(atoi(list.substr(i, j - i).c_str()));
            i = j + 1;
        }
    }
    const double threshold = argc > 3 ? atof(argv[3]) : 0.8;
    LARGE_INTEGER f;
    QueryPerformanceFrequency(&f);
    const double toMs = 1000.0 / double(f.QuadPart);
    std::vector<std::vector<Gap>> gaps(cores.size());
    std::vector<std::thread> threads;
    std::atomic<bool> stop{ false };
    LARGE_INTEGER start;
    QueryPerformanceCounter(&start);
    for (size_t c = 0; c < cores.size(); c++)
        threads.emplace_back([&, c] {
            SetThreadAffinityMask(GetCurrentThread(), DWORD_PTR(1) << cores[c]);
            SetThreadPriority(GetCurrentThread(), THREAD_PRIORITY_TIME_CRITICAL);
            LARGE_INTEGER last, now;
            QueryPerformanceCounter(&last);
            while (!stop.load(std::memory_order_relaxed))
            {
                QueryPerformanceCounter(&now);
                const double gap = double(now.QuadPart - last.QuadPart) * toMs;
                if (gap > threshold)
                    gaps[c].push_back({ double(last.QuadPart - start.QuadPart) * toMs, gap, cores[c] });
                last = now;
            }
        });
    Sleep(DWORD(seconds * 1000));
    stop.store(true);
    for (auto& t : threads)
        t.join();
    std::vector<Gap> all;
    for (size_t c = 0; c < cores.size(); c++)
    {
        all.insert(all.end(), gaps[c].begin(), gaps[c].end());
        double worst = 0, total = 0;
        for (const Gap& g : gaps[c])
            worst = std::max(worst, g.lengthMs), total += g.lengthMs;
        printf("core %d: %zu gaps over %.1f ms in %.0f s, worst %.2f ms, total %.1f ms\n", cores[c], gaps[c].size(), threshold, seconds, worst, total);
    }
    std::sort(all.begin(), all.end(), [](const Gap& a, const Gap& b) { return a.atMs < b.atMs; });
    // Gaps that overlap on every core: machine-wide.
    int shared = 0;
    for (size_t i = 0; i < all.size(); i++)
    {
        std::vector<int> seen{ all[i].core };
        for (size_t j = i + 1; j < all.size() && all[j].atMs < all[i].atMs + all[i].lengthMs; j++)
            if (std::find(seen.begin(), seen.end(), all[j].core) == seen.end())
                seen.push_back(all[j].core);
        if (seen.size() == cores.size())
            shared++;
    }
    printf("machine-wide (seen on every core at once): %d\n", shared);
    printf("gaps (s, ms, core):");
    int n = 0;
    for (const Gap& g : all)
        if (n++ < 60)
            printf(" %.2f:%.2f/%d", g.atMs / 1000.0, g.lengthMs, g.core);
    printf("\n");
    return 0;
}
