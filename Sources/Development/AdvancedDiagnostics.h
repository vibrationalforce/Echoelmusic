// AdvancedDiagnostics.h - Enterprise-Grade Development & Debugging Tools
// Professional diagnostics, profiling, and monitoring for production environments
#pragma once

#include "../Common/GlobalWarningFixes.h"
#include <JuceHeader.h>
#include <chrono>
#include <mutex>
#include <deque>
#include <map>
#include <atomic>

namespace Echoel {

// ==================== PERFORMANCE PROFILER ====================
class PerformanceProfiler {
public:
    struct ProfileData {
        juce::String functionName;
        double avgTimeMs{0.0};
        double minTimeMs{999999.0};
        double maxTimeMs{0.0};
        int callCount{0};
        double totalTimeMs{0.0};
        double cpuUsagePercent{0.0};
    };

    class ScopedTimer {
    public:
        ScopedTimer(PerformanceProfiler& profiler, const juce::String& name)
            : profiler(profiler), functionName(name) {
            startTime = std::chrono::high_resolution_clock::now();
        }

        ~ScopedTimer() {
            auto endTime = std::chrono::high_resolution_clock::now();
            auto duration = std::chrono::duration_cast<std::chrono::microseconds>(endTime - startTime);
            profiler.recordSample(functionName, duration.count() / 1000.0);
        }

    private:
        PerformanceProfiler& profiler;
        juce::String functionName;
        std::chrono::high_resolution_clock::time_point startTime;
    };

    void recordSample(const juce::String& name, double timeMs) {
        std::lock_guard<std::mutex> lock(mutex);

        auto& data = profileData[name];
        data.functionName = name;
        data.callCount++;
        data.totalTimeMs += timeMs;
        data.minTimeMs = std::min(data.minTimeMs, timeMs);
        data.maxTimeMs = std::max(data.maxTimeMs, timeMs);
        data.avgTimeMs = data.totalTimeMs / static_cast<double>(data.callCount);
    }

    std::map<juce::String, ProfileData> getProfileData() const {
        std::lock_guard<std::mutex> lock(mutex);
        return profileData;
    }

    juce::String generateReport() const {
        std::lock_guard<std::mutex> lock(mutex);

        juce::String report;
        report << "🔬 Performance Profile Report\n";
        report << "==============================\n\n";

        // Sort by average time (descending)
        std::vector<ProfileData> sorted;
        for (const auto& pair : profileData) {
            sorted.push_back(pair.second);
        }

        std::sort(sorted.begin(), sorted.end(), [](const ProfileData& a, const ProfileData& b) {
            return a.avgTimeMs > b.avgTimeMs;
        });

        report << juce::String::formatted("%-40s %10s %10s %10s %10s\n",
            "Function", "Avg (ms)", "Min (ms)", "Max (ms)", "Calls");
        report << juce::String::repeatedString("-", 80) << "\n";

        for (const auto& data : sorted) {
            report << juce::String::formatted("%-40s %10.3f %10.3f %10.3f %10d\n",
                data.functionName.toRawUTF8(),
                data.avgTimeMs,
                data.minTimeMs,
                data.maxTimeMs,
                data.callCount);
        }

        return report;
    }

    void reset() {
        std::lock_guard<std::mutex> lock(mutex);
        profileData.clear();
    }

private:
    mutable std::mutex mutex;
    std::map<juce::String, ProfileData> profileData;
};

// Convenience macro for profiling
#define ECHOEL_PROFILE_SCOPE(profiler, name) \
    Echoel::PerformanceProfiler::ScopedTimer JUCE_JOIN_MACRO(timer_, __LINE__)(profiler, name)

// ==================== MEMORY TRACKER ====================
class MemoryTracker {
public:
    struct AllocationInfo {
        size_t size;
        juce::String location;
        int64_t timestamp;
    };

    static MemoryTracker& getInstance() {
        static MemoryTracker instance;
        return instance;
    }

    void trackAllocation(void* ptr, size_t size, const juce::String& location) {
        std::lock_guard<std::mutex> lock(mutex);

        AllocationInfo info;
        info.size = size;
        info.location = location;
        info.timestamp = juce::Time::currentTimeMillis();

        allocations[ptr] = info;
        totalAllocated += size;
        currentAllocated += size;
        peakAllocated = std::max(peakAllocated, currentAllocated);
        allocationCount++;
    }

    void trackDeallocation(void* ptr) {
        std::lock_guard<std::mutex> lock(mutex);

        auto it = allocations.find(ptr);
        if (it != allocations.end()) {
            currentAllocated -= it->second.size;
            allocations.erase(it);
            deallocationCount++;
        }
    }

    juce::String generateReport() const {
        std::lock_guard<std::mutex> lock(mutex);

        juce::String report;
        report << "💾 Memory Tracker Report\n";
        report << "========================\n\n";
        report << "Total Allocated: " << formatBytes(totalAllocated) << "\n";
        report << "Current Usage: " << formatBytes(currentAllocated) << "\n";
        report << "Peak Usage: " << formatBytes(peakAllocated) << "\n";
        report << "Allocations: " << allocationCount << "\n";
        report << "Deallocations: " << deallocationCount << "\n";
        report << "Active Allocations: " << allocations.size() << "\n\n";

        if (!allocations.empty()) {
            report << "Top Allocations:\n";
            report << juce::String::repeatedString("-", 80) << "\n";

            // Sort by size
            std::vector<std::pair<void*, AllocationInfo>> sorted(allocations.begin(), allocations.end());
            std::sort(sorted.begin(), sorted.end(),
                [](const auto& a, const auto& b) { return a.second.size > b.second.size; });

            int count = 0;
            for (const auto& [ptr, info] : sorted) {
                if (++count > 10) break;  // Top 10
                report << formatBytes(info.size) << " at " << info.location << "\n";
            }
        }

        return report;
    }

private:
    MemoryTracker() = default;

    mutable std::mutex mutex;
    std::map<void*, AllocationInfo> allocations;
    size_t totalAllocated{0};
    size_t currentAllocated{0};
    size_t peakAllocated{0};
    int allocationCount{0};
    int deallocationCount{0};

    static juce::String formatBytes(size_t bytes) {
        if (bytes < 1024) return juce::String(bytes) + " B";
        if (bytes < 1024 * 1024) return juce::String(bytes / 1024.0, 2) + " KB";
        if (bytes < 1024 * 1024 * 1024) return juce::String(bytes / (1024.0 * 1024.0), 2) + " MB";
        return juce::String(bytes / (1024.0 * 1024.0 * 1024.0), 2) + " GB";
    }
};

// ==================== AUDIO BUFFER ANALYZER ====================
class AudioBufferAnalyzer {
public:
    struct BufferStats {
        float rmsLevel{0.0f};
        float peakLevel{0.0f};
        float dcOffset{0.0f};
        bool hasClipping{false};
        bool hasNaN{false};
        bool hasInf{false};
        bool hasDenormals{false};
        int silentSamples{0};
        float dynamicRange{0.0f};
    };

    static BufferStats analyze(const juce::AudioBuffer<float>& buffer) {
        BufferStats stats;

        if (buffer.getNumSamples() == 0) return stats;

        float sumSquares = 0.0f;
        float sum = 0.0f;
        float minVal = 1.0f;
        float maxVal = -1.0f;
        int totalSamples = 0;

        for (int ch = 0; ch < buffer.getNumChannels(); ++ch) {
            const float* data = buffer.getReadPointer(ch);

            for (int i = 0; i < buffer.getNumSamples(); ++i) {
                float sample = data[i];

                // Check for problems
                if (std::isnan(sample)) {
                    stats.hasNaN = true;
                    continue;
                }
                if (std::isinf(sample)) {
                    stats.hasInf = true;
                    continue;
                }
                if (std::abs(sample) < 1e-15f && sample != 0.0f) {
                    stats.hasDenormals = true;
                }
                if (std::abs(sample) > 0.999f) {
                    stats.hasClipping = true;
                }
                if (std::abs(sample) < 1e-6f) {
                    stats.silentSamples++;
                }

                // Statistics
                sumSquares += sample * sample;
                sum += sample;
                minVal = std::min(minVal, sample);
                maxVal = std::max(maxVal, sample);
                totalSamples++;
            }
        }

        if (totalSamples > 0) {
            stats.rmsLevel = std::sqrt(sumSquares / static_cast<float>(totalSamples));
            stats.peakLevel = std::max(std::abs(minVal), std::abs(maxVal));
            stats.dcOffset = sum / static_cast<float>(totalSamples);
            stats.dynamicRange = (stats.peakLevel > 0.0f && stats.rmsLevel > 0.0f)
                ? 20.0f * std::log10(stats.peakLevel / stats.rmsLevel)
                : 0.0f;
        }

        return stats;
    }

    static juce::String getWarnings(const BufferStats& stats) {
        juce::String warnings;

        if (stats.hasNaN) warnings << "⚠️ NaN values detected!\n";
        if (stats.hasInf) warnings << "⚠️ Inf values detected!\n";
        if (stats.hasClipping) warnings << "⚠️ Clipping detected (>0.999)!\n";
        if (stats.hasDenormals) warnings << "⚠️ Denormal values detected!\n";
        if (std::abs(stats.dcOffset) > 0.001f) {
            warnings << "⚠️ DC offset detected: " << stats.dcOffset << "\n";
        }

        return warnings.isEmpty() ? "✅ No issues detected" : warnings;
    }
};

// ==================== CPU USAGE MONITOR ====================
class CPUMonitor {
public:
    void updateLoad(double load) {
        std::lock_guard<std::mutex> lock(mutex);

        currentLoad = load;
        history.push_back(load);

        if (history.size() > maxHistorySize) {
            history.pop_front();
        }

        // Calculate statistics
        double sum = 0.0;
        minLoad = 100.0;
        maxLoad = 0.0;

        for (double val : history) {
            sum += val;
            minLoad = std::min(minLoad, val);
            maxLoad = std::max(maxLoad, val);
        }

        avgLoad = history.empty() ? 0.0 : sum / static_cast<double>(history.size());
    }

    juce::String getReport() const {
        std::lock_guard<std::mutex> lock(mutex);

        juce::String report;
        report << "⚡ CPU Usage Monitor\n";
        report << "===================\n\n";
        report << "Current: " << juce::String(currentLoad, 1) << "%\n";
        report << "Average: " << juce::String(avgLoad, 1) << "%\n";
        report << "Min: " << juce::String(minLoad, 1) << "%\n";
        report << "Max: " << juce::String(maxLoad, 1) << "%\n";

        if (maxLoad > 80.0) {
            report << "\n⚠️ WARNING: CPU usage above 80%!\n";
        }

        return report;
    }

    double getCurrentLoad() const {
        std::lock_guard<std::mutex> lock(mutex);
        return currentLoad;
    }

private:
    mutable std::mutex mutex;
    std::deque<double> history;
    double currentLoad{0.0};
    double avgLoad{0.0};
    double minLoad{0.0};
    double maxLoad{0.0};
    size_t maxHistorySize{1000};
};

// ==================== THREAD SAFETY CHECKER ====================
class ThreadSafetyChecker {
public:
    void registerAudioThread() {
        audioThreadId = std::this_thread::get_id();
        ECHOEL_TRACE("Audio thread registered: " << getThreadIdString(audioThreadId));
    }

    void registerMessageThread() {
        messageThreadId = std::this_thread::get_id();
        ECHOEL_TRACE("Message thread registered: " << getThreadIdString(messageThreadId));
    }

    bool isAudioThread() const {
        return std::this_thread::get_id() == audioThreadId;
    }

    bool isMessageThread() const {
        return std::this_thread::get_id() == messageThreadId;
    }

    void assertAudioThread(const juce::String& location) const {
        if (!isAudioThread()) {
            ECHOEL_ASSERT(false, "Function called from wrong thread: " + location);
            DBG("❌ THREAD SAFETY VIOLATION: " << location
                << " called from " << getThreadIdString(std::this_thread::get_id())
                << " but expected audio thread " << getThreadIdString(audioThreadId));
        }
    }

    void assertMessageThread(const juce::String& location) const {
        if (!isMessageThread()) {
            ECHOEL_ASSERT(false, "Function called from wrong thread: " + location);
            DBG("❌ THREAD SAFETY VIOLATION: " << location
                << " called from " << getThreadIdString(std::this_thread::get_id())
                << " but expected message thread " << getThreadIdString(messageThreadId));
        }
    }

private:
    std::thread::id audioThreadId;
    std::thread::id messageThreadId;

    static juce::String getThreadIdString(std::thread::id id) {
        std::ostringstream oss;
        oss << id;
        return juce::String(oss.str());
    }
};

// ==================== DIAGNOSTIC LOGGER ====================
class DiagnosticLogger {
public:
    enum class Level {
        Debug,
        Info,
        Warning,
        Error,
        Critical
    };

    struct LogEntry {
        Level level;
        juce::String message;
        juce::String function;
        juce::String file;
        int line;
        int64_t timestamp;
        std::thread::id threadId;
    };

    static DiagnosticLogger& getInstance() {
        static DiagnosticLogger instance;
        return instance;
    }

    void log(Level level, const juce::String& message,
            const juce::String& function, const juce::String& file, int line) {
        std::lock_guard<std::mutex> lock(mutex);

        LogEntry entry;
        entry.level = level;
        entry.message = message;
        entry.function = function;
        entry.file = file;
        entry.line = line;
        entry.timestamp = juce::Time::currentTimeMillis();
        entry.threadId = std::this_thread::get_id();

        logEntries.push_back(entry);

        if (logEntries.size() > maxEntries) {
            logEntries.pop_front();
        }

        // Also output to debug console
        DBG(getLevelString(level) << " [" << function << "] " << message);
    }

    juce::String generateReport() const {
        std::lock_guard<std::mutex> lock(mutex);

        juce::String report;
        report << "📋 Diagnostic Log\n";
        report << "================\n\n";

        for (const auto& entry : logEntries) {
            auto time = juce::Time(entry.timestamp);
            report << time.formatted("%H:%M:%S") << " ";
            report << getLevelString(entry.level) << " ";
            report << "[" << entry.function << "] ";
            report << entry.message << "\n";
        }

        return report;
    }

    void saveToFile(const juce::File& file) const {
        file.replaceWithText(generateReport());
    }

private:
    DiagnosticLogger() = default;

    mutable std::mutex mutex;
    std::deque<LogEntry> logEntries;
    size_t maxEntries{10000};

    static juce::String getLevelString(Level level) {
        switch (level) {
            case Level::Debug: return "🔍 DEBUG";
            case Level::Info: return "ℹ️ INFO";
            case Level::Warning: return "⚠️ WARN";
            case Level::Error: return "❌ ERROR";
            case Level::Critical: return "🚨 CRITICAL";
            default: return "UNKNOWN";
        }
    }
};

// Convenience macros
#define ECHOEL_LOG_DEBUG(msg) \
    Echoel::DiagnosticLogger::getInstance().log(Echoel::DiagnosticLogger::Level::Debug, msg, __FUNCTION__, __FILE__, __LINE__)
#define ECHOEL_LOG_INFO(msg) \
    Echoel::DiagnosticLogger::getInstance().log(Echoel::DiagnosticLogger::Level::Info, msg, __FUNCTION__, __FILE__, __LINE__)
#define ECHOEL_LOG_WARNING(msg) \
    Echoel::DiagnosticLogger::getInstance().log(Echoel::DiagnosticLogger::Level::Warning, msg, __FUNCTION__, __FILE__, __LINE__)
#define ECHOEL_LOG_ERROR(msg) \
    Echoel::DiagnosticLogger::getInstance().log(Echoel::DiagnosticLogger::Level::Error, msg, __FUNCTION__, __FILE__, __LINE__)
#define ECHOEL_LOG_CRITICAL(msg) \
    Echoel::DiagnosticLogger::getInstance().log(Echoel::DiagnosticLogger::Level::Critical, msg, __FUNCTION__, __FILE__, __LINE__)

// ==================== COMPREHENSIVE DIAGNOSTICS SUITE ====================
class DiagnosticsSuite {
public:
    PerformanceProfiler& getProfiler() { return profiler; }
    CPUMonitor& getCPUMonitor() { return cpuMonitor; }
    ThreadSafetyChecker& getThreadChecker() { return threadChecker; }

    juce::String generateComprehensiveReport() const {
        juce::String report;
        report << "╔════════════════════════════════════════════════════════╗\n";
        report << "║        EOEL DIAGNOSTICS REPORT                  ║\n";
        report << "╚════════════════════════════════════════════════════════╝\n\n";

        report << profiler.generateReport() << "\n\n";
        report << cpuMonitor.getReport() << "\n\n";
        report << MemoryTracker::getInstance().generateReport() << "\n\n";
        report << DiagnosticLogger::getInstance().generateReport() << "\n\n";

        return report;
    }

    void saveReport(const juce::File& file) const {
        file.replaceWithText(generateComprehensiveReport());
        ECHOEL_LOG_INFO("Diagnostics report saved to: " + file.getFullPathName());
    }

private:
    PerformanceProfiler profiler;
    CPUMonitor cpuMonitor;
    ThreadSafetyChecker threadChecker;
};

} // namespace Echoel
