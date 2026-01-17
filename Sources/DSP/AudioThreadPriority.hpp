/**
 * AudioThreadPriority.hpp
 * Echoelmusic - Cross-Platform Real-Time Thread Priority
 *
 * Sets optimal thread priority for audio processing
 * Ralph Wiggum Lambda Loop Mode - Nobel Prize Quality
 *
 * Features:
 * - Windows: THREAD_PRIORITY_TIME_CRITICAL + MMCSS "Pro Audio"
 * - Linux: SCHED_FIFO with RT priority
 * - macOS: Real-time thread policy
 * - Android: SCHED_FIFO for audio threads
 *
 * Created: 2026-01-17
 */

#pragma once

#include <thread>
#include <string>

#ifdef _WIN32
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <avrt.h>
#pragma comment(lib, "avrt.lib")
#elif defined(__APPLE__)
#include <pthread.h>
#include <mach/mach.h>
#include <mach/thread_policy.h>
#include <mach/mach_time.h>
#elif defined(__linux__) || defined(__ANDROID__)
#include <pthread.h>
#include <sched.h>
#include <sys/resource.h>
#include <unistd.h>
#endif

namespace Echoelmusic {
namespace Audio {

// ============================================================================
// MARK: - Thread Priority Levels
// ============================================================================

enum class ThreadPriority {
    Normal,          // Default OS priority
    AboveNormal,     // Slightly elevated
    High,            // High priority (for non-audio)
    Realtime,        // Real-time audio priority
    TimeCritical     // Highest possible (audio callback)
};

// ============================================================================
// MARK: - Audio Thread Configuration
// ============================================================================

struct AudioThreadConfig {
    ThreadPriority priority = ThreadPriority::Realtime;
    uint32_t periodMicroseconds = 5333;   // ~5.33ms for 48kHz/256 samples
    uint32_t computationMicroseconds = 2000;  // Max computation time
    bool useMMCSS = true;                 // Windows: use MMCSS
    std::string mmcssTaskName = "Pro Audio";  // MMCSS task name
};

// ============================================================================
// MARK: - Audio Thread Priority Manager
// ============================================================================

class AudioThreadPriority {
public:
    /**
     * Set current thread to real-time audio priority.
     * @return true if successful
     */
    static bool setRealtimePriority(const AudioThreadConfig& config = AudioThreadConfig()) {
#ifdef _WIN32
        return setWindowsPriority(config);
#elif defined(__APPLE__)
        return setMacOSPriority(config);
#elif defined(__linux__) || defined(__ANDROID__)
        return setLinuxPriority(config);
#else
        return false;
#endif
    }

    /**
     * Reset current thread to normal priority.
     */
    static void resetPriority() {
#ifdef _WIN32
        if (mmcssHandle_) {
            AvRevertMmThreadCharacteristics(mmcssHandle_);
            mmcssHandle_ = nullptr;
        }
        SetThreadPriority(GetCurrentThread(), THREAD_PRIORITY_NORMAL);
#elif defined(__APPLE__)
        // Reset to default policy
        thread_standard_policy_data_t policy;
        thread_policy_set(
            pthread_mach_thread_np(pthread_self()),
            THREAD_STANDARD_POLICY,
            reinterpret_cast<thread_policy_t>(&policy),
            THREAD_STANDARD_POLICY_COUNT
        );
#elif defined(__linux__) || defined(__ANDROID__)
        struct sched_param param;
        param.sched_priority = 0;
        pthread_setschedparam(pthread_self(), SCHED_OTHER, &param);
#endif
    }

    /**
     * Check if real-time priority is available.
     */
    static bool isRealtimeAvailable() {
#ifdef _WIN32
        // MMCSS available on Vista+
        return true;
#elif defined(__APPLE__)
        return true;
#elif defined(__linux__)
        // Check if we can set RT priority
        struct rlimit rlim;
        if (getrlimit(RLIMIT_RTPRIO, &rlim) == 0) {
            return rlim.rlim_cur > 0 || geteuid() == 0;
        }
        return geteuid() == 0;
#elif defined(__ANDROID__)
        return true;  // Available but may be restricted
#else
        return false;
#endif
    }

    /**
     * Get recommended buffer size for given latency.
     * @param sampleRate Audio sample rate
     * @param targetLatencyMs Target latency in milliseconds
     * @return Recommended buffer size (power of 2)
     */
    static uint32_t getRecommendedBufferSize(uint32_t sampleRate, float targetLatencyMs) {
        float samplesForLatency = (targetLatencyMs / 1000.0f) * sampleRate;

        // Round to nearest power of 2
        uint32_t bufferSize = 1;
        while (bufferSize < samplesForLatency) {
            bufferSize *= 2;
        }

        // Clamp to reasonable range
        if (bufferSize < 32) bufferSize = 32;
        if (bufferSize > 4096) bufferSize = 4096;

        return bufferSize;
    }

    /**
     * Get latency in milliseconds for given buffer size.
     */
    static float getLatencyMs(uint32_t sampleRate, uint32_t bufferSize) {
        return static_cast<float>(bufferSize) / sampleRate * 1000.0f;
    }

private:
#ifdef _WIN32
    static inline HANDLE mmcssHandle_ = nullptr;

    static bool setWindowsPriority(const AudioThreadConfig& config) {
        bool success = true;

        // Set thread priority class
        DWORD priorityClass;
        int priority;

        switch (config.priority) {
            case ThreadPriority::Normal:
                priorityClass = NORMAL_PRIORITY_CLASS;
                priority = THREAD_PRIORITY_NORMAL;
                break;
            case ThreadPriority::AboveNormal:
                priorityClass = ABOVE_NORMAL_PRIORITY_CLASS;
                priority = THREAD_PRIORITY_ABOVE_NORMAL;
                break;
            case ThreadPriority::High:
                priorityClass = HIGH_PRIORITY_CLASS;
                priority = THREAD_PRIORITY_HIGHEST;
                break;
            case ThreadPriority::Realtime:
            case ThreadPriority::TimeCritical:
                priorityClass = REALTIME_PRIORITY_CLASS;
                priority = THREAD_PRIORITY_TIME_CRITICAL;
                break;
        }

        // Try to set process priority class
        SetPriorityClass(GetCurrentProcess(), priorityClass);

        // Set thread priority
        if (!SetThreadPriority(GetCurrentThread(), priority)) {
            success = false;
        }

        // Use MMCSS for Pro Audio scheduling (Vista+)
        if (config.useMMCSS) {
            DWORD taskIndex = 0;
            mmcssHandle_ = AvSetMmThreadCharacteristicsA(
                config.mmcssTaskName.c_str(),
                &taskIndex
            );

            if (mmcssHandle_) {
                // Boost priority within MMCSS
                AvSetMmThreadPriority(mmcssHandle_, AVRT_PRIORITY_CRITICAL);
            }
        }

        return success;
    }
#endif

#ifdef __APPLE__
    static bool setMacOSPriority(const AudioThreadConfig& config) {
        // Use Mach real-time thread policy
        thread_time_constraint_policy_data_t policy;
        mach_timebase_info_data_t timebase;
        mach_timebase_info(&timebase);

        // Convert microseconds to Mach absolute time
        double factor = (double)timebase.denom / timebase.numer * 1000.0;

        policy.period = static_cast<uint32_t>(config.periodMicroseconds * factor);
        policy.computation = static_cast<uint32_t>(config.computationMicroseconds * factor);
        policy.constraint = policy.computation;
        policy.preemptible = true;

        kern_return_t result = thread_policy_set(
            pthread_mach_thread_np(pthread_self()),
            THREAD_TIME_CONSTRAINT_POLICY,
            reinterpret_cast<thread_policy_t>(&policy),
            THREAD_TIME_CONSTRAINT_POLICY_COUNT
        );

        return result == KERN_SUCCESS;
    }
#endif

#if defined(__linux__) || defined(__ANDROID__)
    static bool setLinuxPriority(const AudioThreadConfig& config) {
        struct sched_param param;
        int policy;
        int priority;

        switch (config.priority) {
            case ThreadPriority::Normal:
                policy = SCHED_OTHER;
                priority = 0;
                break;
            case ThreadPriority::AboveNormal:
            case ThreadPriority::High:
                policy = SCHED_FIFO;
                priority = 50;
                break;
            case ThreadPriority::Realtime:
                policy = SCHED_FIFO;
                priority = 80;
                break;
            case ThreadPriority::TimeCritical:
                policy = SCHED_FIFO;
                priority = 99;  // Maximum
                break;
        }

        // Clamp to valid range
        int maxPriority = sched_get_priority_max(policy);
        int minPriority = sched_get_priority_min(policy);
        priority = std::max(minPriority, std::min(maxPriority, priority));

        param.sched_priority = priority;

        int result = pthread_setschedparam(pthread_self(), policy, &param);

        if (result != 0) {
            // Fall back to nice value
            setpriority(PRIO_PROCESS, 0, -20);
            return false;
        }

        return true;
    }
#endif
};

// ============================================================================
// MARK: - Scoped Priority Guard
// ============================================================================

/**
 * RAII guard for setting thread priority.
 * Automatically resets on destruction.
 */
class ScopedAudioPriority {
public:
    explicit ScopedAudioPriority(const AudioThreadConfig& config = AudioThreadConfig())
        : wasSet_(AudioThreadPriority::setRealtimePriority(config)) {}

    ~ScopedAudioPriority() {
        if (wasSet_) {
            AudioThreadPriority::resetPriority();
        }
    }

    bool wasSet() const { return wasSet_; }

    // Non-copyable
    ScopedAudioPriority(const ScopedAudioPriority&) = delete;
    ScopedAudioPriority& operator=(const ScopedAudioPriority&) = delete;

private:
    bool wasSet_;
};

// ============================================================================
// MARK: - Thread Affinity (Optional)
// ============================================================================

class ThreadAffinity {
public:
    /**
     * Pin current thread to specific CPU core.
     * Useful for avoiding cache thrashing on multi-core systems.
     */
    static bool pinToCore(int coreIndex) {
#ifdef _WIN32
        DWORD_PTR mask = 1ULL << coreIndex;
        return SetThreadAffinityMask(GetCurrentThread(), mask) != 0;
#elif defined(__linux__)
        cpu_set_t cpuset;
        CPU_ZERO(&cpuset);
        CPU_SET(coreIndex, &cpuset);
        return pthread_setaffinity_np(pthread_self(), sizeof(cpu_set_t), &cpuset) == 0;
#elif defined(__APPLE__)
        // macOS doesn't support thread affinity directly
        // Use thread_policy_set with THREAD_AFFINITY_POLICY
        thread_affinity_policy_data_t policy = { coreIndex };
        return thread_policy_set(
            pthread_mach_thread_np(pthread_self()),
            THREAD_AFFINITY_POLICY,
            reinterpret_cast<thread_policy_t>(&policy),
            THREAD_AFFINITY_POLICY_COUNT
        ) == KERN_SUCCESS;
#else
        return false;
#endif
    }

    /**
     * Get number of CPU cores.
     */
    static int getCoreCount() {
        return static_cast<int>(std::thread::hardware_concurrency());
    }

    /**
     * Get recommended core for audio thread.
     * Typically the last core (isolated from OS tasks).
     */
    static int getRecommendedAudioCore() {
        int cores = getCoreCount();
        return cores > 1 ? cores - 1 : 0;
    }
};

} // namespace Audio
} // namespace Echoelmusic
