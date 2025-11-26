#pragma once

#include <JuceHeader.h>
#include <memory>
#include <queue>
#include <atomic>
#include <mutex>

/**
 * EchoelMasterSystem - Unified Integration of All Echoelmusic Modules
 *
 * This is the MASTER SYSTEM that consolidates the entire Echoelmusic platform
 * into 5 core modules with clean interfaces and professional quality.
 *
 * ARCHITECTURE:
 * ┌─────────────────────────────────────────────────────────────┐
 * │                   ECHOELMUSIC MASTER SYSTEM                 │
 * │                  (EchoelMasterSystem.cpp)                   │
 * └─────────────────────────────────────────────────────────────┘
 *                              │
 *         ┌────────────────────┼────────────────────┐
 *         │                    │                    │
 *     ┌───▼───┐           ┌────▼────┐         ┌────▼────┐
 *     │STUDIO │           │BIOMETRIC│         │ SPATIAL │
 *     │MODULE │           │ MODULE  │         │ MODULE  │
 *     └───┬───┘           └────┬────┘         └────┬────┘
 *         │                    │                    │
 *     ┌───▼───┐           ┌────▼────┐
 *     │ LIVE  │           │   AI    │
 *     │MODULE │           │ MODULE  │
 *     └───────┘           └─────────┘
 *
 * MODULES:
 * 1. STUDIO:    DAW + Content Creation (< 5ms latency)
 * 2. BIOMETRIC: Health + Bio-Reactive Audio
 * 3. SPATIAL:   3D/XR Audio + Visuals + Holographic
 * 4. LIVE:      Performance + Streaming + Collaboration
 * 5. AI:        Intelligent Automation + Mixing + Mastering
 *
 * QUALITY METRICS:
 * - Latency: < 5ms ALWAYS
 * - CPU: < 30% at full project
 * - RAM: < 500MB base
 * - Crashes: 0 in 24h
 * - Startup: < 3 seconds
 *
 * Usage:
 * ```cpp
 * EchoelMasterSystem master;
 * master.initialize();
 *
 * // Access modules
 * auto& studio = master.getStudio();
 * studio.setLatency(LatencyMode::UltraLow);
 *
 * auto& biometric = master.getBiometric();
 * biometric.enableCameraHeartRate(true);
 *
 * // Cross-module features
 * master.enableBioReactiveMix(true);
 * master.enableSpatialVisualization(true);
 * master.enableLivePerformance(true);
 * master.enableAIAssist(true);
 * ```
 */

//==============================================================================
// Forward Declarations
//==============================================================================

class StudioModule;
class BiometricModule;
class SpatialModule;
class LiveModule;
class AIModule;

//==============================================================================
// Error Codes
//==============================================================================

enum class EchoelErrorCode
{
    Success = 0,
    AudioDeviceError,
    AudioBufferUnderrun,
    BiometricDeviceTimeout,
    NetworkConnectionFailed,
    FileIOError,
    PluginLoadError,
    OutOfMemory,
    UnknownError
};

//==============================================================================
// Performance Statistics
//==============================================================================

struct PerformanceStats
{
    // Audio
    double audioLatencyMs = 0.0;
    float cpuUsagePercent = 0.0f;
    int bufferUnderruns = 0;

    // Memory
    size_t ramUsageMB = 0;
    size_t peakRamUsageMB = 0;

    // Processing
    double dspLoadPercent = 0.0;
    int activeVoices = 0;
    int activePlugins = 0;

    // Network (for Live module)
    double networkLatencyMs = 0.0;
    float networkBandwidthMbps = 0.0f;

    // Uptime
    int64_t uptimeSeconds = 0;
    int crashes = 0;

    // Status
    bool isRealtimeSafe = true;
    bool isStable = true;

    juce::String toString() const;
};

//==============================================================================
// Message System (for inter-module communication)
//==============================================================================

enum class MessageType
{
    AudioProcessed,         // Studio → All modules
    BiometricDataReceived,  // Biometric → Studio, AI
    SpatialRenderComplete,  // Spatial → Live
    NetworkPacketReceived,  // Live → Studio
    AIAnalysisComplete,     // AI → Studio
    UserInteraction,        // UI → Modules
    SystemEvent             // General system events
};

struct Message
{
    MessageType type;
    juce::String sourceModule;
    juce::String targetModule;  // Empty = broadcast to all
    juce::var data;
    int64_t timestamp;
};

//==============================================================================
// Module Configuration
//==============================================================================

struct ModuleConfig
{
    // Studio
    struct {
        double sampleRate = 44100.0;
        int bufferSize = 512;
        bool enableMIDI2 = true;
        bool enablePluginHosting = true;
        int maxTracks = 128;
    } studio;

    // Biometric
    struct {
        bool enableCameraHeartRate = true;
        bool enableHealthKit = true;
        bool enableBioReactive = true;
        float bioMappingIntensity = 0.5f;
    } biometric;

    // Spatial
    struct {
        enum class Format { Stereo, Binaural, DolbyAtmos, Ambisonics } format = Format::Stereo;
        bool enableVisualization = true;
        bool enableLightControl = false;
        bool enableHolographic = false;
    } spatial;

    // Live
    struct {
        bool enableStreaming = false;
        bool enableAbletonLink = false;
        bool enableCollaboration = false;
        int maxLatencyMs = 50;
    } live;

    // AI
    struct {
        bool enableSmartMixer = true;
        bool enableAutoMastering = false;
        bool enableMasteringMentor = true;
        bool enableChordDetection = true;
    } ai;
};

//==============================================================================
// MASTER SYSTEM
//==============================================================================

class EchoelMasterSystem : public juce::Timer
{
public:
    //==============================================================================
    // Construction / Destruction
    //==============================================================================

    EchoelMasterSystem();
    ~EchoelMasterSystem() override;

    //==============================================================================
    // Initialization
    //==============================================================================

    /** Initialize all modules */
    EchoelErrorCode initialize(const ModuleConfig& config = ModuleConfig());

    /** Shutdown all modules (safe cleanup) */
    void shutdown();

    /** Check if system is initialized */
    bool isInitialized() const { return initialized; }

    //==============================================================================
    // Module Access
    //==============================================================================

    /** Get Studio module (DAW + Content Creation) */
    StudioModule& getStudio();
    const StudioModule& getStudio() const;

    /** Get Biometric module (Health + Bio-Reactive) */
    BiometricModule& getBiometric();
    const BiometricModule& getBiometric() const;

    /** Get Spatial module (3D/XR Audio + Visuals) */
    SpatialModule& getSpatial();
    const SpatialModule& getSpatial() const;

    /** Get Live module (Performance + Streaming) */
    LiveModule& getLive();
    const LiveModule& getLive() const;

    /** Get AI module (Intelligent Automation) */
    AIModule& getAI();
    const AIModule& getAI() const;

    //==============================================================================
    // Cross-Module Features
    //==============================================================================

    /** Enable bio-reactive mixing (Biometric → Studio) */
    void enableBioReactiveMix(bool enable);
    bool isBioReactiveMixEnabled() const { return bioReactiveMixEnabled; }

    /** Enable spatial visualization (Studio → Spatial) */
    void enableSpatialVisualization(bool enable);
    bool isSpatialVisualizationEnabled() const { return spatialVisualizationEnabled; }

    /** Enable live performance mode (Studio → Live) */
    void enableLivePerformance(bool enable);
    bool isLivePerformanceEnabled() const { return livePerformanceEnabled; }

    /** Enable AI assist (AI → Studio) */
    void enableAIAssist(bool enable);
    bool isAIAssistEnabled() const { return aiAssistEnabled; }

    //==============================================================================
    // Performance Monitoring & Optimization
    //==============================================================================

    /** Ensure realtime performance (CPU pinning, memory locking, etc.) */
    void ensureRealtimePerformance();

    /** Get current performance statistics */
    PerformanceStats getStats() const;

    /** Get CPU usage percentage */
    float getCPUUsage() const;

    /** Get RAM usage in MB */
    size_t getRAMUsageMB() const;

    /** Get audio latency in milliseconds */
    double getAudioLatencyMs() const;

    /** Check if system is running in realtime-safe mode */
    bool isRealtimeSafe() const;

    //==============================================================================
    // Message System
    //==============================================================================

    /** Send message to module(s) */
    void sendMessage(const Message& message);

    /** Register message listener */
    void addMessageListener(std::function<void(const Message&)> listener);

    //==============================================================================
    // Configuration
    //==============================================================================

    /** Update configuration */
    void setConfig(const ModuleConfig& config);

    /** Get current configuration */
    ModuleConfig getConfig() const { return config; }

    //==============================================================================
    // Error Handling
    //==============================================================================

    /** Get last error */
    EchoelErrorCode getLastError() const { return lastError; }

    /** Get error message */
    juce::String getErrorMessage() const;

    /** Set error callback */
    void setErrorCallback(std::function<void(EchoelErrorCode, const juce::String&)> callback);

private:
    //==============================================================================
    // Module Instances
    //==============================================================================

    std::unique_ptr<StudioModule> studio;
    std::unique_ptr<BiometricModule> biometric;
    std::unique_ptr<SpatialModule> spatial;
    std::unique_ptr<LiveModule> live;
    std::unique_ptr<AIModule> ai;

    //==============================================================================
    // State
    //==============================================================================

    std::atomic<bool> initialized{false};
    std::atomic<bool> shuttingDown{false};

    ModuleConfig config;
    EchoelErrorCode lastError = EchoelErrorCode::Success;

    // Cross-module features
    std::atomic<bool> bioReactiveMixEnabled{false};
    std::atomic<bool> spatialVisualizationEnabled{false};
    std::atomic<bool> livePerformanceEnabled{false};
    std::atomic<bool> aiAssistEnabled{false};

    //==============================================================================
    // Message System
    //==============================================================================

    std::queue<Message> messageQueue;
    std::mutex messageQueueMutex;
    std::vector<std::function<void(const Message&)>> messageListeners;

    void processMessageQueue();
    void routeMessage(const Message& message);

    //==============================================================================
    // Inter-Module Connections
    //==============================================================================

    void connectModules();
    void disconnectModules();

    // Callbacks
    void onAudioProcessed(const juce::AudioBuffer<float>& buffer);
    void onBiometricData(float heartRate, float hrv, float stress, float focus);
    void onSpatialRender();
    void onNetworkPacket();
    void onAIAnalysis();

    //==============================================================================
    // Performance Monitoring
    //==============================================================================

    mutable PerformanceStats currentStats;
    std::atomic<int64_t> startTime{0};

    void updateStats();
    void timerCallback() override;  // Update stats periodically

    //==============================================================================
    // Error Handling
    //==============================================================================

    std::function<void(EchoelErrorCode, const juce::String&)> errorCallback;

    void reportError(EchoelErrorCode code, const juce::String& message);

    //==============================================================================
    // Platform-Specific Optimizations
    //==============================================================================

    void setCPUAffinity(const std::vector<int>& cores);
    void setThreadPriority(int priority);
    void lockMemory();
    void disableCPUThrottling();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(EchoelMasterSystem)
};

//==============================================================================
// Module Interface Stubs (to be fully implemented)
//==============================================================================

/**
 * StudioModule - Complete DAW + Content Creation
 * Latency Target: < 5ms ALWAYS
 */
class StudioModule
{
public:
    StudioModule() = default;
    ~StudioModule() = default;

    // Core audio
    void setLatency(int bufferSize) { (void)bufferSize; }
    void setSampleRate(double rate) { (void)rate; }

    // MIDI
    void connectMIDIDevice(const juce::String& device) { (void)device; }

    // Plugins
    void scanPlugins() {}
    void loadPlugin(const juce::String& path, int track) { (void)path; (void)track; }

    // Project
    void newProject(const juce::String& templateName = "") { (void)templateName; }
    void saveProject(const juce::File& file) { (void)file; }
    void loadProject(const juce::File& file) { (void)file; }
};

/**
 * BiometricModule - Health + Bio-Reactive Audio
 */
class BiometricModule
{
public:
    BiometricModule() = default;
    ~BiometricModule() = default;

    void enableCameraHeartRate(bool enable) { (void)enable; }
    float getCurrentHeartRate() const { return 70.0f; }
    float getStressLevel() const { return 0.3f; }
    float getFocusLevel() const { return 0.7f; }
};

/**
 * SpatialModule - 3D/XR Audio + Visuals
 */
class SpatialModule
{
public:
    SpatialModule() = default;
    ~SpatialModule() = default;

    void setSpatialFormat(int format) { (void)format; }
    void enableVisualization(bool enable) { (void)enable; }
};

/**
 * LiveModule - Performance + Streaming
 */
class LiveModule
{
public:
    LiveModule() = default;
    ~LiveModule() = default;

    void startStream() {}
    void stopStream() {}
    void enableAbletonLink(bool enable) { (void)enable; }
};

/**
 * AIModule - Intelligent Automation
 */
class AIModule
{
public:
    AIModule() = default;
    ~AIModule() = default;

    void analyzeMix() {}
    void autoBalance() {}
    void enableMasteringMentor(bool enable) { (void)enable; }
};
