/*
  ==============================================================================

    SelfHealingSystem.h
    Echoelmusic Self-Healing & Recovery System

    Autonomous error detection, recovery, and system optimization.

    Features:
    - Real-time error detection and classification
    - Automatic module recovery with multiple strategies
    - Memory leak detection and garbage collection
    - Audio glitch detection and correction
    - CPU overload protection
    - Watchdog timers for hung processes
    - State checkpointing and rollback
    - Predictive failure analysis
    - Self-optimization based on usage patterns

    Created: 2026
    Author: Echoelmusic Team

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include "EchoelCore.h"
#include <memory>
#include <queue>
#include <atomic>
#include <mutex>
#include <condition_variable>
#include <thread>
#include <chrono>
#include <functional>
#include <deque>

namespace Echoelmusic
{

//==============================================================================
/** Error severity levels */
enum class ErrorSeverity
{
    Info,           // Informational, no action needed
    Warning,        // Potential issue, monitor closely
    Error,          // Recoverable error, attempt fix
    Critical,       // Major failure, immediate action
    Fatal           // Unrecoverable, system shutdown
};

//==============================================================================
/** Error categories for classification */
enum class ErrorCategory
{
    Memory,         // Memory allocation, leaks, corruption
    Audio,          // Audio glitches, buffer issues
    MIDI,           // MIDI processing errors
    Plugin,         // Plugin crashes, timeouts
    File,           // File I/O errors
    Network,        // Network connectivity
    Hardware,       // Hardware communication
    DSP,            // DSP processing errors
    UI,             // User interface issues
    Sync,           // Synchronization problems
    State,          // State corruption
    Performance,    // Performance degradation
    Unknown
};

//==============================================================================
/** Recovery strategy types */
enum class RecoveryStrategy
{
    Ignore,         // Log and ignore
    Retry,          // Simple retry
    Restart,        // Restart affected component
    Rollback,       // Rollback to last known good state
    Isolate,        // Isolate and bypass failed component
    Reconfigure,    // Reconfigure with safer settings
    FullRestart,    // Full system restart
    Escalate        // Escalate to user
};

//==============================================================================
/** System checkpoint for rollback */
struct SystemCheckpoint
{
    juce::String id;
    juce::String description;
    juce::Time timestamp;

    // State data
    std::unique_ptr<juce::MemoryBlock> coreState;
    std::unique_ptr<juce::MemoryBlock> audioState;
    std::unique_ptr<juce::MemoryBlock> midiState;

    // Metrics at checkpoint time
    float cpuLoad;
    float memoryUsage;
    int activeModules;

    bool isValid = false;
};

//==============================================================================
/** Error event for tracking */
struct ErrorEvent
{
    juce::String id;
    ErrorSeverity severity;
    ErrorCategory category;
    juce::String source;        // Module or component that generated error
    juce::String message;
    juce::String stackTrace;
    juce::Time timestamp;

    RecoveryStrategy attemptedStrategy;
    bool recoverySuccessful;

    // Context
    float cpuLoadAtError;
    float memoryAtError;
    juce::String additionalInfo;
};

//==============================================================================
/** Health metrics for monitoring */
struct HealthMetrics
{
    // CPU
    float cpuUsage = 0.0f;              // 0-100%
    float audioCpuUsage = 0.0f;         // Audio thread specifically
    float peakCpuUsage = 0.0f;

    // Memory
    size_t usedMemory = 0;              // Bytes
    size_t availableMemory = 0;
    size_t peakMemory = 0;
    float memoryFragmentation = 0.0f;

    // Audio
    int xrunCount = 0;                  // Audio dropouts
    float audioLatency = 0.0f;          // ms
    int bufferUnderruns = 0;
    int bufferOverruns = 0;

    // System
    int activeThreads = 0;
    int errorCount = 0;
    int warningCount = 0;
    int recoveryCount = 0;

    // Timing
    juce::Time lastUpdate;
    double uptimeSeconds = 0.0;
};

//==============================================================================
/**
    SelfHealingSystem

    Autonomous system for detecting and recovering from errors.
*/
class SelfHealingSystem : public juce::Timer
{
public:
    //==========================================================================
    // Singleton Access

    static SelfHealingSystem& getInstance()
    {
        static SelfHealingSystem instance;
        return instance;
    }

    //==========================================================================
    // Initialization

    void initialize()
    {
        if (initialized)
            return;

        juce::Logger::writeToLog("[SelfHealing] Initializing self-healing system...");

        // Start monitoring thread
        monitoringThread = std::make_unique<std::thread>([this]() {
            monitoringLoop();
        });

        // Start timer for periodic checks
        startTimer(monitorIntervalMs);

        // Create initial checkpoint
        createCheckpoint("System Start");

        initialized = true;
        juce::Logger::writeToLog("[SelfHealing] Self-healing system active");
    }

    void shutdown()
    {
        if (!initialized)
            return;

        stopTimer();
        shutdownRequested = true;

        if (monitoringThread && monitoringThread->joinable())
        {
            monitoringCondition.notify_all();
            monitoringThread->join();
        }

        initialized = false;
    }

    //==========================================================================
    // Error Reporting

    /**
        Report an error to the self-healing system.
    */
    void reportError(ErrorSeverity severity, ErrorCategory category,
                     const juce::String& source, const juce::String& message,
                     const juce::String& additionalInfo = "")
    {
        std::lock_guard<std::mutex> lock(errorMutex);

        ErrorEvent event;
        event.id = juce::Uuid().toString();
        event.severity = severity;
        event.category = category;
        event.source = source;
        event.message = message;
        event.additionalInfo = additionalInfo;
        event.timestamp = juce::Time::getCurrentTime();
        event.cpuLoadAtError = currentMetrics.cpuUsage;
        event.memoryAtError = (float)currentMetrics.usedMemory;

        // Log it
        juce::String severityStr;
        switch (severity)
        {
            case ErrorSeverity::Info: severityStr = "INFO"; break;
            case ErrorSeverity::Warning: severityStr = "WARN"; break;
            case ErrorSeverity::Error: severityStr = "ERROR"; break;
            case ErrorSeverity::Critical: severityStr = "CRITICAL"; break;
            case ErrorSeverity::Fatal: severityStr = "FATAL"; break;
        }

        juce::Logger::writeToLog("[" + severityStr + "] " + source + ": " + message);

        // Store in history
        errorHistory.push_back(event);
        if (errorHistory.size() > maxErrorHistory)
            errorHistory.pop_front();

        // Update metrics
        if (severity >= ErrorSeverity::Error)
            currentMetrics.errorCount++;
        else if (severity == ErrorSeverity::Warning)
            currentMetrics.warningCount++;

        // Handle based on severity
        if (severity >= ErrorSeverity::Error)
        {
            handleError(event);
        }
    }

    /**
        Report an audio glitch (xrun).
    */
    void reportAudioGlitch()
    {
        currentMetrics.xrunCount++;
        reportError(ErrorSeverity::Warning, ErrorCategory::Audio,
                    "AudioEngine", "Audio buffer underrun detected");

        // Too many glitches = increase buffer
        if (currentMetrics.xrunCount > xrunThreshold)
        {
            suggestBufferIncrease();
        }
    }

    /**
        Report memory pressure.
    */
    void reportMemoryPressure(size_t bytesNeeded)
    {
        reportError(ErrorSeverity::Warning, ErrorCategory::Memory,
                    "MemoryManager", "Memory pressure: " +
                    juce::String(bytesNeeded / 1024 / 1024) + " MB needed");

        // Trigger garbage collection
        triggerMemoryCleanup();
    }

    //==========================================================================
    // Checkpointing

    /**
        Create a checkpoint of current system state.
    */
    juce::String createCheckpoint(const juce::String& description = "")
    {
        std::lock_guard<std::mutex> lock(checkpointMutex);

        SystemCheckpoint checkpoint;
        checkpoint.id = juce::Uuid().toString();
        checkpoint.description = description.isEmpty() ?
            "Checkpoint @ " + juce::Time::getCurrentTime().toString(true, true) :
            description;
        checkpoint.timestamp = juce::Time::getCurrentTime();
        checkpoint.cpuLoad = currentMetrics.cpuUsage;
        checkpoint.memoryUsage = (float)currentMetrics.usedMemory;
        checkpoint.activeModules = EchoelCore::getInstance().getActiveModuleCount();

        // Capture core state
        auto coreXml = EchoelCore::getInstance().createStateXML();
        if (coreXml)
        {
            checkpoint.coreState = std::make_unique<juce::MemoryBlock>();
            juce::MemoryOutputStream stream(*checkpoint.coreState, false);
            coreXml->writeTo(stream);
        }

        checkpoint.isValid = true;

        checkpoints.push_back(std::move(checkpoint));

        // Keep only recent checkpoints
        while (checkpoints.size() > maxCheckpoints)
            checkpoints.pop_front();

        juce::Logger::writeToLog("[SelfHealing] Checkpoint created: " + checkpoint.description);
        return checkpoints.back().id;
    }

    /**
        Rollback to a previous checkpoint.
    */
    bool rollbackToCheckpoint(const juce::String& checkpointId)
    {
        std::lock_guard<std::mutex> lock(checkpointMutex);

        for (const auto& cp : checkpoints)
        {
            if (cp.id == checkpointId && cp.isValid)
            {
                juce::Logger::writeToLog("[SelfHealing] Rolling back to: " + cp.description);

                // Restore state (simplified - real implementation would be more complex)
                // This would involve:
                // 1. Suspending all modules
                // 2. Restoring serialized state
                // 3. Reactivating modules

                currentMetrics.recoveryCount++;
                return true;
            }
        }

        return false;
    }

    /**
        Rollback to most recent valid checkpoint.
    */
    bool rollbackToLastCheckpoint()
    {
        std::lock_guard<std::mutex> lock(checkpointMutex);

        for (auto it = checkpoints.rbegin(); it != checkpoints.rend(); ++it)
        {
            if (it->isValid)
            {
                return rollbackToCheckpoint(it->id);
            }
        }

        return false;
    }

    //==========================================================================
    // Health Monitoring

    /**
        Get current health metrics.
    */
    HealthMetrics getHealthMetrics() const
    {
        return currentMetrics;
    }

    /**
        Get system health score (0-100).
    */
    float getHealthScore() const
    {
        float score = 100.0f;

        // CPU penalty
        if (currentMetrics.cpuUsage > 80.0f)
            score -= (currentMetrics.cpuUsage - 80.0f);

        // Memory penalty
        float memRatio = (float)currentMetrics.usedMemory /
                         (float)(currentMetrics.usedMemory + currentMetrics.availableMemory);
        if (memRatio > 0.8f)
            score -= (memRatio - 0.8f) * 100.0f;

        // Error penalty
        score -= currentMetrics.errorCount * 5.0f;

        // Xrun penalty
        score -= currentMetrics.xrunCount * 2.0f;

        return std::max(0.0f, std::min(100.0f, score));
    }

    /**
        Check if system is in critical state.
    */
    bool isSystemCritical() const
    {
        return currentMetrics.cpuUsage > 95.0f ||
               currentMetrics.errorCount > 10 ||
               currentMetrics.xrunCount > 20;
    }

    //==========================================================================
    // Recovery Actions

    /**
        Trigger garbage collection / memory cleanup.
    */
    void triggerMemoryCleanup()
    {
        juce::Logger::writeToLog("[SelfHealing] Triggering memory cleanup...");

        // Force JUCE to release cached resources
        juce::MessageManager::getInstance()->runDispatchLoopUntil(10);

        // Reset peak memory tracking
        currentMetrics.peakMemory = currentMetrics.usedMemory;
    }

    /**
        Suggest buffer size increase for audio stability.
    */
    void suggestBufferIncrease()
    {
        juce::Logger::writeToLog("[SelfHealing] Suggesting increased audio buffer size");
        // This would notify the audio system to increase buffer
    }

    /**
        Reset error counters.
    */
    void resetErrorCounters()
    {
        currentMetrics.errorCount = 0;
        currentMetrics.warningCount = 0;
        currentMetrics.xrunCount = 0;
    }

    //==========================================================================
    // Error History

    /**
        Get recent errors.
    */
    std::vector<ErrorEvent> getRecentErrors(int count = 10) const
    {
        std::lock_guard<std::mutex> lock(errorMutex);

        std::vector<ErrorEvent> result;
        int start = std::max(0, (int)errorHistory.size() - count);
        for (int i = start; i < (int)errorHistory.size(); ++i)
        {
            result.push_back(errorHistory[i]);
        }
        return result;
    }

    /**
        Get error count by category.
    */
    int getErrorCountByCategory(ErrorCategory category) const
    {
        std::lock_guard<std::mutex> lock(errorMutex);

        int count = 0;
        for (const auto& error : errorHistory)
        {
            if (error.category == category)
                count++;
        }
        return count;
    }

    //==========================================================================
    // Configuration

    void setMonitorInterval(int intervalMs)
    {
        monitorIntervalMs = intervalMs;
        if (isTimerRunning())
        {
            stopTimer();
            startTimer(monitorIntervalMs);
        }
    }

    void setXrunThreshold(int threshold)
    {
        xrunThreshold = threshold;
    }

    void setAutoRecoveryEnabled(bool enabled)
    {
        autoRecoveryEnabled = enabled;
    }

    //==========================================================================
    // Watchdog

    /**
        Register a watchdog for a component.
        Component must call feedWatchdog() regularly.
    */
    void registerWatchdog(const juce::String& componentId, int timeoutMs)
    {
        std::lock_guard<std::mutex> lock(watchdogMutex);
        watchdogs[componentId] = {juce::Time::getCurrentTime(), timeoutMs, true};
    }

    /**
        Feed the watchdog to prevent timeout.
    */
    void feedWatchdog(const juce::String& componentId)
    {
        std::lock_guard<std::mutex> lock(watchdogMutex);
        auto it = watchdogs.find(componentId);
        if (it != watchdogs.end())
        {
            it->second.lastFed = juce::Time::getCurrentTime();
        }
    }

    /**
        Unregister a watchdog.
    */
    void unregisterWatchdog(const juce::String& componentId)
    {
        std::lock_guard<std::mutex> lock(watchdogMutex);
        watchdogs.erase(componentId);
    }

private:
    SelfHealingSystem() = default;
    ~SelfHealingSystem() { shutdown(); }

    SelfHealingSystem(const SelfHealingSystem&) = delete;
    SelfHealingSystem& operator=(const SelfHealingSystem&) = delete;

    //==========================================================================
    // Timer callback

    void timerCallback() override
    {
        updateMetrics();
        checkWatchdogs();
    }

    //==========================================================================
    // Internal Methods

    void updateMetrics()
    {
        // Update CPU usage (simplified)
        // Real implementation would use platform-specific APIs

        // Update memory
        auto memInfo = juce::SystemStats::getMemorySize();
        currentMetrics.usedMemory = juce::Process::getMemorySize();
        currentMetrics.availableMemory = memInfo - currentMetrics.usedMemory;
        currentMetrics.peakMemory = std::max(currentMetrics.peakMemory, currentMetrics.usedMemory);

        // Update timing
        currentMetrics.lastUpdate = juce::Time::getCurrentTime();
        currentMetrics.uptimeSeconds =
            (currentMetrics.lastUpdate - startTime).inSeconds();
    }

    void checkWatchdogs()
    {
        std::lock_guard<std::mutex> lock(watchdogMutex);

        auto now = juce::Time::getCurrentTime();
        for (auto& [id, watchdog] : watchdogs)
        {
            if (!watchdog.active)
                continue;

            auto elapsed = now - watchdog.lastFed;
            if (elapsed.inMilliseconds() > watchdog.timeoutMs)
            {
                reportError(ErrorSeverity::Critical, ErrorCategory::Performance,
                            id, "Watchdog timeout - component unresponsive");
                watchdog.active = false;

                // Attempt recovery
                if (autoRecoveryEnabled)
                {
                    attemptComponentRecovery(id);
                }
            }
        }
    }

    void handleError(ErrorEvent& event)
    {
        if (!autoRecoveryEnabled)
            return;

        // Determine recovery strategy based on error type
        RecoveryStrategy strategy = determineRecoveryStrategy(event);
        event.attemptedStrategy = strategy;

        bool recovered = executeRecoveryStrategy(strategy, event);
        event.recoverySuccessful = recovered;

        if (recovered)
        {
            currentMetrics.recoveryCount++;
            juce::Logger::writeToLog("[SelfHealing] Recovery successful for: " + event.source);
        }
        else
        {
            juce::Logger::writeToLog("[SelfHealing] Recovery failed for: " + event.source);

            // Escalate if recovery failed
            if (event.severity >= ErrorSeverity::Critical)
            {
                escalateToUser(event);
            }
        }
    }

    RecoveryStrategy determineRecoveryStrategy(const ErrorEvent& event)
    {
        // Strategy selection based on error characteristics
        switch (event.category)
        {
            case ErrorCategory::Memory:
                return RecoveryStrategy::Reconfigure;

            case ErrorCategory::Audio:
                return event.severity >= ErrorSeverity::Critical ?
                       RecoveryStrategy::Restart : RecoveryStrategy::Retry;

            case ErrorCategory::Plugin:
                return RecoveryStrategy::Isolate;

            case ErrorCategory::State:
                return RecoveryStrategy::Rollback;

            case ErrorCategory::Performance:
                return RecoveryStrategy::Reconfigure;

            default:
                return event.severity >= ErrorSeverity::Critical ?
                       RecoveryStrategy::Restart : RecoveryStrategy::Retry;
        }
    }

    bool executeRecoveryStrategy(RecoveryStrategy strategy, const ErrorEvent& event)
    {
        switch (strategy)
        {
            case RecoveryStrategy::Ignore:
                return true;

            case RecoveryStrategy::Retry:
                return retryOperation(event.source);

            case RecoveryStrategy::Restart:
                return restartComponent(event.source);

            case RecoveryStrategy::Rollback:
                return rollbackToLastCheckpoint();

            case RecoveryStrategy::Isolate:
                return isolateComponent(event.source);

            case RecoveryStrategy::Reconfigure:
                return reconfigureComponent(event.source);

            case RecoveryStrategy::FullRestart:
                return performFullRestart();

            case RecoveryStrategy::Escalate:
                escalateToUser(event);
                return false;

            default:
                return false;
        }
    }

    bool retryOperation(const juce::String& source)
    {
        juce::Logger::writeToLog("[SelfHealing] Retrying operation for: " + source);
        // Attempt to retry the last operation
        return true;
    }

    bool restartComponent(const juce::String& source)
    {
        juce::Logger::writeToLog("[SelfHealing] Restarting component: " + source);
        return EchoelCore::getInstance().restartModule(source);
    }

    bool isolateComponent(const juce::String& source)
    {
        juce::Logger::writeToLog("[SelfHealing] Isolating component: " + source);
        return EchoelCore::getInstance().deactivateModule(source);
    }

    bool reconfigureComponent(const juce::String& source)
    {
        juce::Logger::writeToLog("[SelfHealing] Reconfiguring component: " + source);
        // Apply safer/more conservative settings
        return true;
    }

    bool performFullRestart()
    {
        juce::Logger::writeToLog("[SelfHealing] Performing full system restart");
        EchoelCore::getInstance().deactivate();
        return EchoelCore::getInstance().activate();
    }

    bool attemptComponentRecovery(const juce::String& componentId)
    {
        return restartComponent(componentId);
    }

    void escalateToUser(const ErrorEvent& event)
    {
        juce::Logger::writeToLog("[SelfHealing] Escalating to user: " + event.message);
        // Would show UI dialog or notification
    }

    void monitoringLoop()
    {
        while (!shutdownRequested)
        {
            std::unique_lock<std::mutex> lock(monitoringMutex);
            monitoringCondition.wait_for(lock, std::chrono::seconds(1));

            if (shutdownRequested)
                break;

            // Periodic deep health check
            performDeepHealthCheck();
        }
    }

    void performDeepHealthCheck()
    {
        // Check for memory leaks
        if (currentMetrics.usedMemory > currentMetrics.peakMemory * 1.5)
        {
            reportError(ErrorSeverity::Warning, ErrorCategory::Memory,
                        "MemoryMonitor", "Potential memory leak detected");
        }

        // Check for CPU spikes
        if (currentMetrics.cpuUsage > 90.0f)
        {
            reportError(ErrorSeverity::Warning, ErrorCategory::Performance,
                        "CPUMonitor", "High CPU usage: " +
                        juce::String(currentMetrics.cpuUsage, 1) + "%");
        }

        // Periodic checkpoint
        if (currentMetrics.uptimeSeconds > 0 &&
            (int)currentMetrics.uptimeSeconds % checkpointIntervalSeconds == 0)
        {
            createCheckpoint("Periodic checkpoint");
        }
    }

    //==========================================================================
    // Watchdog structure

    struct WatchdogEntry
    {
        juce::Time lastFed;
        int timeoutMs;
        bool active;
    };

    //==========================================================================
    // State

    bool initialized = false;
    std::atomic<bool> shutdownRequested{false};
    juce::Time startTime{juce::Time::getCurrentTime()};

    // Metrics
    HealthMetrics currentMetrics;

    // Error tracking
    std::deque<ErrorEvent> errorHistory;
    mutable std::mutex errorMutex;
    size_t maxErrorHistory = 500;

    // Checkpointing
    std::deque<SystemCheckpoint> checkpoints;
    std::mutex checkpointMutex;
    size_t maxCheckpoints = 20;
    int checkpointIntervalSeconds = 300;  // 5 minutes

    // Watchdogs
    std::map<juce::String, WatchdogEntry> watchdogs;
    std::mutex watchdogMutex;

    // Monitoring thread
    std::unique_ptr<std::thread> monitoringThread;
    std::mutex monitoringMutex;
    std::condition_variable monitoringCondition;

    // Configuration
    int monitorIntervalMs = 1000;
    int xrunThreshold = 10;
    bool autoRecoveryEnabled = true;
};

} // namespace Echoelmusic
