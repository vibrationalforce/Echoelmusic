#include "EchoelMasterSystem.h"

#ifdef __linux__
    #include <sys/mman.h>
    #include <sched.h>
    #include <pthread.h>
#elif __APPLE__
    #include <sys/mman.h>
    #include <pthread.h>
    #include <mach/thread_policy.h>
    #include <mach/thread_act.h>
#elif _WIN32
    #include <windows.h>
    #include <process hello.h>
#endif

//==============================================================================
// PerformanceStats
//==============================================================================

juce::String PerformanceStats::toString() const
{
    juce::String result;
    result << "ECHOELMUSIC PERFORMANCE STATS\n";
    result << "========================================\n";
    result << "Audio Latency: " << juce::String(audioLatencyMs, 2) << " ms\n";
    result << "CPU Usage: " << juce::String(cpuUsagePercent, 1) << "%\n";
    result << "RAM Usage: " << juce::String((int)ramUsageMB) << " MB\n";
    result << "DSP Load: " << juce::String(dspLoadPercent, 1) << "%\n";
    result << "Active Voices: " << juce::String(activeVoices) << "\n";
    result << "Active Plugins: " << juce::String(activePlugins) << "\n";
    result << "Buffer Underruns: " << juce::String(bufferUnderruns) << "\n";
    result << "Network Latency: " << juce::String(networkLatencyMs, 2) << " ms\n";
    result << "Uptime: " << juce::String(uptimeSeconds) << " seconds\n";
    result << "Status: " << (isRealtimeSafe ? "✅ REALTIME SAFE" : "⚠️ NOT REALTIME") << "\n";
    result << "Stability: " << (isStable ? "✅ STABLE" : "❌ UNSTABLE") << "\n";
    result << "========================================\n";
    return result;
}

//==============================================================================
// EchoelMasterSystem - Construction / Destruction
//==============================================================================

EchoelMasterSystem::EchoelMasterSystem()
{
    DBG("EchoelMasterSystem: Constructor");
}

EchoelMasterSystem::~EchoelMasterSystem()
{
    DBG("EchoelMasterSystem: Destructor");
    shutdown();
}

//==============================================================================
// Initialization
//==============================================================================

EchoelErrorCode EchoelMasterSystem::initialize(const ModuleConfig& cfg)
{
    DBG("EchoelMasterSystem: Initializing...");

    if (initialized.load())
    {
        DBG("EchoelMasterSystem: Already initialized");
        return EchoelErrorCode::Success;
    }

    config = cfg;
    startTime = juce::Time::currentTimeMillis();

    try
    {
        // Initialize modules in order
        DBG("EchoelMasterSystem: Initializing Studio module...");
        studio = std::make_unique<StudioModule>();
        studio->setSampleRate(config.studio.sampleRate);
        studio->setLatency(config.studio.bufferSize);

        DBG("EchoelMasterSystem: Initializing Biometric module...");
        biometric = std::make_unique<BiometricModule>();
        if (config.biometric.enableCameraHeartRate)
        {
            biometric->enableCameraHeartRate(true);
        }

        DBG("EchoelMasterSystem: Initializing Spatial module...");
        spatial = std::make_unique<SpatialModule>();
        spatial->setSpatialFormat((int)config.spatial.format);

        DBG("EchoelMasterSystem: Initializing Live module...");
        live = std::make_unique<LiveModule>();
        if (config.live.enableAbletonLink)
        {
            live->enableAbletonLink(true);
        }

        DBG("EchoelMasterSystem: Initializing AI module...");
        ai = std::make_unique<AIModule>();
        if (config.ai.enableMasteringMentor)
        {
            ai->enableMasteringMentor(true);
        }

        // Connect modules
        DBG("EchoelMasterSystem: Connecting modules...");
        connectModules();

        // Ensure realtime performance
        DBG("EchoelMasterSystem: Ensuring realtime performance...");
        ensureRealtimePerformance();

        // Start monitoring
        startTimerHz(10);  // Update stats 10 times per second

        initialized = true;
        lastError = EchoelErrorCode::Success;

        DBG("EchoelMasterSystem: ✅ Initialization complete!");

        return EchoelErrorCode::Success;
    }
    catch (const std::exception& e)
    {
        juce::String errorMsg = "Initialization failed: ";
        errorMsg << e.what();
        DBG("EchoelMasterSystem: ❌ " << errorMsg);

        reportError(EchoelErrorCode::UnknownError, errorMsg);
        shutdown();

        return EchoelErrorCode::UnknownError;
    }
}

void EchoelMasterSystem::shutdown()
{
    DBG("EchoelMasterSystem: Shutting down...");

    if (!initialized.load())
    {
        DBG("EchoelMasterSystem: Not initialized, nothing to shut down");
        return;
    }

    shuttingDown = true;

    // Stop monitoring
    stopTimer();

    // Disconnect modules
    disconnectModules();

    // Destroy modules in reverse order
    DBG("EchoelMasterSystem: Destroying AI module...");
    ai.reset();

    DBG("EchoelMasterSystem: Destroying Live module...");
    live.reset();

    DBG("EchoelMasterSystem: Destroying Spatial module...");
    spatial.reset();

    DBG("EchoelMasterSystem: Destroying Biometric module...");
    biometric.reset();

    DBG("EchoelMasterSystem: Destroying Studio module...");
    studio.reset();

    initialized = false;
    shuttingDown = false;

    DBG("EchoelMasterSystem: ✅ Shutdown complete");
}

//==============================================================================
// Module Access
//==============================================================================

StudioModule& EchoelMasterSystem::getStudio()
{
    jassert(initialized.load() && studio != nullptr);
    return *studio;
}

const StudioModule& EchoelMasterSystem::getStudio() const
{
    jassert(initialized.load() && studio != nullptr);
    return *studio;
}

BiometricModule& EchoelMasterSystem::getBiometric()
{
    jassert(initialized.load() && biometric != nullptr);
    return *biometric;
}

const BiometricModule& EchoelMasterSystem::getBiometric() const
{
    jassert(initialized.load() && biometric != nullptr);
    return *biometric;
}

SpatialModule& EchoelMasterSystem::getSpatial()
{
    jassert(initialized.load() && spatial != nullptr);
    return *spatial;
}

const SpatialModule& EchoelMasterSystem::getSpatial() const
{
    jassert(initialized.load() && spatial != nullptr);
    return *spatial;
}

LiveModule& EchoelMasterSystem::getLive()
{
    jassert(initialized.load() && live != nullptr);
    return *live;
}

const LiveModule& EchoelMasterSystem::getLive() const
{
    jassert(initialized.load() && live != nullptr);
    return *live;
}

AIModule& EchoelMasterSystem::getAI()
{
    jassert(initialized.load() && ai != nullptr);
    return *ai;
}

const AIModule& EchoelMasterSystem::getAI() const
{
    jassert(initialized.load() && ai != nullptr);
    return *ai;
}

//==============================================================================
// Cross-Module Features
//==============================================================================

void EchoelMasterSystem::enableBioReactiveMix(bool enable)
{
    DBG("EchoelMasterSystem: Bio-Reactive Mix " << (enable ? "ENABLED" : "DISABLED"));
    bioReactiveMixEnabled = enable;

    if (enable && initialized.load())
    {
        // Connect biometric → studio
        // This will modulate audio based on heart rate, stress, focus
        DBG("EchoelMasterSystem: Connecting Biometric → Studio");
    }
}

void EchoelMasterSystem::enableSpatialVisualization(bool enable)
{
    DBG("EchoelMasterSystem: Spatial Visualization " << (enable ? "ENABLED" : "DISABLED"));
    spatialVisualizationEnabled = enable;

    if (enable && initialized.load())
    {
        // Connect studio → spatial
        // This will visualize audio in 3D space
        DBG("EchoelMasterSystem: Connecting Studio → Spatial");
        spatial->enableVisualization(true);
    }
}

void EchoelMasterSystem::enableLivePerformance(bool enable)
{
    DBG("EchoelMasterSystem: Live Performance " << (enable ? "ENABLED" : "DISABLED"));
    livePerformanceEnabled = enable;

    if (enable && initialized.load())
    {
        // Connect studio → live
        // This will stream audio/video
        DBG("EchoelMasterSystem: Connecting Studio → Live");
    }
}

void EchoelMasterSystem::enableAIAssist(bool enable)
{
    DBG("EchoelMasterSystem: AI Assist " << (enable ? "ENABLED" : "DISABLED"));
    aiAssistEnabled = enable;

    if (enable && initialized.load())
    {
        // Connect AI → studio
        // This will provide intelligent mixing suggestions
        DBG("EchoelMasterSystem: Connecting AI → Studio");
    }
}

//==============================================================================
// Performance Monitoring & Optimization
//==============================================================================

void EchoelMasterSystem::ensureRealtimePerformance()
{
    DBG("EchoelMasterSystem: Ensuring realtime performance...");

#ifdef __linux__
    // Linux: Set SCHED_FIFO priority
    struct sched_param param;
    param.sched_priority = sched_get_priority_max(SCHED_FIFO);
    if (sched_setscheduler(0, SCHED_FIFO, &param) == 0)
    {
        DBG("EchoelMasterSystem: ✅ Set SCHED_FIFO priority");
    }
    else
    {
        DBG("EchoelMasterSystem: ⚠️ Failed to set SCHED_FIFO (may need root)");
    }

    // Lock memory
    if (mlockall(MCL_CURRENT | MCL_FUTURE) == 0)
    {
        DBG("EchoelMasterSystem: ✅ Locked memory");
    }
    else
    {
        DBG("EchoelMasterSystem: ⚠️ Failed to lock memory");
    }

#elif __APPLE__
    // macOS: Set thread priority
    thread_time_constraint_policy_data_t policy;
    policy.period = 2902; // ~192kHz / 64 samples
    policy.computation = 1451;
    policy.constraint = 2902;
    policy.preemptible = 1;

    kern_return_t result = thread_policy_set(
        pthread_mach_thread_np(pthread_self()),
        THREAD_TIME_CONSTRAINT_POLICY,
        (thread_policy_t)&policy,
        THREAD_TIME_CONSTRAINT_POLICY_COUNT
    );

    if (result == KERN_SUCCESS)
    {
        DBG("EchoelMasterSystem: ✅ Set realtime thread priority");
    }
    else
    {
        DBG("EchoelMasterSystem: ⚠️ Failed to set thread priority");
    }

#elif _WIN32
    // Windows: Set high priority
    if (SetPriorityClass(GetCurrentProcess(), REALTIME_PRIORITY_CLASS))
    {
        DBG("EchoelMasterSystem: ✅ Set realtime priority class");
    }
    else
    {
        DBG("EchoelMasterSystem: ⚠️ Failed to set priority class");
    }

    if (SetThreadPriority(GetCurrentThread(), THREAD_PRIORITY_TIME_CRITICAL))
    {
        DBG("EchoelMasterSystem: ✅ Set time-critical thread priority");
    }

#endif

    // Disable CPU throttling (if possible)
    // This is platform-specific and may require elevated privileges
}

PerformanceStats EchoelMasterSystem::getStats() const
{
    return currentStats;
}

float EchoelMasterSystem::getCPUUsage() const
{
    return currentStats.cpuUsagePercent;
}

size_t EchoelMasterSystem::getRAMUsageMB() const
{
    return currentStats.ramUsageMB;
}

double EchoelMasterSystem::getAudioLatencyMs() const
{
    return currentStats.audioLatencyMs;
}

bool EchoelMasterSystem::isRealtimeSafe() const
{
    return currentStats.isRealtimeSafe;
}

//==============================================================================
// Message System
//==============================================================================

void EchoelMasterSystem::sendMessage(const Message& message)
{
    std::lock_guard<std::mutex> lock(messageQueueMutex);
    messageQueue.push(message);
}

void EchoelMasterSystem::addMessageListener(std::function<void(const Message&)> listener)
{
    messageListeners.push_back(listener);
}

void EchoelMasterSystem::processMessageQueue()
{
    std::lock_guard<std::mutex> lock(messageQueueMutex);

    while (!messageQueue.empty())
    {
        Message msg = messageQueue.front();
        messageQueue.pop();

        routeMessage(msg);
    }
}

void EchoelMasterSystem::routeMessage(const Message& message)
{
    // Route to specific module or broadcast
    if (message.targetModule.isEmpty())
    {
        // Broadcast to all listeners
        for (auto& listener : messageListeners)
        {
            listener(message);
        }
    }
    else
    {
        // Route to specific module
        // TODO: Implement module-specific routing
    }
}

//==============================================================================
// Inter-Module Connections
//==============================================================================

void EchoelMasterSystem::connectModules()
{
    DBG("EchoelMasterSystem: Connecting inter-module communication...");

    // Studio → Biometric: Audio processed
    // Biometric → Studio: Bio data received
    // Studio → Spatial: Audio for visualization
    // Spatial → Live: Render for streaming
    // AI → Studio: Analysis complete

    // These connections are established when cross-module features are enabled
}

void EchoelMasterSystem::disconnectModules()
{
    DBG("EchoelMasterSystem: Disconnecting inter-module communication...");
}

void EchoelMasterSystem::onAudioProcessed(const juce::AudioBuffer<float>& buffer)
{
    (void)buffer;
    // Handle audio processed event
}

void EchoelMasterSystem::onBiometricData(float heartRate, float hrv, float stress, float focus)
{
    (void)heartRate; (void)hrv; (void)stress; (void)focus;
    // Handle biometric data
}

void EchoelMasterSystem::onSpatialRender()
{
    // Handle spatial render complete
}

void EchoelMasterSystem::onNetworkPacket()
{
    // Handle network packet
}

void EchoelMasterSystem::onAIAnalysis()
{
    // Handle AI analysis complete
}

//==============================================================================
// Performance Monitoring
//==============================================================================

void EchoelMasterSystem::updateStats()
{
    if (!initialized.load())
        return;

    // Update uptime
    int64_t now = juce::Time::currentTimeMillis();
    currentStats.uptimeSeconds = (now - startTime.load()) / 1000;

    // Update audio latency (from studio module)
    currentStats.audioLatencyMs = (config.studio.bufferSize / config.studio.sampleRate) * 1000.0;

    // Update CPU usage (simplified)
    // In production, this would use platform-specific CPU monitoring
    currentStats.cpuUsagePercent = 15.0f;  // Placeholder

    // Update RAM usage
    juce::MemoryStatistics memStats;
    currentStats.ramUsageMB = memStats.getTotalMemoryUsed() / (1024 * 1024);
    currentStats.peakRamUsageMB = memStats.getPeakMemoryUsage() / (1024 * 1024);

    // Check realtime safety
    currentStats.isRealtimeSafe = (currentStats.audioLatencyMs < 10.0 &&
                                   currentStats.bufferUnderruns == 0);

    // Check stability
    currentStats.isStable = (currentStats.crashes == 0 &&
                             currentStats.cpuUsagePercent < 80.0f);
}

void EchoelMasterSystem::timerCallback()
{
    updateStats();
    processMessageQueue();
}

//==============================================================================
// Error Handling
//==============================================================================

juce::String EchoelMasterSystem::getErrorMessage() const
{
    switch (lastError)
    {
        case EchoelErrorCode::Success:
            return "No error";
        case EchoelErrorCode::AudioDeviceError:
            return "Audio device error";
        case EchoelErrorCode::AudioBufferUnderrun:
            return "Audio buffer underrun (xrun)";
        case EchoelErrorCode::BiometricDeviceTimeout:
            return "Biometric device timeout";
        case EchoelErrorCode::NetworkConnectionFailed:
            return "Network connection failed";
        case EchoelErrorCode::FileIOError:
            return "File I/O error";
        case EchoelErrorCode::PluginLoadError:
            return "Plugin load error";
        case EchoelErrorCode::OutOfMemory:
            return "Out of memory";
        case EchoelErrorCode::UnknownError:
        default:
            return "Unknown error";
    }
}

void EchoelMasterSystem::setErrorCallback(std::function<void(EchoelErrorCode, const juce::String&)> callback)
{
    errorCallback = callback;
}

void EchoelMasterSystem::reportError(EchoelErrorCode code, const juce::String& message)
{
    lastError = code;
    DBG("EchoelMasterSystem ERROR: " << message);

    if (errorCallback)
    {
        errorCallback(code, message);
    }
}

//==============================================================================
// Configuration
//==============================================================================

void EchoelMasterSystem::setConfig(const ModuleConfig& cfg)
{
    config = cfg;

    if (initialized.load())
    {
        // Update module configurations
        studio->setSampleRate(config.studio.sampleRate);
        studio->setLatency(config.studio.bufferSize);

        biometric->enableCameraHeartRate(config.biometric.enableCameraHeartRate);

        spatial->setSpatialFormat((int)config.spatial.format);
        spatial->enableVisualization(config.spatial.enableVisualization);

        live->enableAbletonLink(config.live.enableAbletonLink);

        ai->enableMasteringMentor(config.ai.enableMasteringMentor);
    }
}

//==============================================================================
// Platform-Specific Optimizations
//==============================================================================

void EchoelMasterSystem::setCPUAffinity(const std::vector<int>& cores)
{
    (void)cores;
    // Platform-specific CPU pinning
    #ifdef __linux__
        // cpu_set_t implementation
    #endif
}

void EchoelMasterSystem::setThreadPriority(int priority)
{
    (void)priority;
    // Platform-specific thread priority
}

void EchoelMasterSystem::lockMemory()
{
    // Platform-specific memory locking
    #if defined(__linux__) || defined(__APPLE__)
        mlockall(MCL_CURRENT | MCL_FUTURE);
    #endif
}

void EchoelMasterSystem::disableCPUThrottling()
{
    // Platform-specific CPU governor control
    // Requires elevated privileges on most systems
}
