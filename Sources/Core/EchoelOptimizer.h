#pragma once

/*
 * EchoelOptimizer.h
 * Ralph Wiggum Genius Loop Mode - System Optimization Engine
 *
 * Ultra-optimized performance management system for real-time audio,
 * video, AI, and biofeedback processing with adaptive resource allocation.
 */

#include <atomic>
#include <vector>
#include <array>
#include <memory>
#include <functional>
#include <string>
#include <cmath>
#include <algorithm>
#include <thread>
#include <mutex>
#include <chrono>
#include <deque>
#include <unordered_map>

namespace Echoel {
namespace Core {

// ============================================================================
// Performance Metrics
// ============================================================================

struct PerformanceMetrics {
    // CPU metrics
    float cpuUsage = 0.0f;              // 0-100%
    float cpuTemperature = 0.0f;        // Celsius
    int activeCores = 0;
    float avgCoreFrequency = 0.0f;      // MHz

    // Memory metrics
    size_t usedMemory = 0;              // Bytes
    size_t availableMemory = 0;
    size_t peakMemory = 0;
    float memoryPressure = 0.0f;        // 0-1

    // Audio metrics
    float audioLatency = 0.0f;          // ms
    float bufferUnderruns = 0.0f;       // Per second
    float dspLoad = 0.0f;               // 0-100%
    int activeVoices = 0;

    // Video metrics
    float frameRate = 0.0f;             // FPS
    float frameTime = 0.0f;             // ms
    float gpuUsage = 0.0f;              // 0-100%
    size_t gpuMemoryUsed = 0;

    // Network metrics
    float networkLatency = 0.0f;        // ms
    float bandwidth = 0.0f;             // Mbps
    float packetLoss = 0.0f;            // %

    // AI metrics
    float inferenceTime = 0.0f;         // ms
    int modelLoadCount = 0;
    float aiQueueDepth = 0.0f;

    // Overall health
    float systemHealth = 1.0f;          // 0-1
    std::vector<std::string> warnings;
    std::vector<std::string> errors;

    uint64_t timestamp = 0;
};

// ============================================================================
// Resource Priority Levels
// ============================================================================

enum class ResourcePriority {
    Critical,       // Audio/bio real-time (must not drop)
    High,           // Video rendering, AI inference
    Normal,         // UI updates, visualization
    Low,            // Background tasks, analytics
    Background      // File I/O, network sync
};

enum class QualityLevel {
    Maximum,        // Full quality, no compromises
    High,           // Minor optimizations
    Balanced,       // Quality/performance trade-off
    Performance,    // Favor performance
    Minimal         // Emergency mode
};

// ============================================================================
// Lock-Free Performance Counter
// ============================================================================

class PerformanceCounter {
public:
    void start() {
        startTime_ = std::chrono::high_resolution_clock::now();
    }

    void stop() {
        auto endTime = std::chrono::high_resolution_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::microseconds>(
            endTime - startTime_).count();

        // Lock-free update
        float durationMs = duration / 1000.0f;
        sampleSum_.fetch_add(static_cast<int64_t>(durationMs * 1000),
                             std::memory_order_relaxed);
        sampleCount_.fetch_add(1, std::memory_order_relaxed);

        // Update min/max
        int64_t currentMin = minDuration_.load(std::memory_order_relaxed);
        while (duration < currentMin &&
               !minDuration_.compare_exchange_weak(currentMin, duration,
                   std::memory_order_relaxed));

        int64_t currentMax = maxDuration_.load(std::memory_order_relaxed);
        while (duration > currentMax &&
               !maxDuration_.compare_exchange_weak(currentMax, duration,
                   std::memory_order_relaxed));
    }

    float getAverageMs() const {
        int64_t count = sampleCount_.load(std::memory_order_relaxed);
        if (count == 0) return 0.0f;
        int64_t sum = sampleSum_.load(std::memory_order_relaxed);
        return static_cast<float>(sum) / count / 1000.0f;
    }

    float getMinMs() const {
        return minDuration_.load(std::memory_order_relaxed) / 1000.0f;
    }

    float getMaxMs() const {
        return maxDuration_.load(std::memory_order_relaxed) / 1000.0f;
    }

    void reset() {
        sampleSum_.store(0, std::memory_order_relaxed);
        sampleCount_.store(0, std::memory_order_relaxed);
        minDuration_.store(INT64_MAX, std::memory_order_relaxed);
        maxDuration_.store(0, std::memory_order_relaxed);
    }

private:
    std::chrono::high_resolution_clock::time_point startTime_;
    std::atomic<int64_t> sampleSum_{0};
    std::atomic<int64_t> sampleCount_{0};
    std::atomic<int64_t> minDuration_{INT64_MAX};
    std::atomic<int64_t> maxDuration_{0};
};

// ============================================================================
// RAII Performance Measurement
// ============================================================================

class ScopedTimer {
public:
    explicit ScopedTimer(PerformanceCounter& counter)
        : counter_(counter) {
        counter_.start();
    }

    ~ScopedTimer() {
        counter_.stop();
    }

private:
    PerformanceCounter& counter_;
};

#define ECHOEL_PROFILE_SCOPE(counter) \
    Echoel::Core::ScopedTimer _scopedTimer##__LINE__(counter)

// ============================================================================
// Adaptive Buffer Manager
// ============================================================================

class AdaptiveBufferManager {
public:
    struct BufferConfig {
        size_t minSize = 64;
        size_t maxSize = 4096;
        size_t preferredSize = 256;
        float underrunThreshold = 0.01f;  // 1%
        float overrunThreshold = 0.1f;
    };

    void configure(const BufferConfig& config) {
        config_ = config;
        currentSize_ = config.preferredSize;
    }

    size_t getCurrentSize() const {
        return currentSize_.load(std::memory_order_relaxed);
    }

    void reportUnderrun() {
        underrunCount_.fetch_add(1, std::memory_order_relaxed);
        totalSamples_.fetch_add(1, std::memory_order_relaxed);
        maybeAdjustSize();
    }

    void reportSuccess() {
        totalSamples_.fetch_add(1, std::memory_order_relaxed);
        maybeAdjustSize();
    }

    float getUnderrunRate() const {
        size_t total = totalSamples_.load(std::memory_order_relaxed);
        if (total == 0) return 0.0f;
        return static_cast<float>(underrunCount_.load(std::memory_order_relaxed)) / total;
    }

private:
    void maybeAdjustSize() {
        size_t total = totalSamples_.load(std::memory_order_relaxed);
        if (total < 100) return;  // Need enough samples

        float underrunRate = getUnderrunRate();
        size_t current = currentSize_.load(std::memory_order_relaxed);

        if (underrunRate > config_.underrunThreshold) {
            // Too many underruns - increase buffer
            size_t newSize = std::min(current * 2, config_.maxSize);
            currentSize_.store(newSize, std::memory_order_relaxed);
            resetCounters();
        } else if (underrunRate < config_.underrunThreshold * 0.1f && total > 1000) {
            // Very stable - try smaller buffer for lower latency
            size_t newSize = std::max(current / 2, config_.minSize);
            if (newSize < current) {
                currentSize_.store(newSize, std::memory_order_relaxed);
                resetCounters();
            }
        }
    }

    void resetCounters() {
        underrunCount_.store(0, std::memory_order_relaxed);
        totalSamples_.store(0, std::memory_order_relaxed);
    }

    BufferConfig config_;
    std::atomic<size_t> currentSize_{256};
    std::atomic<size_t> underrunCount_{0};
    std::atomic<size_t> totalSamples_{0};
};

// ============================================================================
// CPU Affinity Manager
// ============================================================================

class AffinityManager {
public:
    struct CoreAssignment {
        int coreId;
        ResourcePriority priority;
        std::string taskName;
    };

    void initialize() {
        numCores_ = std::thread::hardware_concurrency();
        if (numCores_ == 0) numCores_ = 4;

        // Reserve cores for different priorities
        // Core 0: System (avoid)
        // Core 1-2: Critical (audio, bio)
        // Core 3-N: Others

        criticalCoreStart_ = 1;
        criticalCoreEnd_ = std::min(3u, numCores_ - 1);
        generalCoreStart_ = criticalCoreEnd_;
        generalCoreEnd_ = numCores_ - 1;
    }

    int assignCore(ResourcePriority priority, const std::string& taskName) {
        std::lock_guard<std::mutex> lock(mutex_);

        int core = -1;

        if (priority == ResourcePriority::Critical) {
            // Round-robin critical cores
            core = criticalCoreStart_ + (nextCriticalCore_++ % (criticalCoreEnd_ - criticalCoreStart_ + 1));
        } else {
            // Round-robin general cores
            core = generalCoreStart_ + (nextGeneralCore_++ % (generalCoreEnd_ - generalCoreStart_ + 1));
        }

        assignments_.push_back({core, priority, taskName});
        return core;
    }

    std::vector<CoreAssignment> getAssignments() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return assignments_;
    }

    unsigned int getNumCores() const { return numCores_; }

private:
    unsigned int numCores_ = 4;
    unsigned int criticalCoreStart_ = 1;
    unsigned int criticalCoreEnd_ = 2;
    unsigned int generalCoreStart_ = 3;
    unsigned int generalCoreEnd_ = 7;
    unsigned int nextCriticalCore_ = 0;
    unsigned int nextGeneralCore_ = 0;
    std::vector<CoreAssignment> assignments_;
    mutable std::mutex mutex_;
};

// ============================================================================
// Memory Pool with Usage Tracking
// ============================================================================

class TrackedMemoryPool {
public:
    TrackedMemoryPool(size_t blockSize, size_t initialBlocks)
        : blockSize_(blockSize) {
        for (size_t i = 0; i < initialBlocks; ++i) {
            void* block = std::aligned_alloc(64, blockSize);
            if (block) {
                freeBlocks_.push_back(block);
                totalAllocated_ += blockSize;
            }
        }
    }

    ~TrackedMemoryPool() {
        for (void* block : freeBlocks_) {
            std::free(block);
        }
        for (void* block : usedBlocks_) {
            std::free(block);
        }
    }

    void* allocate() {
        std::lock_guard<std::mutex> lock(mutex_);

        if (freeBlocks_.empty()) {
            // Allocate new block
            void* block = std::aligned_alloc(64, blockSize_);
            if (block) {
                usedBlocks_.push_back(block);
                totalAllocated_ += blockSize_;
                currentUsed_ += blockSize_;
                peakUsed_ = std::max(peakUsed_, currentUsed_);
                allocationCount_++;
                return block;
            }
            return nullptr;
        }

        void* block = freeBlocks_.back();
        freeBlocks_.pop_back();
        usedBlocks_.push_back(block);
        currentUsed_ += blockSize_;
        peakUsed_ = std::max(peakUsed_, currentUsed_);
        allocationCount_++;
        return block;
    }

    void deallocate(void* block) {
        if (!block) return;

        std::lock_guard<std::mutex> lock(mutex_);

        auto it = std::find(usedBlocks_.begin(), usedBlocks_.end(), block);
        if (it != usedBlocks_.end()) {
            usedBlocks_.erase(it);
            freeBlocks_.push_back(block);
            currentUsed_ -= blockSize_;
            deallocationCount_++;
        }
    }

    struct Stats {
        size_t blockSize;
        size_t totalAllocated;
        size_t currentUsed;
        size_t peakUsed;
        size_t freeBlocks;
        size_t usedBlocks;
        uint64_t allocationCount;
        uint64_t deallocationCount;
    };

    Stats getStats() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return {
            blockSize_,
            totalAllocated_,
            currentUsed_,
            peakUsed_,
            freeBlocks_.size(),
            usedBlocks_.size(),
            allocationCount_,
            deallocationCount_
        };
    }

private:
    size_t blockSize_;
    std::vector<void*> freeBlocks_;
    std::vector<void*> usedBlocks_;
    size_t totalAllocated_ = 0;
    size_t currentUsed_ = 0;
    size_t peakUsed_ = 0;
    uint64_t allocationCount_ = 0;
    uint64_t deallocationCount_ = 0;
    mutable std::mutex mutex_;
};

// ============================================================================
// Quality/Performance Balancer
// ============================================================================

class QualityBalancer {
public:
    struct SubsystemQuality {
        std::string name;
        QualityLevel currentLevel = QualityLevel::High;
        QualityLevel minLevel = QualityLevel::Minimal;
        float performanceImpact = 1.0f;  // Higher = more impact when reduced
        float qualityImportance = 1.0f;   // Higher = resist reduction
    };

    void registerSubsystem(const std::string& name, float perfImpact, float qualImp) {
        SubsystemQuality sq;
        sq.name = name;
        sq.performanceImpact = perfImpact;
        sq.qualityImportance = qualImp;
        subsystems_[name] = sq;
    }

    void setTargetPerformance(float targetCpuUsage, float targetFrameTime) {
        targetCpuUsage_ = targetCpuUsage;
        targetFrameTime_ = targetFrameTime;
    }

    void updateMetrics(float currentCpuUsage, float currentFrameTime) {
        currentCpuUsage_ = currentCpuUsage;
        currentFrameTime_ = currentFrameTime;

        // Calculate performance pressure
        float cpuPressure = currentCpuUsage / targetCpuUsage_;
        float framePressure = currentFrameTime / targetFrameTime_;
        performancePressure_ = std::max(cpuPressure, framePressure);

        // Adjust quality levels based on pressure
        if (performancePressure_ > 1.2f) {
            reduceLowestPriorityQuality();
        } else if (performancePressure_ < 0.7f) {
            increaseHighestPriorityQuality();
        }
    }

    QualityLevel getQualityLevel(const std::string& subsystem) const {
        auto it = subsystems_.find(subsystem);
        if (it != subsystems_.end()) {
            return it->second.currentLevel;
        }
        return QualityLevel::High;
    }

    float getPerformancePressure() const {
        return performancePressure_;
    }

private:
    void reduceLowestPriorityQuality() {
        // Find subsystem with lowest (importance / impact) ratio that can be reduced
        std::string target;
        float lowestRatio = std::numeric_limits<float>::max();

        for (auto& [name, sq] : subsystems_) {
            if (sq.currentLevel < QualityLevel::Minimal) {
                float ratio = sq.qualityImportance / sq.performanceImpact;
                if (ratio < lowestRatio) {
                    lowestRatio = ratio;
                    target = name;
                }
            }
        }

        if (!target.empty()) {
            auto& sq = subsystems_[target];
            sq.currentLevel = static_cast<QualityLevel>(
                static_cast<int>(sq.currentLevel) + 1);
        }
    }

    void increaseHighestPriorityQuality() {
        // Find subsystem with highest importance that can be increased
        std::string target;
        float highestImportance = 0.0f;

        for (auto& [name, sq] : subsystems_) {
            if (sq.currentLevel > QualityLevel::Maximum) {
                if (sq.qualityImportance > highestImportance) {
                    highestImportance = sq.qualityImportance;
                    target = name;
                }
            }
        }

        if (!target.empty()) {
            auto& sq = subsystems_[target];
            sq.currentLevel = static_cast<QualityLevel>(
                static_cast<int>(sq.currentLevel) - 1);
        }
    }

    std::unordered_map<std::string, SubsystemQuality> subsystems_;
    float targetCpuUsage_ = 70.0f;
    float targetFrameTime_ = 16.67f;
    float currentCpuUsage_ = 0.0f;
    float currentFrameTime_ = 0.0f;
    float performancePressure_ = 0.0f;
};

// ============================================================================
// Power/Thermal Management
// ============================================================================

class ThermalManager {
public:
    struct ThermalState {
        float cpuTemp = 0.0f;
        float gpuTemp = 0.0f;
        bool throttled = false;
        float throttleAmount = 0.0f;  // 0-1
    };

    void setThresholds(float warningTemp, float criticalTemp) {
        warningTemp_ = warningTemp;
        criticalTemp_ = criticalTemp;
    }

    ThermalState update(float cpuTemp, float gpuTemp) {
        ThermalState state;
        state.cpuTemp = cpuTemp;
        state.gpuTemp = gpuTemp;

        float maxTemp = std::max(cpuTemp, gpuTemp);

        if (maxTemp > criticalTemp_) {
            state.throttled = true;
            state.throttleAmount = 0.5f;  // Aggressive throttle
        } else if (maxTemp > warningTemp_) {
            state.throttled = true;
            float range = criticalTemp_ - warningTemp_;
            state.throttleAmount = (maxTemp - warningTemp_) / range * 0.3f;
        } else {
            state.throttled = false;
            state.throttleAmount = 0.0f;
        }

        currentState_ = state;
        return state;
    }

    ThermalState getState() const { return currentState_; }

    // Get recommended max workload (0-1)
    float getRecommendedWorkload() const {
        return 1.0f - currentState_.throttleAmount;
    }

private:
    float warningTemp_ = 75.0f;
    float criticalTemp_ = 90.0f;
    ThermalState currentState_;
};

// ============================================================================
// Main Optimizer System
// ============================================================================

class EchoelOptimizer {
public:
    struct OptimizerConfig {
        // Target performance
        float targetCpuUsage = 70.0f;       // %
        float targetFrameTime = 16.67f;      // ms (60 FPS)
        float targetAudioLatency = 10.0f;    // ms
        float maxMemoryUsage = 0.8f;         // 80% of available

        // Thermal management
        float thermalWarning = 75.0f;
        float thermalCritical = 90.0f;

        // Adaptation
        bool enableAdaptiveQuality = true;
        bool enableAdaptiveBuffers = true;
        bool enableThermalManagement = true;
        float adaptationRate = 0.1f;
    };

    EchoelOptimizer() {
        affinityManager_.initialize();

        // Create memory pools for different sizes
        memoryPools_[64] = std::make_unique<TrackedMemoryPool>(64, 1000);
        memoryPools_[256] = std::make_unique<TrackedMemoryPool>(256, 500);
        memoryPools_[1024] = std::make_unique<TrackedMemoryPool>(1024, 200);
        memoryPools_[4096] = std::make_unique<TrackedMemoryPool>(4096, 100);
        memoryPools_[16384] = std::make_unique<TrackedMemoryPool>(16384, 50);

        // Register subsystems for quality balancing
        qualityBalancer_.registerSubsystem("video", 0.8f, 0.7f);
        qualityBalancer_.registerSubsystem("audio", 0.3f, 1.0f);  // Critical
        qualityBalancer_.registerSubsystem("ai", 0.6f, 0.5f);
        qualityBalancer_.registerSubsystem("visuals", 0.7f, 0.4f);
        qualityBalancer_.registerSubsystem("network", 0.2f, 0.6f);

        // Initialize performance counters
        counters_["audio_callback"] = std::make_unique<PerformanceCounter>();
        counters_["video_render"] = std::make_unique<PerformanceCounter>();
        counters_["ai_inference"] = std::make_unique<PerformanceCounter>();
        counters_["bio_process"] = std::make_unique<PerformanceCounter>();
        counters_["visual_gen"] = std::make_unique<PerformanceCounter>();
    }

    void configure(const OptimizerConfig& config) {
        config_ = config;
        qualityBalancer_.setTargetPerformance(config.targetCpuUsage,
                                               config.targetFrameTime);
        thermalManager_.setThresholds(config.thermalWarning,
                                       config.thermalCritical);
    }

    // Update performance metrics
    void update(const PerformanceMetrics& metrics) {
        currentMetrics_ = metrics;

        // Store history for trend analysis
        metricsHistory_.push_back(metrics);
        if (metricsHistory_.size() > 100) {
            metricsHistory_.pop_front();
        }

        // Update subsystems
        if (config_.enableAdaptiveQuality) {
            qualityBalancer_.updateMetrics(metrics.cpuUsage, metrics.frameTime);
        }

        if (config_.enableThermalManagement) {
            thermalManager_.update(metrics.cpuTemperature, 0.0f);  // GPU temp if available
        }

        // Calculate system health
        calculateSystemHealth();
    }

    // Get optimized settings for a subsystem
    struct OptimizedSettings {
        QualityLevel quality;
        float workloadMultiplier;     // 0-1, reduce work if needed
        size_t recommendedBufferSize;
        int recommendedCore;
        std::vector<std::string> recommendations;
    };

    OptimizedSettings getSettings(const std::string& subsystem) {
        OptimizedSettings settings;

        settings.quality = qualityBalancer_.getQualityLevel(subsystem);
        settings.workloadMultiplier = thermalManager_.getRecommendedWorkload();
        settings.recommendedBufferSize = bufferManager_.getCurrentSize();
        settings.recommendedCore = affinityManager_.assignCore(
            subsystem == "audio" || subsystem == "bio" ?
            ResourcePriority::Critical : ResourcePriority::Normal,
            subsystem);

        // Generate recommendations
        if (qualityBalancer_.getPerformancePressure() > 1.0f) {
            settings.recommendations.push_back(
                "System under load - quality reduced for " + subsystem);
        }

        if (thermalManager_.getState().throttled) {
            settings.recommendations.push_back(
                "Thermal throttling active - workload reduced");
        }

        return settings;
    }

    // Memory allocation from pools
    void* allocatePooled(size_t size) {
        // Find smallest pool that fits
        for (auto& [poolSize, pool] : memoryPools_) {
            if (size <= poolSize) {
                return pool->allocate();
            }
        }
        // Fall back to regular allocation
        return std::aligned_alloc(64, size);
    }

    void deallocatePooled(void* ptr, size_t size) {
        for (auto& [poolSize, pool] : memoryPools_) {
            if (size <= poolSize) {
                pool->deallocate(ptr);
                return;
            }
        }
        std::free(ptr);
    }

    // Get performance counter for profiling
    PerformanceCounter* getCounter(const std::string& name) {
        auto it = counters_.find(name);
        if (it != counters_.end()) {
            return it->second.get();
        }
        counters_[name] = std::make_unique<PerformanceCounter>();
        return counters_[name].get();
    }

    // Report buffer events
    void reportBufferUnderrun(const std::string& subsystem) {
        bufferManager_.reportUnderrun();
        underrunCount_++;
    }

    void reportBufferSuccess(const std::string& subsystem) {
        bufferManager_.reportSuccess();
    }

    // Get current metrics
    PerformanceMetrics getCurrentMetrics() const {
        return currentMetrics_;
    }

    // Get comprehensive status report
    struct StatusReport {
        PerformanceMetrics metrics;
        std::map<std::string, QualityLevel> qualityLevels;
        ThermalManager::ThermalState thermalState;
        std::vector<TrackedMemoryPool::Stats> memoryPoolStats;
        std::map<std::string, float> counterAverages;
        float systemHealth;
        std::vector<std::string> warnings;
        std::vector<std::string> recommendations;
    };

    StatusReport getStatusReport() const {
        StatusReport report;
        report.metrics = currentMetrics_;
        report.thermalState = thermalManager_.getState();
        report.systemHealth = systemHealth_;

        // Quality levels
        for (const auto& subsystem : {"audio", "video", "ai", "visuals", "network"}) {
            report.qualityLevels[subsystem] = qualityBalancer_.getQualityLevel(subsystem);
        }

        // Memory pool stats
        for (const auto& [size, pool] : memoryPools_) {
            report.memoryPoolStats.push_back(pool->getStats());
        }

        // Counter averages
        for (const auto& [name, counter] : counters_) {
            report.counterAverages[name] = counter->getAverageMs();
        }

        // Generate warnings
        if (currentMetrics_.cpuUsage > 90.0f) {
            report.warnings.push_back("CPU usage critical");
        }
        if (currentMetrics_.dspLoad > 80.0f) {
            report.warnings.push_back("DSP load high");
        }
        if (report.thermalState.throttled) {
            report.warnings.push_back("Thermal throttling active");
        }
        if (bufferManager_.getUnderrunRate() > 0.01f) {
            report.warnings.push_back("Audio buffer underruns detected");
        }

        // Generate recommendations
        if (qualityBalancer_.getPerformancePressure() > 1.0f) {
            report.recommendations.push_back(
                "Consider reducing active features or quality settings");
        }
        if (currentMetrics_.memoryPressure > 0.8f) {
            report.recommendations.push_back(
                "Memory pressure high - consider closing other applications");
        }

        return report;
    }

    // Benchmark system capabilities
    struct BenchmarkResult {
        float maxSafeVoices;
        float maxSafeVideoLayers;
        float recommendedBufferSize;
        float estimatedLatency;
        std::string performanceClass;  // "low", "medium", "high", "ultra"
    };

    BenchmarkResult runBenchmark() {
        BenchmarkResult result;

        unsigned int cores = affinityManager_.getNumCores();

        // Estimate based on core count
        if (cores >= 8) {
            result.performanceClass = "ultra";
            result.maxSafeVoices = 128;
            result.maxSafeVideoLayers = 16;
            result.recommendedBufferSize = 64;
        } else if (cores >= 4) {
            result.performanceClass = "high";
            result.maxSafeVoices = 64;
            result.maxSafeVideoLayers = 8;
            result.recommendedBufferSize = 128;
        } else if (cores >= 2) {
            result.performanceClass = "medium";
            result.maxSafeVoices = 32;
            result.maxSafeVideoLayers = 4;
            result.recommendedBufferSize = 256;
        } else {
            result.performanceClass = "low";
            result.maxSafeVoices = 16;
            result.maxSafeVideoLayers = 2;
            result.recommendedBufferSize = 512;
        }

        result.estimatedLatency = result.recommendedBufferSize / 48.0f; // Assuming 48kHz

        return result;
    }

private:
    void calculateSystemHealth() {
        float health = 1.0f;

        // CPU impact
        if (currentMetrics_.cpuUsage > 90.0f) health -= 0.3f;
        else if (currentMetrics_.cpuUsage > 80.0f) health -= 0.15f;

        // DSP load impact
        if (currentMetrics_.dspLoad > 80.0f) health -= 0.2f;

        // Memory impact
        if (currentMetrics_.memoryPressure > 0.9f) health -= 0.2f;

        // Underrun impact
        float underrunRate = bufferManager_.getUnderrunRate();
        if (underrunRate > 0.01f) health -= underrunRate * 10.0f;

        // Thermal impact
        if (thermalManager_.getState().throttled) {
            health -= thermalManager_.getState().throttleAmount * 0.3f;
        }

        systemHealth_ = std::max(0.0f, std::min(1.0f, health));
    }

    OptimizerConfig config_;
    PerformanceMetrics currentMetrics_;
    std::deque<PerformanceMetrics> metricsHistory_;

    AffinityManager affinityManager_;
    AdaptiveBufferManager bufferManager_;
    QualityBalancer qualityBalancer_;
    ThermalManager thermalManager_;

    std::map<size_t, std::unique_ptr<TrackedMemoryPool>> memoryPools_;
    std::map<std::string, std::unique_ptr<PerformanceCounter>> counters_;

    std::atomic<uint64_t> underrunCount_{0};
    float systemHealth_ = 1.0f;
};

} // namespace Core
} // namespace Echoel
