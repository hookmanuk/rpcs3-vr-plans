// Development (XERENGE_DATAWATCH=1): which guest function writes a guest address. plume names the address (the
// environment's XERENGE_DATAWATCH_ADDR, a guest virtual address, e.g. a draw's vertex buffer); every thread gets a
// hardware write breakpoint on it (debug register 0, 8 bytes), and the writing instruction is mapped back to its
// recompiled guest function through PPCFuncMappings. Logged from the frame's tick, never from the handler.
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <array>
#include <atomic>
#include <chrono>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <string>
#include <thread>
#include <unordered_map>
#include <vector>

#include <rex/hook.h>
#include <rex/logging.h>
#include <rex/ppc.h>

#include "guest_memory.h"

#ifdef _WIN32
#include <windows.h>
#include <tlhelp32.h>
#endif

namespace xerenge {
namespace {
#ifdef _WIN32
std::array<std::atomic<uint64_t>, 8192> g_hits{};  // host addresses of the writing instructions
std::atomic<uint32_t> g_hit_count{0};
uintptr_t g_watched = 0;

LONG CALLBACK WatchHandler(EXCEPTION_POINTERS* info) {
  if (info->ExceptionRecord->ExceptionCode != EXCEPTION_SINGLE_STEP || (info->ContextRecord->Dr6 & 0xF) == 0) {
    return EXCEPTION_CONTINUE_SEARCH;
  }
  const uint32_t n = g_hit_count.fetch_add(1);
  if (n < g_hits.size()) {
    g_hits[n] = uint64_t(info->ExceptionRecord->ExceptionAddress);
  } else {
    info->ContextRecord->Dr7 &= ~uint64_t(0xFF);  // enough: this thread stops watching
  }
  info->ContextRecord->Dr6 = 0;
  return EXCEPTION_CONTINUE_EXECUTION;
}

void ArmAllThreads(const uintptr_t (&addresses)[4]) {
  const HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);
  if (snapshot == INVALID_HANDLE_VALUE) {
    return;
  }
  THREADENTRY32 entry{sizeof(entry)};
  uint32_t armed = 0;
  for (BOOL ok = Thread32First(snapshot, &entry); ok; ok = Thread32Next(snapshot, &entry)) {
    if (entry.th32OwnerProcessID != GetCurrentProcessId() || entry.th32ThreadID == GetCurrentThreadId()) {
      continue;
    }
    if (const HANDLE thread = OpenThread(THREAD_GET_CONTEXT | THREAD_SET_CONTEXT | THREAD_SUSPEND_RESUME, FALSE,
                                         entry.th32ThreadID)) {
      if (SuspendThread(thread) != DWORD(-1)) {
        CONTEXT context{};
        context.ContextFlags = CONTEXT_DEBUG_REGISTERS;
        if (GetThreadContext(thread, &context)) {
          context.Dr0 = addresses[0];
          context.Dr1 = addresses[1];
          context.Dr2 = addresses[2];
          context.Dr3 = addresses[3];
          // L0-L3 on, each R/W = 01 (writes), LEN = 10 (8 bytes).
          uint64_t dr7 = 0;
          for (int i = 0; i < 4; ++i) {
            dr7 |= uint64_t(1) << (2 * i);
            dr7 |= uint64_t((std::getenv("XERENGE_DATAWATCH_READS") ? 3u : 1u) | (2u << 2)) << (16 + 4 * i);
          }
          context.Dr7 = dr7;
          armed += SetThreadContext(thread, &context) ? 1 : 0;
        }
        ResumeThread(thread);
      }
      CloseHandle(thread);
    }
  }
  CloseHandle(snapshot);
  REXLOG_INFO("datawatch: {} threads watch {:016X} {:016X} {:016X} {:016X}", armed, addresses[0], addresses[1],
              addresses[2], addresses[3]);
}

// The guest function a host instruction is in: the mapping with the highest host address at or below it.
const PPCFuncMapping* FunctionOf(uint64_t host) {
  const PPCFuncMapping* best = nullptr;
  for (const PPCFuncMapping* m = PPCFuncMappings; m->host != nullptr; ++m) {
    const uint64_t h = uint64_t(reinterpret_cast<uintptr_t>(m->host));
    if (h <= host && (!best || h > uint64_t(reinterpret_cast<uintptr_t>(best->host)))) {
      best = m;
    }
  }
  return best;
}
#endif
}  // namespace

namespace {
#ifdef _WIN32
// Development (XERENGE_BARSCAN=1): a value found by how it changes. %TEMP%\xerenge_vr\SNAP0, SNAP1, SNAP2 (empty files)
// take the guest's committed memory (the heap at 0x40000000-0x60000000 and the image's data, 0x82000000-0x84000000) as
// floats; after SNAP2 the candidates - 0, then rising, at most 1 - are logged; POKE writes 1.0 into all of them.
struct Snapshot {
  std::vector<std::pair<uint32_t, std::vector<uint32_t>>> regions;  // guest start, its words
};
Snapshot g_snaps[3];
std::vector<uint32_t> g_candidates;
std::vector<float> g_candidate_v2;  // each one's value at SNAP2

Snapshot TakeSnapshot(uint8_t* base) {
  Snapshot s;
  const uintptr_t b = reinterpret_cast<uintptr_t>(base);
  for (const auto [lo, hi] : {std::pair<uint32_t, uint32_t>{0x40000000u, 0x60000000u}, {0x82000000u, 0x84000000u}}) {
    for (uintptr_t at = b + lo; at < b + hi;) {
      MEMORY_BASIC_INFORMATION mbi{};
      if (!VirtualQuery(reinterpret_cast<const void*>(at), &mbi, sizeof(mbi))) break;
      const uintptr_t start = std::max(reinterpret_cast<uintptr_t>(mbi.BaseAddress), at);
      const uintptr_t end = std::min(reinterpret_cast<uintptr_t>(mbi.BaseAddress) + mbi.RegionSize, b + hi);
      if (mbi.State == MEM_COMMIT && (mbi.Protect & (PAGE_READWRITE | PAGE_EXECUTE_READWRITE)) && !(mbi.Protect & PAGE_GUARD)) {
        std::vector<uint32_t> words((end - start) / 4);
        std::memcpy(words.data(), reinterpret_cast<const void*>(start), words.size() * 4);
        s.regions.push_back({uint32_t(start - b), std::move(words)});
      }
      at = end;
    }
  }
  return s;
}

float BeFloat(uint32_t raw) {
  const uint32_t v = _byteswap_ulong(raw);
  float f;
  std::memcpy(&f, &v, 4);
  return f;
}

void BarScan(uint8_t* base) {
  static const bool enabled = std::getenv("XERENGE_BARSCAN") != nullptr;
  if (!enabled) return;
  const std::string dir = std::string(std::getenv("TEMP")) + "\\xerenge_vr\\";
  for (int i = 0; i < 3; ++i) {
    const std::string f = dir + "SNAP" + std::to_string(i);
    if (GetFileAttributesA(f.c_str()) != INVALID_FILE_ATTRIBUTES) {
      DeleteFileA(f.c_str());
      g_snaps[i] = TakeSnapshot(base);
      size_t words = 0;
      for (const auto& r : g_snaps[i].regions) words += r.second.size();
      REXLOG_INFO("barscan: snapshot {} of {} MB", i, words * 4 >> 20);
      if (i == 2) {
        g_candidates.clear();
        g_candidate_v2.clear();
        for (size_t r = 0; r < g_snaps[2].regions.size() && r < g_snaps[0].regions.size() && r < g_snaps[1].regions.size(); ++r) {
          const auto& a = g_snaps[0].regions[r];
          const auto& b1 = g_snaps[1].regions[r];
          const auto& c = g_snaps[2].regions[r];
          if (a.first != b1.first || a.first != c.first) continue;
          const size_t n = std::min({a.second.size(), b1.second.size(), c.second.size()});
          for (size_t k = 0; k < n; ++k) {
            static const bool ints = std::getenv("XERENGE_BARSCAN_INT") != nullptr;
            const float v0 = BeFloat(a.second[k]), v1 = BeFloat(b1.second[k]), v2 = BeFloat(c.second[k]);
            const uint32_t i0 = _byteswap_ulong(a.second[k]), i1 = _byteswap_ulong(b1.second[k]),
                           i2 = _byteswap_ulong(c.second[k]);
            static const float target = std::getenv("XERENGE_BARSCAN_TARGET") ? float(std::atof(std::getenv("XERENGE_BARSCAN_TARGET"))) : -1.f;
            static const bool stable = std::getenv("XERENGE_BARSCAN_STABLE") != nullptr;
            static const bool late = std::getenv("XERENGE_BARSCAN_LATE") != nullptr;  // TARGET, settled, float or int
            const bool hit = late ? ((v0 == 0.f && v2 == v1 && std::fabs(v1 - target) < 0.6f) ||
                                     (i0 == 0 && i2 == i1 && i1 == uint32_t(target + 0.5f)))
                           : stable ? (v0 == 0.f && v1 > 0.02f && v1 < 0.5f && v2 == v1) : target >= 0.f ? (v0 == 0.f && std::fabs(v1 - target) < 0.012f && std::fabs(v2 - v1) < 0.002f)
                             : ints ? (i0 == 0 && i1 >= 1 && i2 > i1 && i2 <= 60)
                                    : (v0 == 0.f && v1 > 0.01f && v2 > v1 && v2 <= 1.0f);
            if (hit) {
              g_candidates.push_back(a.first + uint32_t(k * 4));
              g_candidate_v2.push_back(v2);
            }
          }
        }
        std::string t;
        for (size_t k = 0, shown = 0; k < g_candidates.size() && shown < 200; ++k) {
          if (g_candidates[k] < 0x80000000u) continue;  // the image's data only (the heap's are particles)
          ++shown;
          t += fmt::format(" {:08X}={:.3f}", g_candidates[k], BeFloat(*reinterpret_cast<const uint32_t*>(base + g_candidates[k])));
        }
        REXLOG_INFO("barscan: {} candidates:{}", g_candidates.size(), t);
      }
    }
  }
  static auto hold_until = std::chrono::steady_clock::time_point{};
  static uint32_t hold_value = 0;
  static bool hold_float = false;
  const std::string fpoke = dir + "FPOKE";  // "F": every candidate held at the float F for 3 s
  if (GetFileAttributesA(fpoke.c_str()) != INVALID_FILE_ATTRIBUTES) {
    float f = 1.f;
    if (std::FILE* fp = std::fopen(fpoke.c_str(), "rb")) {
      std::fscanf(fp, "%f", &f);
      std::fclose(fp);
    }
    DeleteFileA(fpoke.c_str());
    std::memcpy(&hold_value, &f, 4);
    hold_float = true;
    hold_until = std::chrono::steady_clock::now() + std::chrono::seconds(3);
    REXLOG_INFO("barscan: {} candidates held at {:.3f}", g_candidates.size(), f);
  }
  (void)hold_float;
  if (std::chrono::steady_clock::now() < hold_until) {
    const uint32_t v = _byteswap_ulong(hold_value);
    static const char* const only = std::getenv("XERENGE_BARSCAN_ONLY");  // "ADDR,ADDR": just these candidates
    for (const uint32_t g : g_candidates) {
      if (only && !std::strstr(only, fmt::format("{:08X}", g).c_str())) continue;
      static const bool late_hold = std::getenv("XERENGE_BARSCAN_LATE") != nullptr;
      if (late_hold) {  // as the candidate was: a small integer, or a float
        uint32_t cur;
        std::memcpy(&cur, base + g, 4);
        cur = _byteswap_ulong(cur);
        float hf;
        std::memcpy(&hf, &hold_value, 4);
        const uint32_t as_int = _byteswap_ulong(uint32_t(hf));
        std::memcpy(base + g, cur < 0x10000u ? &as_int : &v, 4);
        continue;
      }
      std::memcpy(base + g, &v, 4);
    }
  }
  const std::string ipoke = dir + "IPOKE";  // "N": every candidate held at the integer N for 3 s
  if (GetFileAttributesA(ipoke.c_str()) != INVALID_FILE_ATTRIBUTES) {
    if (std::FILE* f = std::fopen(ipoke.c_str(), "rb")) {
      std::fscanf(f, "%u", &hold_value);
      std::fclose(f);
    }
    DeleteFileA(ipoke.c_str());
    hold_until = std::chrono::steady_clock::now() + std::chrono::seconds(3);
    REXLOG_INFO("barscan: {} candidates held at {}", g_candidates.size(), hold_value);
  }
  const std::string poke = dir + "POKE";
  if (GetFileAttributesA(poke.c_str()) != INVALID_FILE_ATTRIBUTES) {
    // "FRACTION TOLERANCE": only the candidates whose value at SNAP2 was that (the bar as read off the screen).
    float fraction = -1.f, tolerance = 0.05f;
    if (std::FILE* f = std::fopen(poke.c_str(), "rb")) {
      std::fscanf(f, "%f %f", &fraction, &tolerance);
      std::fclose(f);
    }
    DeleteFileA(poke.c_str());
    const uint32_t one = _byteswap_ulong(0x3F800000u);
    size_t poked = 0;
    std::string t;
    for (size_t k = 0; k < g_candidates.size(); ++k) {
      if (fraction >= 0.f && std::fabs(g_candidate_v2[k] - fraction) > tolerance) continue;
      if (poked >= 5000) break;
      std::memcpy(base + g_candidates[k], &one, 4);
      t += fmt::format(" {:08X}({:.3f})", g_candidates[k], g_candidate_v2[k]);
      ++poked;
    }
    REXLOG_INFO("barscan: {} candidates near {:.3f} set to 1.0:{}", poked, fraction, t);
  }
}
#endif
}  // namespace

void TexDump(uint8_t* base) {
#ifdef _WIN32
  // Development (XERENGE_POKE=address=value,...): 32-bit words written on every call (tweakables, e.g. Burnout's
  // "Min boost power for crash breaker" at 825F8DCC).
  static const char* const pokes_env = std::getenv("XERENGE_POKE");
  if (const char* pokes = pokes_env) {
    std::string s(pokes);
    size_t at = 0;
    while (at < s.size()) {
      const size_t comma = s.find(',', at);
      const std::string one = s.substr(at, comma == std::string::npos ? std::string::npos : comma - at);
      at = comma == std::string::npos ? s.size() : comma + 1;
      const size_t eq = one.find('=');
      if (eq == std::string::npos) continue;
      xerenge::StoreGuestU32(base, uint32_t(std::strtoul(one.substr(0, eq).c_str(), nullptr, 16)),
                             uint32_t(std::strtoul(one.substr(eq + 1).c_str(), nullptr, 16)));
    }
  }
  static bool told = false;
  if (!told) {
    told = true;
    REXLOG_INFO("texdump: list {} temp {}", std::getenv("XERENGE_TEXDUMP") ? std::getenv("XERENGE_TEXDUMP") : "-", std::getenv("TEMP") ? std::getenv("TEMP") : "-");
  }
  // Development (XERENGE_TEXDUMP=physical,physical,...): 64 KB from each, once, when %TEMP%\xerenge_vr\TEXDUMP exists,
  // to %TEMP%\xerenge_vr\tex_<address>.bin.
  static const char* const texdump_env = std::getenv("XERENGE_TEXDUMP");
  if (const char* list = texdump_env) {
    const std::string dir = std::string(std::getenv("TEMP")) + "\\xerenge_vr\\";
    const std::string trigger = dir + "TEXDUMP";
    if (GetFileAttributesA(trigger.c_str()) != INVALID_FILE_ATTRIBUTES) {
      DeleteFileA(trigger.c_str());
      std::string s(list);
      size_t at = 0;
      while (at < s.size()) {
        const size_t comma = s.find(',', at);
        const std::string one = s.substr(at, comma == std::string::npos ? std::string::npos : comma - at);
        at = comma == std::string::npos ? s.size() : comma + 1;
        const uint32_t addr = uint32_t(std::strtoul(one.c_str(), nullptr, 16));
        if (std::FILE* f = std::fopen((dir + "tex_" + one + ".bin").c_str(), "wb")) {
          std::fwrite(base + 0xA0000000u + addr, 1, 0x10000, f);
          std::fclose(f);
        }
        REXLOG_INFO("texdump: {:08X}", addr);
      }
      // And the image (82000000-83000000, committed pages; the rest zero) to image.bin.
      if (std::FILE* f = std::fopen((dir + "image.bin").c_str(), "wb")) {
        std::vector<uint8_t> page(0x1000);
        for (uint32_t a = 0x82000000u; a < 0x83000000u; a += 0x1000) {
          MEMORY_BASIC_INFORMATION mbi{};
          const bool ok = VirtualQuery(base + a, &mbi, sizeof(mbi)) && mbi.State == MEM_COMMIT &&
                          !(mbi.Protect & (PAGE_NOACCESS | PAGE_GUARD));
          if (ok) {
            std::memcpy(page.data(), base + a, 0x1000);
          } else {
            std::fill(page.begin(), page.end(), uint8_t(0));
          }
          std::fwrite(page.data(), 1, 0x1000, f);
        }
        std::fclose(f);
        REXLOG_INFO("texdump: image written");
      }
    }
  }
#endif
}

void DevWatchTick(uint8_t* base) {
#ifdef _WIN32
  BarScan(base);
  TexDump(base);
  static const bool enabled = std::getenv("XERENGE_DATAWATCH") != nullptr;
  if (!enabled) {
    return;
  }
  static auto checked = std::chrono::steady_clock::now();
  if (std::chrono::steady_clock::now() - checked < std::chrono::milliseconds(500)) {
    return;
  }
  checked = std::chrono::steady_clock::now();
  if (g_watched == 0) {
    static const auto started = std::chrono::steady_clock::now();
    if (const char* delay = std::getenv("XERENGE_DATAWATCH_DELAY")) {
      if (delay[0] == 'f') {  // "file": once %TEMP%\xerenge_vr\ARM exists
        const std::string arm = std::string(std::getenv("TEMP")) + "\\xerenge_vr\\ARM";
        if (GetFileAttributesA(arm.c_str()) == INVALID_FILE_ATTRIBUTES) {
          return;
        }
        DeleteFileA(arm.c_str());
      } else if (std::chrono::steady_clock::now() - started < std::chrono::seconds(std::atoi(delay))) {
        return;
      }
    }
    char text[32] = {};
    if (GetEnvironmentVariableA("XERENGE_DATAWATCH_ADDR", text, sizeof(text)) > 0) {
      const uint32_t guest = uint32_t(std::strtoul(text, nullptr, 16));
      const uintptr_t b = reinterpret_cast<uintptr_t>(base);
      // A live vertex (x, y and z all set: the buffer's first slots are often unused), through each of the 360's views
      // of its physical memory (the GPU reads one, the CPU may write another): 0xE0000000 4 KB pages (physical +
      // 0x1000), 0xA0000000 / 0xC0000000 / 0x40000000 the physical address itself.
      uint32_t live = ~0u;
      for (uint32_t v = 0; v < 1600 && live == ~0u; ++v) {
        const auto* q = reinterpret_cast<const uint32_t*>(b + guest + v * 16);
        if (std::getenv("XERENGE_DATAWATCH_RAW") || (q[0] && q[1] && q[2])) {
          live = v;
        }
      }
      if (live == ~0u) {
        return;  // none yet: the next tick
      }
      const uint32_t at = guest + live * 16;
      const uint32_t physical = (at & 0x1FFFFFFFu) + (at >= 0xE0000000u ? 0x1000u : 0u);
      const uintptr_t addresses[4] = {b + at, b + 0xA0000000u + physical, b + 0xC0000000u + physical,
                                      b + 0x40000000u + physical};
      REXLOG_INFO("datawatch: vertex {} at {:08X}", live, at);
      g_watched = addresses[0];
      AddVectoredExceptionHandler(1, WatchHandler);
      // From a thread of its own: the one ticking here (the game's main thread) is the likeliest writer, and a thread
      // cannot set its own debug registers.
      std::thread([addresses] { ArmAllThreads(addresses); }).join();
    }
    return;
  }
  static uint32_t reported = 0;
  const uint32_t n = std::min<uint32_t>(g_hit_count.load(), uint32_t(g_hits.size()));
  for (; reported < n; ++reported) {
    const uint64_t host = g_hits[reported].load();
    const PPCFuncMapping* f = FunctionOf(host);
    REXLOG_INFO("datawatch: write {} at host {:016X} in sub_{:08X} (+{:X})", reported, host,
                f ? uint32_t(f->guest) : 0u, f ? host - uint64_t(reinterpret_cast<uintptr_t>(f->host)) : 0);
  }
#else
  (void)base;
#endif
}

}  // namespace xerenge

// Development (XERENGE_PARTLOG=1): the particle evaluator (sub_8214F860, r3 the system): its clock, its gravity and the
// first live particles' start and velocity, every 2 s.
extern "C" void __imp__sub_8214F860(PPCContext& __restrict, uint8_t*);
extern "C" void __imp__sub_8214F6E8(PPCContext& __restrict, uint8_t*);
namespace {
bool g_injecting = false;
}
// Development (XERENGE_SPAWNLOG=1): every particle spawn (sub_8214F6E8: r3 the system, r4 the start, r5 the velocity,
// f1 the time, f2 the ground) - its caller, start and velocity, the first 400.
extern "C" void __imp__sub_820DFDA8(PPCContext& __restrict, uint8_t*);
// Development (XERENGE_EXPLODE=1): %TEMP%\xerenge_vr\EXPLODE blows up the player's car the game's own way - sub_820DFDA8
// (r4 the car, each frame) runs a car's explosion when bit 8 of its state's (car +2664) byte +12893 is set, then clears
// it; the player's car has +624 == 1.
REX_HOOK_RAW(sub_820DFDA8) {
  static const bool explode = std::getenv("XERENGE_EXPLODE") != nullptr;
  if (explode && base[ctx.r4.u32 + 624] == 1) {
    const std::string trigger = std::string(std::getenv("TEMP")) + "\\xerenge_vr\\EXPLODE";
    if (GetFileAttributesA(trigger.c_str()) != INVALID_FILE_ATTRIBUTES) {
      DeleteFileA(trigger.c_str());
      const uint32_t state = xerenge::LoadGuestU32(base, ctx.r4.u32 + 2664);
      base[state + 12893] |= 8;
      REXLOG_INFO("explode: car {:08X} state {:08X} flags now {:02X}", ctx.r4.u32, state, int(base[state + 12893]));
    }
  }
  __imp__sub_820DFDA8(ctx, base);
}
extern "C" void __imp__sub_82174800(PPCContext& __restrict, uint8_t*);
// Development (XERENGE_FXLOG=1): each effect drawn (sub_82174800: r3/r4 the instance), its type (+176) and definition.
REX_HOOK_RAW(sub_82174800) {
  static const bool log = std::getenv("XERENGE_FXLOG") != nullptr;
  if (log) {
    static std::unordered_map<uint32_t, int> seen;
    const uint32_t inst = ctx.r4.u32;
    if (seen[inst]++ == 0) {
      const uint32_t def = xerenge::LoadGuestU32(base, inst + 60);
      const uint32_t name = xerenge::LoadGuestU32(base, def);
      std::string s;
      for (uint32_t k = 0; k < 32 && name >= 0x82000000u && name < 0x83000000u; ++k) {
        const char c = char(base[name + k]);
        if (!c) break;
        s += c;
      }
      REXLOG_INFO("fxdraw: inst {:08X} r3 {:08X} def {:08X} {} type {}", inst, ctx.r3.u32, def, s,
                  xerenge::LoadGuestU32(base, inst + 176));
    }
  }
  const uint32_t drawn_inst = ctx.r4.u32;
  __imp__sub_82174800(ctx, base);
  // The first quad of each glass / debris draw (vertices from 829D6180, 32 bytes: position, then the rest), 3 a second.
  if (log && xerenge::LoadGuestU32(base, drawn_inst + 176) == 4) {
    static auto last = std::chrono::steady_clock::now();
    if (std::chrono::steady_clock::now() - last > std::chrono::milliseconds(300)) {
      last = std::chrono::steady_clock::now();
      const auto lf = [&](uint32_t a) {
        const uint32_t u = xerenge::LoadGuestU32(base, a);
        float v;
        std::memcpy(&v, &u, 4);
        return v;
      };
      std::string t;
      for (uint32_t q = 0; q < 2; ++q) {
        for (uint32_t k = 0; k < 4; ++k) {
          const uint32_t v = 0x829D6180u + (q * 4 + k) * 32;
          t += fmt::format(" [{:.2f} {:.2f} {:.2f} | {:08X} {:.2f} {:.2f}]", lf(v), lf(v + 4), lf(v + 8),
                           xerenge::LoadGuestU32(base, v + 12), lf(v + 16), lf(v + 20));
        }
        t += " ||";
      }
      REXLOG_INFO("fxquad: inst {:08X}{}", drawn_inst, t);
    }
  }
}
extern "C" void __imp__sub_8214D788(PPCContext& __restrict, uint8_t*);
// Development (XERENGE_FXLOG=1): every billboard particle emitted (sub_8214D788: r3 the effect's instance, r4 the
// start, r5 the velocity, f1 the time, f2-f6 its sizes and the like, the caller's bytes 95 / 103 its flags) - the first
// of each instance and caller in full.
REX_HOOK_RAW(sub_8214D788) {
  static const bool log = std::getenv("XERENGE_FXLOG") != nullptr;
  if (log) {
    static std::unordered_map<uint64_t, int> seen;
    const uint64_t key = uint64_t(ctx.r3.u32) << 32 | uint32_t(ctx.lr);
    // Every emit of the explosion and fire effects (instances 15-28, 0x100 each from 827A7E20), the first of the rest.
    const uint32_t index = (ctx.r3.u32 - 0x827A7E20u) / 0x100u;
    static int explosion_emits = 0;
    const bool explosion = index >= 15 && index <= 28 && explosion_emits < 4000;
    if (explosion) ++explosion_emits;
    if (seen[key]++ == 0 || explosion) {
      const auto lf = [&](uint32_t a) {
        const uint32_t u = xerenge::LoadGuestU32(base, a);
        float v;
        std::memcpy(&v, &u, 4);
        return v;
      };
      REXLOG_INFO("fxemit: inst {:08X} def {:08X} lr {:08X} p {:.2f} {:.2f} {:.2f} v {:.2f} {:.2f} {:.2f} f1 {:.3f} f2 {:.3f} "
                  "f3 {:.3f} f4 {:.3f} f5 {:.3f} f6 {:.3f} flags {} {}",
                  ctx.r3.u32, xerenge::LoadGuestU32(base, ctx.r3.u32 + 60), uint32_t(ctx.lr), lf(ctx.r4.u32),
                  lf(ctx.r4.u32 + 4), lf(ctx.r4.u32 + 8), lf(ctx.r5.u32), lf(ctx.r5.u32 + 4), lf(ctx.r5.u32 + 8), ctx.f1.f64,
                  ctx.f2.f64, ctx.f3.f64, ctx.f4.f64, ctx.f5.f64, ctx.f6.f64, int(base[ctx.r1.u32 + 95]),
                  int(base[ctx.r1.u32 + 103]));
    }
  }
  __imp__sub_8214D788(ctx, base);
}
extern "C" void __imp__sub_8214D878(PPCContext& __restrict, uint8_t*);
// Development (XERENGE_FXLOG=1): the billboard effects queued for drawing (sub_8214D878: r3 the instance, its +60 the
// definition, 0x94 bytes each from 825F1B40, its name at +0x50) - once a second, how many of each.
REX_HOOK_RAW(sub_8214D878) {
  // Development (XERENGE_BOOMTEST=1): %TEMP%\xerenge_vr\BOOM starts 1.5 s of explosion billboards at the player car
  // through the game's own emit (sub_8214D788), into its explosion effects' instances (0x100 each from 827A7E20, the
  // definition's index: 19 fxexplosionflash, 20 fxexplosionsmoke, 22 fxexplosionfire, 27 / 28 fxexplosionfire).
  static const bool boom_test = std::getenv("XERENGE_BOOMTEST") != nullptr;
  if (boom_test && ctx.r3.u32 == 0x827A9420u) {
    static auto boom_until = std::chrono::steady_clock::time_point{};
    const std::string trigger = std::string(std::getenv("TEMP")) + "\\xerenge_vr\\BOOM";
    if (GetFileAttributesA(trigger.c_str()) != INVALID_FILE_ATTRIBUTES) {
      DeleteFileA(trigger.c_str());
      boom_until = std::chrono::steady_clock::now() + std::chrono::milliseconds(1500);
      REXLOG_INFO("boomtest: on");
    }
    if (std::chrono::steady_clock::now() < boom_until) {
      const auto load_f = [&](uint32_t a) {
        const uint32_t u = xerenge::LoadGuestU32(base, a);
        float v;
        std::memcpy(&v, &u, 4);
        return v;
      };
      const auto store_f = [&](uint32_t a, float v) {
        uint32_t u;
        std::memcpy(&u, &v, 4);
        xerenge::StoreGuestU32(base, a, u);
      };
      static uint32_t seed = 12345;
      const auto rnd = [&] {
        seed = seed * 1664525u + 1013904223u;
        return float(seed >> 8) / float(1u << 24) * 2.f - 1.f;
      };
      const float cx = load_f(0x82CE0040 + 0x30), cy = load_f(0x82CE0040 + 0x34), cz = load_f(0x82CE0040 + 0x38);
      const float now = load_f(0x829206ECu);
      const uint32_t frame = (ctx.r1.u32 - 0x1000) & ~0xFu;
      const uint32_t vecs = frame - 0x100;
      static const std::vector<uint32_t> indices = [] {
        std::vector<uint32_t> v;
        const char* list = std::getenv("XERENGE_BOOMFX");  // the effects' indices, "15,17" (default 19,20,22,27,28)
        std::string t = list ? list : "19,20,22,27,28";
        size_t at = 0;
        while (at < t.size()) {
          const size_t comma = t.find(',', at);
          v.push_back(uint32_t(std::atoi(t.substr(at, comma == std::string::npos ? std::string::npos : comma - at).c_str())));
          at = comma == std::string::npos ? t.size() : comma + 1;
        }
        return v;
      }();
      static const float vel_scale = std::getenv("XERENGE_BOOMVEL") ? float(std::atof(std::getenv("XERENGE_BOOMVEL"))) : 1.f;
      for (const uint32_t index : indices) {
        for (int k = 0; k < 2; ++k) {
          store_f(vecs + 0, cx + rnd() * 1.5f);
          store_f(vecs + 4, cy + 1.f + rnd() * 0.5f);
          store_f(vecs + 8, cz + rnd() * 1.5f);
          store_f(vecs + 16, rnd() * 4.f * vel_scale);
          store_f(vecs + 20, (2.f + rnd() * 2.f) * vel_scale);
          store_f(vecs + 24, rnd() * 4.f * vel_scale);
          base[frame + 95] = 1;
          base[frame + 103] = xerenge::LoadGuestU32(base, 0x827A7E20u + index * 0x100) == 0 ? 1 : 0;
          PPCContext c = ctx;
          c.r1.u64 = frame;
          c.r3.u64 = 0x827A7E20u + index * 0x100;
          c.r4.u64 = vecs;
          c.r5.u64 = vecs + 16;
          c.f1.f64 = now;
          c.f2.f64 = 0.0;
          c.f3.f64 = 1.0;
          c.f4.f64 = 0.8;
          c.f5.f64 = 1.0;
          c.f6.f64 = 3.0 * rnd();
          __imp__sub_8214D788(c, base);
          static int told = 0;
          if (told++ < 12) {
            REXLOG_INFO("boomtest: instance {} emitted {} at {:.1f} {:.1f} {:.1f} now {:.2f}", index, c.r3.u32, cx, cy, cz, now);
          }
        }
      }
    }
  }
  static const bool log = std::getenv("XERENGE_FXLOG") != nullptr;
  if (log) {
    static std::unordered_map<uint32_t, int> counts;
    static auto last = std::chrono::steady_clock::now();
    const auto lf = [&](uint32_t a) {
      const uint32_t u = xerenge::LoadGuestU32(base, a);
      float v;
      std::memcpy(&v, &u, 4);
      return v;
    };
    const float now = lf(0x829206ECu);
    const bool active = now - lf(ctx.r3.u32 + 24) < lf(ctx.r3.u32 + 20) ||
                        (base[0x8291F04Au] && now - lf(ctx.r3.u32 + 52) < lf(ctx.r3.u32 + 48));
    if (active) ++counts[xerenge::LoadGuestU32(base, ctx.r3.u32 + 60)];
    static std::unordered_map<uint32_t, int> dumped;
    const uint32_t def = xerenge::LoadGuestU32(base, ctx.r3.u32 + 60);
    if ((active || def == 0x825F27F8u) && dumped[def]++ == 0) {
      std::string t;
      for (uint32_t k = 0; k < 0x60; k += 4) t += fmt::format(" {:08X}", xerenge::LoadGuestU32(base, ctx.r3.u32 + k));
      REXLOG_INFO("fxinst: {:08X} def {:08X} now {:.2f}:{}", ctx.r3.u32, def, now, t);
    }
    if (std::chrono::steady_clock::now() - last > std::chrono::seconds(1)) {
      last = std::chrono::steady_clock::now();
      std::string t;
      for (const auto& [def, n] : counts) {
        const uint32_t name = xerenge::LoadGuestU32(base, def);
        std::string s;
        for (uint32_t k = 0; k < 32 && name >= 0x82000000u && name < 0x83000000u; ++k) {
          const char c = char(base[name + k]);
          if (!c) break;
          s += c;
        }
        t += fmt::format(" {:08X}({}, layer {})x{}", def, s, int32_t(xerenge::LoadGuestU32(base, def + 16)), n);
        (void)0;
      }
      counts.clear();
      REXLOG_INFO("fxlog:{}", t);
    }
  }
  __imp__sub_8214D878(ctx, base);
}
extern "C" void __imp__sub_820B31D0(PPCContext& __restrict, uint8_t*);
extern "C" void __imp__sub_820B2C88(PPCContext& __restrict, uint8_t*);
REX_HOOK_RAW(sub_820B31D0) {
  static const bool log = std::getenv("XERENGE_SPAWNLOG") != nullptr;
  static int told = 0;
  if (log && told < 200) {
    ++told;
    REXLOG_INFO("spawnlog: 820B31D0 type {} r3 {:08X} lr {:08X}", ctx.r9.s32, ctx.r3.u32, uint32_t(ctx.lr));
  }
  __imp__sub_820B31D0(ctx, base);
}
REX_HOOK_RAW(sub_820B2C88) {
  static const bool log = std::getenv("XERENGE_SPAWNLOG") != nullptr;
  static int told = 0;
  if (log && told < 200) {
    ++told;
    REXLOG_INFO("spawnlog: 820B2C88 r3 {:08X} r4 {:08X} r5 {:08X} r6 {:08X} r7 {:08X} r8 {:08X} r9 {:08X} lr {:08X}", ctx.r3.u32, ctx.r4.u32, ctx.r5.u32, ctx.r6.u32, ctx.r7.u32, ctx.r8.u32, ctx.r9.u32, uint32_t(ctx.lr));
  }
  __imp__sub_820B2C88(ctx, base);
}
REX_HOOK_RAW(sub_8214F6E8) {
  static const bool log = std::getenv("XERENGE_SPAWNLOG") != nullptr;
  if (log && !g_injecting) {
    static int told = 0;
    if (told == 0) {
      std::string t;
      for (uint32_t k = 0; k < 24; ++k) t += fmt::format(" {:08X}", xerenge::LoadGuestU32(base, 0x825E6BF0u + k * 4));
      REXLOG_INFO("spawnlog: type table 825E6BF0:{}", t);
    }
    static int flame_told = 0;  // and every one into the flame system (827E2B20), up to 4000
    const bool flame = ctx.r3.u32 == 0x827E2B20u && flame_told < 4000;
    if (flame) ++flame_told;
    if (told < 400 || flame) {
      ++told;
      const auto f = [&](uint32_t a) {
        const uint32_t u = xerenge::LoadGuestU32(base, a);
        float v;
        std::memcpy(&v, &u, 4);
        return v;
      };
      REXLOG_INFO("spawnlog: system {:08X} desc {:08X} lr {:08X} t {:.2f} ground {:.2f} p {:.2f} {:.2f} {:.2f} v {:.2f} {:.2f} {:.2f}",
                  ctx.r3.u32, xerenge::LoadGuestU32(base, ctx.r3.u32 + 0xE100), uint32_t(ctx.lr), ctx.f1.f64, ctx.f2.f64,
                  f(ctx.r4.u32), f(ctx.r4.u32 + 4), f(ctx.r4.u32 + 8), f(ctx.r5.u32), f(ctx.r5.u32 + 4), f(ctx.r5.u32 + 8));
    }
  }
  __imp__sub_8214F6E8(ctx, base);
}
REX_HOOK_RAW(sub_8214F860) {
  xerenge::TexDump(base);

  // Development (XERENGE_FLAMETEST=1): flame particles spawned at the player car, rising (velocity 0, 1.5, 0), through
  // the game's own spawn (sub_8214F6E8: r3 the system, r4 the start, r5 the velocity, f1 the time, f2 the ground).
  static const bool flame_test = std::getenv("XERENGE_FLAMETEST") != nullptr;
  if (flame_test && xerenge::LoadGuestU32(base, ctx.r3.u32 + 0xE100) == 0x825EC770u) {
    static auto spawned = std::chrono::steady_clock::now();
    if (std::chrono::steady_clock::now() - spawned > std::chrono::milliseconds(300)) {
      spawned = std::chrono::steady_clock::now();
      const auto load_f = [&](uint32_t a) {
        const uint32_t u = xerenge::LoadGuestU32(base, a);
        float v;
        std::memcpy(&v, &u, 4);
        return v;
      };
      const auto store_f = [&](uint32_t a, float v) {
        uint32_t u;
        std::memcpy(&u, &v, 4);
        xerenge::StoreGuestU32(base, a, u);
      };
      const float cx = load_f(0x82CE0040 + 0x30), cy = load_f(0x82CE0040 + 0x34), cz = load_f(0x82CE0040 + 0x38);
      const uint32_t scratch = (ctx.r1.u32 - 0x800) & ~0xFu;
      store_f(scratch + 0, cx);
      store_f(scratch + 4, cy + 1.f);
      store_f(scratch + 8, cz);
      store_f(scratch + 16, 0.f);
      store_f(scratch + 20, 1.5f);
      store_f(scratch + 24, 0.f);
      PPCContext c = ctx;
      c.r3.u64 = ctx.r3.u32;
      c.r4.u64 = scratch;
      c.r5.u64 = scratch + 16;
      c.f1.f64 = load_f(ctx.r3.u32 + 0xE108);
      c.f2.f64 = cy;
      g_injecting = true;
      __imp__sub_8214F6E8(c, base);
      g_injecting = false;
    }
  }
  static const bool log = std::getenv("XERENGE_PARTLOG") != nullptr;
  if (log) {
    static std::unordered_map<uint32_t, std::chrono::steady_clock::time_point> last;  // per system
    const uint32_t s = ctx.r3.u32;
    auto& since = last[s];
    if (std::chrono::steady_clock::now() - since > std::chrono::milliseconds(1000)) {
      since = std::chrono::steady_clock::now();
      const auto f = [&](uint32_t a) {
        const uint32_t u = xerenge::LoadGuestU32(base, a);
        float v;
        std::memcpy(&v, &u, 4);
        return v;
      };
      const uint32_t desc = xerenge::LoadGuestU32(base, s + 0xE100);
      std::string t;
      uint32_t shown = 0;
      for (uint32_t g = 0; g < 400 && shown < 4; ++g) {  // groups of four at s + g * 0x90
        for (uint32_t k = 0; k < 4 && shown < 4; ++k) {
          const uint32_t spawn = s + g * 0x90 + k * 4;
          const uint32_t rec = s + g * 0x90 + 0x10 + k * 0x20;
          if (f(rec) == 0.f && f(rec + 4) == 0.f) continue;
          ++shown;
          t += fmt::format(" [t0 {:.2f} p {:.1f} {:.1f}/{:.1f} {:.1f} v {:.2f} {:.2f}/{:.2f} {:.2f}]", f(spawn), f(rec),
                           f(rec + 4), f(rec + 0xC), f(rec + 8), f(rec + 0x10), f(rec + 0x14), f(rec + 0x1C), f(rec + 0x18));
        }
      }
      REXLOG_INFO("partlog: system {:08X} now {:.2f} gravity {:.3f} (desc {:08X} +0xC {:.3f}){}", s, f(s + 0xE108),
                  desc ? f(desc + 0x48) : 0.f, desc, desc ? f(desc + 0xC) : 0.f, t);
    }
  }
  __imp__sub_8214F860(ctx, base);
}
