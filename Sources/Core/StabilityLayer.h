/*
  ==============================================================================

    StabilityLayer.h
    Echoelmusic Stability Optimization Layer

    Ensures maximum stability across all system components.

    Features:
    - Thread-safe resource management
    - Memory pooling and pre-allocation
    - Lock-free audio processing paths
    - Graceful degradation under load
    - Priority-based resource allocation
    - Real-time safe operations
    - Latency compensation
    - Jitter reduction
    - Predictable performance

    Created: 2026
    Author: Echoelmusic Team

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include <atomic>
#include <memory>
#include <mutex>
#include <vector>
#include <queue>
#include <functional>
#include <thread>
#include <condition_variable>

namespace Echoelmusic
{

//==============================================================================
/** Thread priority levels */
enum class ThreadPriority
{
    Realtime,       // Audio thread - highest priority
    High,           // Time-critical processing
    Normal,         // Standard background work
    Low,            // Non-essential tasks
    Idle            // Only when system is idle
};

//==============================================================================
/** Resource usage levels for adaptive behavior */
enum class ResourceLevel
{
    Minimal,        // Bare minimum functionality
    Low,            // Reduced features
    Normal,         // Standard operation
    High,           // Full features
    Maximum         // All features + extras
};

//==============================================================================
/** Audio safety flags */
struct AudioSafetyFlags
{
    bool allowBlocking = false;             // Can block audio thread?
    bool allowAllocation = false;           // Can allocate memory?
    bool allowExceptions = false;           // Can throw exceptions?
    bool allowFileIO = false;               // Can do file I/O?
    bool allowNetworkIO = false;            // Can do network I/O?
    bool allowHeavyProcessing = false;      // Can do expensive DSP?
};

//==============================================================================
/** Performance metrics for stability monitoring */
struct StabilityMetrics
{
    // Audio thread
    float audioThreadLoad = 0.0f;           // 0-100%
    float audioThreadJitter = 0.0f;         // Variance in callback time
    int64_t audioCallbackCount = 0;
    int64_t audioDropouts = 0;
    double averageCallbackTime = 0.0;       // ms
    double maxCallbackTime = 0.0;           // ms

    // Memory
    size_t pooledMemoryUsed = 0;
    size_t pooledMemoryAvailable = 0;
    int allocationCount = 0;
    int deallocationCount = 0;

    // Threads
    int activeWorkerThreads = 0;
    int blockedThreads = 0;
    int64_t lockContentions = 0;

    // Latency
    double inputLatency = 0.0;              // ms
    double outputLatency = 0.0;             // ms
    double totalLatency = 0.0;              // ms
    double compensatedLatency = 0.0;        // After compensation

    // System
    ResourceLevel currentResourceLevel = ResourceLevel::Normal;
    float systemLoad = 0.0f;
    juce::Time lastUpdate;
};

//==============================================================================
/**
    MemoryPool

    Lock-free memory pool for real-time safe allocations.
*/
template <typename T, size_t PoolSize = 1024>
class MemoryPool
{
public:
    MemoryPool()
    {
        // Pre-allocate all memory
        for (size_t i = 0; i < PoolSize; ++i)
        {
            pool[i].data = std::make_unique<T>();
            pool[i].inUse.store(false);
        }
    }

    /** Allocate from pool (lock-free, real-time safe) */
    T* allocate()
    {
        for (size_t i = 0; i < PoolSize; ++i)
        {
            bool expected = false;
            if (pool[i].inUse.compare_exchange_strong(expected, true))
            {
                return pool[i].data.get();
            }
        }
        return nullptr;  // Pool exhausted
    }

    /** Return to pool (lock-free) */
    void deallocate(T* ptr)
    {
        for (size_t i = 0; i < PoolSize; ++i)
        {
            if (pool[i].data.get() == ptr)
            {
                pool[i].inUse.store(false);
                return;
            }
        }
    }

    /** Get pool usage statistics */
    size_t getUsedCount() const
    {
        size_t count = 0;
        for (size_t i = 0; i < PoolSize; ++i)
        {
            if (pool[i].inUse.load())
                count++;
        }
        return count;
    }

    size_t getAvailableCount() const
    {
        return PoolSize - getUsedCount();
    }

private:
    struct PoolEntry
    {
        std::unique_ptr<T> data;
        std::atomic<bool> inUse{false};
    };

    std::array<PoolEntry, PoolSize> pool;
};

//==============================================================================
/**
    LockFreeQueue

    Single-producer single-consumer lock-free queue.
*/
template <typename T, size_t Capacity = 1024>
class LockFreeQueue
{
public:
    LockFreeQueue() : head(0), tail(0) {}

    bool push(const T& item)
    {
        size_t currentTail = tail.load(std::memory_order_relaxed);
        size_t nextTail = (currentTail + 1) % Capacity;

        if (nextTail == head.load(std::memory_order_acquire))
            return false;  // Full

        buffer[currentTail] = item;
        tail.store(nextTail, std::memory_order_release);
        return true;
    }

    bool pop(T& item)
    {
        size_t currentHead = head.load(std::memory_order_relaxed);

        if (currentHead == tail.load(std::memory_order_acquire))
            return false;  // Empty

        item = buffer[currentHead];
        head.store((currentHead + 1) % Capacity, std::memory_order_release);
        return true;
    }

    bool isEmpty() const
    {
        return head.load(std::memory_order_acquire) ==
               tail.load(std::memory_order_acquire);
    }

    size_t size() const
    {
        size_t h = head.load(std::memory_order_acquire);
        size_t t = tail.load(std::memory_order_acquire);
        return (t >= h) ? (t - h) : (Capacity - h + t);
    }

private:
    std::array<T, Capacity> buffer;
    std::atomic<size_t> head;
    std::atomic<size_t> tail;
};

//==============================================================================
/**
    WorkerThreadPool

    Thread pool for background processing with priority support.
*/
class WorkerThreadPool
{
public:
    using Task = std::function<void()>;

    WorkerThreadPool(int numThreads = 4) : shutdown(false)
    {
        for (int i = 0; i < numThreads; ++i)
        {
            workers.emplace_back([this] { workerLoop(); });
        }
    }

    ~WorkerThreadPool()
    {
        {
            std::lock_guard<std::mutex> lock(queueMutex);
            shutdown = true;
        }
        condition.notify_all();

        for (auto& worker : workers)
        {
            if (worker.joinable())
                worker.join();
        }
    }

    /** Submit a task with priority */
    void submit(Task task, ThreadPriority priority = ThreadPriority::Normal)
    {
        {
            std::lock_guard<std::mutex> lock(queueMutex);
            taskQueue.push({std::move(task), priority});
        }
        condition.notify_one();
    }

    /** Get number of pending tasks */
    size_t getPendingCount() const
    {
        std::lock_guard<std::mutex> lock(queueMutex);
        return taskQueue.size();
    }

private:
    struct PrioritizedTask
    {
        Task task;
        ThreadPriority priority;

        bool operator<(const PrioritizedTask& other) const
        {
            return static_cast<int>(priority) > static_cast<int>(other.priority);
        }
    };

    void workerLoop()
    {
        while (true)
        {
            PrioritizedTask task;

            {
                std::unique_lock<std::mutex> lock(queueMutex);
                condition.wait(lock, [this] {
                    return shutdown || !taskQueue.empty();
                });

                if (shutdown && taskQueue.empty())
                    return;

                task = taskQueue.top();
                taskQueue.pop();
            }

            task.task();
        }
    }

    std::vector<std::thread> workers;
    std::priority_queue<PrioritizedTask> taskQueue;
    mutable std::mutex queueMutex;
    std::condition_variable condition;
    bool shutdown;
};

//==============================================================================
/**
    LatencyCompensator

    Manages latency compensation across the system.
*/
class LatencyCompensator
{
public:
    void setInputLatency(double samples)
    {
        inputLatencySamples.store(samples);
        updateTotalLatency();
    }

    void setOutputLatency(double samples)
    {
        outputLatencySamples.store(samples);
        updateTotalLatency();
    }

    void setPluginLatency(const juce::String& pluginId, double samples)
    {
        std::lock_guard<std::mutex> lock(pluginLatencyMutex);
        pluginLatencies[pluginId] = samples;
        updateTotalLatency();
    }

    void removePluginLatency(const juce::String& pluginId)
    {
        std::lock_guard<std::mutex> lock(pluginLatencyMutex);
        pluginLatencies.erase(pluginId);
        updateTotalLatency();
    }

    double getTotalLatencySamples() const
    {
        return totalLatencySamples.load();
    }

    double getTotalLatencyMs(double sampleRate) const
    {
        return (totalLatencySamples.load() / sampleRate) * 1000.0;
    }

    int getCompensationDelaySamples() const
    {
        return static_cast<int>(totalLatencySamples.load());
    }

private:
    void updateTotalLatency()
    {
        double total = inputLatencySamples.load() + outputLatencySamples.load();

        {
            std::lock_guard<std::mutex> lock(pluginLatencyMutex);
            for (const auto& [id, latency] : pluginLatencies)
            {
                total += latency;
            }
        }

        totalLatencySamples.store(total);
    }

    std::atomic<double> inputLatencySamples{0.0};
    std::atomic<double> outputLatencySamples{0.0};
    std::atomic<double> totalLatencySamples{0.0};

    std::map<juce::String, double> pluginLatencies;
    std::mutex pluginLatencyMutex;
};

//==============================================================================
/**
    StabilityLayer

    Master stability management system.
*/
class StabilityLayer : public juce::Timer
{
public:
    //==========================================================================
    // Singleton Access

    static StabilityLayer& getInstance()
    {
        static StabilityLayer instance;
        return instance;
    }

    //==========================================================================
    // Initialization

    void initialize(double sampleRate, int blockSize)
    {
        if (initialized)
            return;

        currentSampleRate = sampleRate;
        currentBlockSize = blockSize;

        // Calculate timing thresholds
        double blockTimeMs = (blockSize / sampleRate) * 1000.0;
        maxCallbackTimeMs = blockTimeMs * 0.7;  // Leave 30% headroom

        // Initialize worker pool
        int numWorkers = std::max(2, (int)std::thread::hardware_concurrency() - 2);
        workerPool = std::make_unique<WorkerThreadPool>(numWorkers);

        // Start monitoring
        startTimer(monitoringIntervalMs);

        initialized = true;
        juce::Logger::writeToLog("[Stability] Layer initialized - SR: " +
            juce::String(sampleRate) + " / Block: " + juce::String(blockSize));
    }

    void shutdown()
    {
        if (!initialized)
            return;

        stopTimer();
        workerPool.reset();
        initialized = false;
    }

    //==========================================================================
    // Audio Thread Safety

    /**
        Enter audio callback context.
        Call at start of audio callback.
    */
    void enterAudioCallback()
    {
        audioCallbackStart = juce::Time::getHighResolutionTicks();
        metrics.audioCallbackCount++;
    }

    /**
        Exit audio callback context.
        Call at end of audio callback.
    */
    void exitAudioCallback()
    {
        auto end = juce::Time::getHighResolutionTicks();
        double callbackTime = juce::Time::highResolutionTicksToSeconds(
            end - audioCallbackStart) * 1000.0;

        // Update metrics
        metrics.averageCallbackTime =
            metrics.averageCallbackTime * 0.99 + callbackTime * 0.01;
        metrics.maxCallbackTime = std::max(metrics.maxCallbackTime, callbackTime);

        // Check for overrun
        if (callbackTime > maxCallbackTimeMs)
        {
            metrics.audioDropouts++;
            handleAudioOverrun(callbackTime);
        }

        // Calculate jitter
        double diff = std::abs(callbackTime - metrics.averageCallbackTime);
        metrics.audioThreadJitter =
            metrics.audioThreadJitter * 0.95f + (float)diff * 0.05f;
    }

    /**
        Check if current operation is safe for audio thread.
    */
    bool isAudioSafe(const AudioSafetyFlags& requiredFlags) const
    {
        // In audio callback, most operations are unsafe
        if (inAudioCallback.load())
        {
            return !requiredFlags.allowBlocking &&
                   !requiredFlags.allowAllocation &&
                   !requiredFlags.allowExceptions &&
                   !requiredFlags.allowFileIO &&
                   !requiredFlags.allowNetworkIO;
        }
        return true;
    }

    //==========================================================================
    // Resource Management

    /**
        Get current resource level.
    */
    ResourceLevel getResourceLevel() const
    {
        return currentResourceLevel.load();
    }

    /**
        Request resource level change.
    */
    void requestResourceLevel(ResourceLevel level)
    {
        requestedResourceLevel.store(level);
    }

    /**
        Submit background task.
    */
    void submitBackgroundTask(std::function<void()> task,
                              ThreadPriority priority = ThreadPriority::Normal)
    {
        if (workerPool)
        {
            workerPool->submit(std::move(task), priority);
        }
    }

    //==========================================================================
    // Latency

    LatencyCompensator& getLatencyCompensator() { return latencyCompensator; }

    //==========================================================================
    // Metrics

    StabilityMetrics getMetrics() const { return metrics; }

    float getAudioThreadLoad() const
    {
        return (float)(metrics.averageCallbackTime / maxCallbackTimeMs * 100.0);
    }

    bool isSystemStable() const
    {
        return metrics.audioDropouts == 0 &&
               getAudioThreadLoad() < 80.0f &&
               metrics.audioThreadJitter < 1.0f;
    }

    //==========================================================================
    // Configuration

    void setSampleRate(double sampleRate)
    {
        currentSampleRate = sampleRate;
        updateTimingThresholds();
    }

    void setBlockSize(int blockSize)
    {
        currentBlockSize = blockSize;
        updateTimingThresholds();
    }

    //==========================================================================
    // Graceful Degradation

    /**
        Enable/disable graceful degradation under load.
    */
    void setGracefulDegradationEnabled(bool enabled)
    {
        gracefulDegradationEnabled = enabled;
    }

    /**
        Check if feature should be disabled for performance.
    */
    bool shouldDisableFeature(const juce::String& featureId) const
    {
        if (!gracefulDegradationEnabled)
            return false;

        // High load = disable non-essential features
        if (getAudioThreadLoad() > 90.0f)
        {
            return nonEssentialFeatures.count(featureId) > 0;
        }

        return false;
    }

    /**
        Mark a feature as non-essential (can be disabled under load).
    */
    void markFeatureNonEssential(const juce::String& featureId)
    {
        nonEssentialFeatures.insert(featureId);
    }

private:
    StabilityLayer() = default;
    ~StabilityLayer() { shutdown(); }

    StabilityLayer(const StabilityLayer&) = delete;
    StabilityLayer& operator=(const StabilityLayer&) = delete;

    //==========================================================================
    // Timer

    void timerCallback() override
    {
        updateMetrics();
        adjustResourceLevel();
    }

    //==========================================================================
    // Internal

    void updateTimingThresholds()
    {
        if (currentSampleRate > 0 && currentBlockSize > 0)
        {
            double blockTimeMs = (currentBlockSize / currentSampleRate) * 1000.0;
            maxCallbackTimeMs = blockTimeMs * 0.7;
        }
    }

    void handleAudioOverrun(double actualTime)
    {
        juce::Logger::writeToLog("[Stability] Audio overrun: " +
            juce::String(actualTime, 2) + "ms (max: " +
            juce::String(maxCallbackTimeMs, 2) + "ms)");

        // Trigger graceful degradation if enabled
        if (gracefulDegradationEnabled)
        {
            auto current = currentResourceLevel.load();
            if (current > ResourceLevel::Minimal)
            {
                currentResourceLevel.store(
                    static_cast<ResourceLevel>(static_cast<int>(current) - 1));
            }
        }
    }

    void updateMetrics()
    {
        metrics.audioThreadLoad = getAudioThreadLoad();
        metrics.currentResourceLevel = currentResourceLevel.load();

        if (workerPool)
        {
            metrics.activeWorkerThreads = (int)workerPool->getPendingCount();
        }

        // Calculate total latency
        metrics.totalLatency = latencyCompensator.getTotalLatencyMs(currentSampleRate);
        metrics.lastUpdate = juce::Time::getCurrentTime();
    }

    void adjustResourceLevel()
    {
        ResourceLevel requested = requestedResourceLevel.load();
        ResourceLevel current = currentResourceLevel.load();

        // Gradual adjustment
        if (requested != current)
        {
            if (static_cast<int>(requested) > static_cast<int>(current))
            {
                // Only increase if system is stable
                if (isSystemStable())
                {
                    currentResourceLevel.store(
                        static_cast<ResourceLevel>(static_cast<int>(current) + 1));
                }
            }
            else
            {
                // Decrease immediately
                currentResourceLevel.store(
                    static_cast<ResourceLevel>(static_cast<int>(current) - 1));
            }
        }
    }

    //==========================================================================
    // State

    bool initialized = false;

    double currentSampleRate = 48000.0;
    int currentBlockSize = 512;
    double maxCallbackTimeMs = 10.0;

    std::atomic<bool> inAudioCallback{false};
    int64_t audioCallbackStart = 0;

    std::atomic<ResourceLevel> currentResourceLevel{ResourceLevel::Normal};
    std::atomic<ResourceLevel> requestedResourceLevel{ResourceLevel::Normal};

    std::unique_ptr<WorkerThreadPool> workerPool;
    LatencyCompensator latencyCompensator;

    StabilityMetrics metrics;
    int monitoringIntervalMs = 100;

    bool gracefulDegradationEnabled = true;
    std::set<juce::String> nonEssentialFeatures;
};

//==============================================================================
/**
    AudioSafeScope

    RAII helper for audio callback safety.
*/
class AudioSafeScope
{
public:
    AudioSafeScope()
    {
        StabilityLayer::getInstance().enterAudioCallback();
    }

    ~AudioSafeScope()
    {
        StabilityLayer::getInstance().exitAudioCallback();
    }

    AudioSafeScope(const AudioSafeScope&) = delete;
    AudioSafeScope& operator=(const AudioSafeScope&) = delete;
};

} // namespace Echoelmusic
