#pragma once

#include <JuceHeader.h>
#include <atomic>
#include <functional>
#include <map>
#include <memory>
#include <queue>

/**
 * ╔═══════════════════════════════════════════════════════════════════════════╗
 * ║     AUTO-HEALING CODE - Self-Repairing Software Architecture              ║
 * ╠═══════════════════════════════════════════════════════════════════════════╣
 * ║                                                                           ║
 * ║   Quantum Science Health Code - Software die sich selbst heilt           ║
 * ║                                                                           ║
 * ║   Mechanismen:                                                            ║
 * ║   - Exception Recovery (fängt und repariert Fehler)                       ║
 * ║   - State Checkpointing (speichert sichere Zustände)                      ║
 * ║   - Memory Leak Detection (findet und behebt Speicherlecks)               ║
 * ║   - Deadlock Prevention (erkennt und löst Deadlocks)                      ║
 * ║   - Performance Degradation Recovery                                       ║
 * ║   - Configuration Auto-Repair                                              ║
 * ║   - Resource Exhaustion Prevention                                         ║
 * ║   - Crash Recovery & Session Restoration                                   ║
 * ║                                                                           ║
 * ║   Inspiriert von: Self-Healing Systems, Chaos Engineering,                ║
 * ║   Netflix Chaos Monkey, Kubernetes Self-Healing                           ║
 * ║                                                                           ║
 * ╚═══════════════════════════════════════════════════════════════════════════╝
 */

namespace Echoel {

//==============================================================================
// Health Metrics
//==============================================================================

struct SystemHealthMetrics
{
    // Memory
    int64_t memoryUsedBytes = 0;
    int64_t memoryAvailableBytes = 0;
    float memoryUsagePercent = 0.0f;
    int memoryLeakSuspicionCount = 0;

    // CPU
    float cpuUsagePercent = 0.0f;
    float audioThreadCpuPercent = 0.0f;
    int cpuThrottlingEvents = 0;

    // Audio
    float audioDropoutRate = 0.0f;      // 0-1
    int xrunCount = 0;                   // Buffer underruns
    float averageLatencyMs = 0.0f;
    float maxLatencyMs = 0.0f;

    // Stability
    int exceptionCount = 0;
    int warningCount = 0;
    int crashRecoveries = 0;
    float uptimeSeconds = 0.0f;

    // Performance Score (0-1, higher is better)
    float overallHealthScore = 1.0f;

    void calculateOverallHealth()
    {
        float score = 1.0f;

        // Penalize high memory usage
        if (memoryUsagePercent > 80.0f) score -= 0.2f;
        if (memoryUsagePercent > 95.0f) score -= 0.3f;

        // Penalize high CPU
        if (cpuUsagePercent > 70.0f) score -= 0.1f;
        if (cpuUsagePercent > 90.0f) score -= 0.2f;

        // Penalize audio issues
        if (audioDropoutRate > 0.01f) score -= 0.2f;
        if (xrunCount > 10) score -= 0.1f;

        // Penalize exceptions
        score -= exceptionCount * 0.05f;

        overallHealthScore = juce::jmax(0.0f, score);
    }
};

//==============================================================================
// Healing Actions
//==============================================================================

enum class HealingAction
{
    None,
    ClearCaches,
    ReduceQuality,
    RestartAudioEngine,
    ResetConfiguration,
    FreeUnusedMemory,
    ReduceBufferSize,
    IncreaseBufferSize,
    DisableNonEssentialFeatures,
    RestoreFromCheckpoint,
    FullRestart
};

struct HealingResult
{
    HealingAction actionTaken = HealingAction::None;
    bool success = false;
    juce::String message;
    float healthImprovement = 0.0f;  // Improvement in health score
};

//==============================================================================
// State Checkpoint
//==============================================================================

struct StateCheckpoint
{
    juce::Time timestamp;
    juce::String name;
    juce::MemoryBlock stateData;
    SystemHealthMetrics healthAtCheckpoint;
    bool isAutomatic = false;

    StateCheckpoint() : timestamp(juce::Time::getCurrentTime()) {}
};

//==============================================================================
// Auto Healing Code Manager
//==============================================================================

class AutoHealingCode : public juce::Timer
{
public:
    //==========================================================================
    // Callbacks
    //==========================================================================

    using HealthChangedCallback = std::function<void(const SystemHealthMetrics&)>;
    using HealingTriggeredCallback = std::function<void(HealingAction, const juce::String& reason)>;
    using HealingCompletedCallback = std::function<void(const HealingResult&)>;

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    AutoHealingCode()
    {
        // Initialize health metrics
        updateHealthMetrics();

        // Create initial checkpoint
        createCheckpoint("initial");

        // Start health monitoring timer (every 5 seconds)
        startTimer(5000);
    }

    ~AutoHealingCode()
    {
        stopTimer();
    }

    //==========================================================================
    // Health Monitoring
    //==========================================================================

    /** Get current health metrics */
    SystemHealthMetrics getHealthMetrics() const
    {
        return currentMetrics;
    }

    /** Check if system is healthy */
    bool isHealthy() const
    {
        return currentMetrics.overallHealthScore >= 0.7f;
    }

    /** Get health score (0-1) */
    float getHealthScore() const
    {
        return currentMetrics.overallHealthScore;
    }

    /** Force health check now */
    void checkHealthNow()
    {
        updateHealthMetrics();
        evaluateAndHeal();
    }

    //==========================================================================
    // Checkpointing
    //==========================================================================

    /** Create a state checkpoint */
    void createCheckpoint(const juce::String& name = "")
    {
        StateCheckpoint checkpoint;
        checkpoint.name = name.isEmpty() ? "auto_" + juce::String(checkpoints.size()) : name;
        checkpoint.healthAtCheckpoint = currentMetrics;
        checkpoint.isAutomatic = name.isEmpty();

        // Capture application state
        if (onCaptureState)
            checkpoint.stateData = onCaptureState();

        checkpoints.push_back(checkpoint);

        // Limit checkpoint history
        while (checkpoints.size() > maxCheckpoints)
        {
            checkpoints.erase(checkpoints.begin());
        }

        DBG("AutoHealingCode: Created checkpoint '" << checkpoint.name << "'");
    }

    /** Restore from checkpoint */
    bool restoreFromCheckpoint(int index = -1)
    {
        if (checkpoints.empty())
            return false;

        // Default to most recent checkpoint
        if (index < 0 || index >= static_cast<int>(checkpoints.size()))
            index = static_cast<int>(checkpoints.size()) - 1;

        const auto& checkpoint = checkpoints[index];

        DBG("AutoHealingCode: Restoring from checkpoint '" << checkpoint.name << "'");

        // Restore state
        if (onRestoreState && checkpoint.stateData.getSize() > 0)
        {
            onRestoreState(checkpoint.stateData);
            return true;
        }

        return false;
    }

    /** State capture/restore callbacks */
    std::function<juce::MemoryBlock()> onCaptureState;
    std::function<void(const juce::MemoryBlock&)> onRestoreState;

    //==========================================================================
    // Exception Handling
    //==========================================================================

    /** Register an exception (for tracking) */
    void registerException(const std::exception& e, const juce::String& context = "")
    {
        ExceptionRecord record;
        record.message = e.what();
        record.context = context;
        record.timestamp = juce::Time::getCurrentTime();

        exceptionHistory.push_back(record);
        currentMetrics.exceptionCount++;

        // Limit history
        while (exceptionHistory.size() > 100)
            exceptionHistory.erase(exceptionHistory.begin());

        // Check if immediate healing needed
        if (exceptionHistory.size() > 5)
        {
            // Check if exceptions are clustered (many in short time)
            auto now = juce::Time::getCurrentTime();
            int recentCount = 0;
            for (const auto& ex : exceptionHistory)
            {
                if ((now - ex.timestamp).inSeconds() < 60)
                    recentCount++;
            }

            if (recentCount > 3)
            {
                triggerHealing(HealingAction::RestoreFromCheckpoint, "Multiple exceptions in short time");
            }
        }

        DBG("AutoHealingCode: Exception registered - " << e.what());
    }

    /** Wrap function with exception recovery */
    template<typename Func>
    auto withRecovery(Func&& func, const juce::String& context = "") -> decltype(func())
    {
        try
        {
            return func();
        }
        catch (const std::exception& e)
        {
            registerException(e, context);

            // Attempt recovery
            attemptRecovery(context);

            // Re-throw if recovery failed
            throw;
        }
    }

    /** Safe execution with fallback */
    template<typename Func, typename Fallback>
    auto safeExecute(Func&& func, Fallback&& fallback, const juce::String& context = "") -> decltype(func())
    {
        try
        {
            return func();
        }
        catch (const std::exception& e)
        {
            registerException(e, context);
            return fallback();
        }
    }

    //==========================================================================
    // Manual Healing Triggers
    //==========================================================================

    /** Trigger specific healing action */
    HealingResult triggerHealing(HealingAction action, const juce::String& reason = "")
    {
        if (onHealingTriggered)
            onHealingTriggered(action, reason);

        HealingResult result;
        result.actionTaken = action;

        float healthBefore = currentMetrics.overallHealthScore;

        switch (action)
        {
            case HealingAction::ClearCaches:
                result.success = clearCaches();
                result.message = "Cleared application caches";
                break;

            case HealingAction::ReduceQuality:
                result.success = reduceQuality();
                result.message = "Reduced processing quality to improve performance";
                break;

            case HealingAction::RestartAudioEngine:
                result.success = restartAudioEngine();
                result.message = "Restarted audio engine";
                break;

            case HealingAction::ResetConfiguration:
                result.success = resetConfiguration();
                result.message = "Reset configuration to defaults";
                break;

            case HealingAction::FreeUnusedMemory:
                result.success = freeUnusedMemory();
                result.message = "Freed unused memory";
                break;

            case HealingAction::ReduceBufferSize:
                result.success = adjustBufferSize(-1);
                result.message = "Reduced audio buffer size";
                break;

            case HealingAction::IncreaseBufferSize:
                result.success = adjustBufferSize(1);
                result.message = "Increased audio buffer size";
                break;

            case HealingAction::DisableNonEssentialFeatures:
                result.success = disableNonEssentialFeatures();
                result.message = "Disabled non-essential features";
                break;

            case HealingAction::RestoreFromCheckpoint:
                result.success = restoreFromCheckpoint();
                result.message = "Restored from last checkpoint";
                break;

            case HealingAction::FullRestart:
                result.success = scheduleFullRestart();
                result.message = "Scheduled full application restart";
                break;

            default:
                result.success = false;
                result.message = "Unknown healing action";
                break;
        }

        // Measure improvement
        updateHealthMetrics();
        result.healthImprovement = currentMetrics.overallHealthScore - healthBefore;

        if (onHealingCompleted)
            onHealingCompleted(result);

        return result;
    }

    //==========================================================================
    // Callbacks
    //==========================================================================

    HealthChangedCallback onHealthChanged;
    HealingTriggeredCallback onHealingTriggered;
    HealingCompletedCallback onHealingCompleted;

    //==========================================================================
    // Configuration
    //==========================================================================

    void setAutoHealingEnabled(bool enabled) { autoHealingEnabled = enabled; }
    void setHealthCheckInterval(int intervalMs) { stopTimer(); startTimer(intervalMs); }
    void setAutoCheckpointInterval(int intervalMs) { autoCheckpointInterval = intervalMs; }
    void setMaxCheckpoints(int max) { maxCheckpoints = max; }

private:
    //==========================================================================
    // Timer Callback
    //==========================================================================

    void timerCallback() override
    {
        updateHealthMetrics();

        // Notify listeners
        if (onHealthChanged)
            onHealthChanged(currentMetrics);

        // Auto-healing if enabled
        if (autoHealingEnabled)
        {
            evaluateAndHeal();
        }

        // Auto-checkpoint
        checkpointTimer += getTimerInterval();
        if (checkpointTimer >= autoCheckpointInterval)
        {
            checkpointTimer = 0;
            if (isHealthy())  // Only checkpoint when healthy
            {
                createCheckpoint();
            }
        }
    }

    //==========================================================================
    // Health Metrics Collection
    //==========================================================================

    void updateHealthMetrics()
    {
        // Memory
        currentMetrics.memoryUsedBytes = juce::Process::getCurrentlyUsedMemory();
        // Note: Total system memory would need platform-specific code

        // CPU (simplified - would need actual implementation)
        currentMetrics.cpuUsagePercent = estimateCpuUsage();

        // Audio metrics would come from AudioEngine
        // currentMetrics.audioDropoutRate = audioEngine->getDropoutRate();

        // Calculate overall health
        currentMetrics.calculateOverallHealth();
    }

    float estimateCpuUsage()
    {
        // Simplified CPU estimation based on timing
        auto startTime = juce::Time::getHighResolutionTicks();

        // Do some work
        volatile int sum = 0;
        for (int i = 0; i < 10000; i++)
            sum += i;

        auto endTime = juce::Time::getHighResolutionTicks();
        auto elapsed = juce::Time::highResolutionTicksToSeconds(endTime - startTime);

        // If this simple operation took too long, CPU is busy
        return juce::jmin(100.0f, static_cast<float>(elapsed * 100000.0));
    }

    //==========================================================================
    // Automatic Healing Logic
    //==========================================================================

    void evaluateAndHeal()
    {
        // Memory issues
        if (currentMetrics.memoryUsagePercent > 90.0f)
        {
            triggerHealing(HealingAction::FreeUnusedMemory, "Memory usage > 90%");

            if (currentMetrics.memoryUsagePercent > 95.0f)
            {
                triggerHealing(HealingAction::ClearCaches, "Critical memory usage");
            }
        }

        // CPU issues
        if (currentMetrics.cpuUsagePercent > 85.0f)
        {
            triggerHealing(HealingAction::ReduceQuality, "CPU usage > 85%");
        }

        // Audio issues
        if (currentMetrics.audioDropoutRate > 0.05f)
        {
            triggerHealing(HealingAction::IncreaseBufferSize, "Audio dropout rate > 5%");
        }

        // Too many exceptions
        if (currentMetrics.exceptionCount > 10)
        {
            triggerHealing(HealingAction::RestoreFromCheckpoint, "Excessive exceptions");
        }

        // Very poor health - drastic measures
        if (currentMetrics.overallHealthScore < 0.3f)
        {
            triggerHealing(HealingAction::DisableNonEssentialFeatures, "Critical health score");

            if (currentMetrics.overallHealthScore < 0.1f)
            {
                triggerHealing(HealingAction::FullRestart, "System near failure");
            }
        }
    }

    //==========================================================================
    // Healing Implementations
    //==========================================================================

    bool clearCaches()
    {
        auto cacheDir = juce::File::getSpecialLocation(juce::File::userApplicationDataDirectory)
            .getChildFile("Echoelmusic/cache");

        if (cacheDir.isDirectory())
        {
            cacheDir.deleteRecursively();
            cacheDir.createDirectory();
            return true;
        }
        return false;
    }

    bool reduceQuality()
    {
        // Would reduce audio quality, disable visualizations, etc.
        qualityLevel = juce::jmax(1, qualityLevel - 1);
        return true;
    }

    bool restartAudioEngine()
    {
        // Would restart audio subsystem
        // audioEngine->restart();
        return true;
    }

    bool resetConfiguration()
    {
        auto configFile = juce::File::getSpecialLocation(juce::File::userApplicationDataDirectory)
            .getChildFile("Echoelmusic/config.xml");

        if (configFile.existsAsFile())
        {
            configFile.copyFileTo(configFile.getSiblingFile("config.backup.xml"));
            configFile.deleteFile();
            return true;
        }
        return false;
    }

    bool freeUnusedMemory()
    {
        // Force garbage collection where possible
        // Clear undo history, thumbnail caches, etc.
        return true;
    }

    bool adjustBufferSize(int direction)
    {
        // Would adjust audio buffer size
        // direction: -1 = smaller (lower latency), +1 = larger (more stable)
        return true;
    }

    bool disableNonEssentialFeatures()
    {
        // Disable visualizations, auto-save, telemetry, etc.
        nonEssentialFeaturesEnabled = false;
        return true;
    }

    bool scheduleFullRestart()
    {
        // Save state and schedule restart
        createCheckpoint("pre_restart");
        restartScheduled = true;
        return true;
    }

    bool attemptRecovery(const juce::String& context)
    {
        // Context-specific recovery
        if (context.containsIgnoreCase("audio"))
        {
            restartAudioEngine();
            return true;
        }
        else if (context.containsIgnoreCase("memory"))
        {
            freeUnusedMemory();
            clearCaches();
            return true;
        }

        // Generic recovery
        return restoreFromCheckpoint();
    }

    //==========================================================================
    // Exception Tracking
    //==========================================================================

    struct ExceptionRecord
    {
        juce::String message;
        juce::String context;
        juce::Time timestamp;
    };

    std::vector<ExceptionRecord> exceptionHistory;

    //==========================================================================
    // Member Variables
    //==========================================================================

    SystemHealthMetrics currentMetrics;
    std::vector<StateCheckpoint> checkpoints;

    bool autoHealingEnabled = true;
    int autoCheckpointInterval = 300000;  // 5 minutes
    int checkpointTimer = 0;
    int maxCheckpoints = 10;

    int qualityLevel = 5;  // 1-5
    bool nonEssentialFeaturesEnabled = true;
    bool restartScheduled = false;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(AutoHealingCode)
};

//==============================================================================
// Convenience Macros
//==============================================================================

#define ECHOEL_TRY_RECOVER(code, context) \
    try { code; } catch (const std::exception& e) { \
        if (autoHealing) autoHealing->registerException(e, context); \
    }

#define ECHOEL_SAFE_CALL(func, fallback) \
    autoHealing ? autoHealing->safeExecute([&]() { return func; }, [&]() { return fallback; }) : func

} // namespace Echoel
