#pragma once

#include <JuceHeader.h>
#include <atomic>
#include <memory>
#include <functional>

/**
 * RemoteProcessingEngine
 *
 * Ermöglicht latenzfreie Remote-Verarbeitung von Audio/Video auf leistungsstarken
 * Backend-Servern. Mobile Geräte können rechenintensive Tasks an Desktop/Server
 * auslagern und arbeiten trotzdem in Echtzeit.
 *
 * Features:
 * - Ultra-low latency streaming (< 10ms over LAN, < 50ms over Internet)
 * - Sample-accurate sync mit Ableton Link
 * - Adaptive quality/bitrate (basierend auf Netzwerk-Latenz)
 * - Automatic fallback auf lokale Verarbeitung
 * - Opus codec für Audio (ultra-low latency mode)
 * - H.265/AV1 für Video (hardware encoding)
 * - WebRTC data channels für Control
 * - Ende-zu-Ende Verschlüsselung (AES-256-GCM)
 *
 * Anwendungsfälle:
 * - iPad → MacBook Pro processing
 * - Android Phone → Gaming PC rendering
 * - Laptop → Cloud Server (Hetzner, AWS, Azure)
 * - Cross-platform collaboration
 *
 * Network Requirements:
 * - LAN: > 100 Mbps, < 5ms latency (optimal)
 * - WiFi 6/6E: > 50 Mbps, < 10ms latency (good)
 * - Internet: > 10 Mbps, < 50ms latency (acceptable)
 * - 5G: > 20 Mbps, < 30ms latency (mobile use)
 */
class RemoteProcessingEngine
{
public:
    //==========================================================================
    // Connection Types
    //==========================================================================

    enum class ConnectionType
    {
        Local,          // Same device (no network)
        LAN,            // Local network (< 5ms)
        Internet,       // Public internet (< 50ms)
        Mobile5G,       // 5G mobile network (< 30ms)
        Bluetooth       // Bluetooth audio (LDAC/aptX HD)
    };

    enum class ProcessingMode
    {
        LocalOnly,      // Process on local device
        RemoteOnly,     // Process on remote server
        Hybrid,         // Intelligente Aufteilung (CPU-intensive → remote)
        Adaptive        // Automatisch basierend auf Netzwerk-Qualität
    };

    enum class RemoteCapability
    {
        AudioProcessing,    // DSP effects
        VideoRendering,     // Video effects/encoding
        AIInference,        // ML models
        Synthesis,          // Synth/sampler
        Mixing,             // Final mix/master
        Recording           // Direct-to-disk recording
    };

    //==========================================================================
    // Remote Server Info
    //==========================================================================

    struct RemoteServer
    {
        juce::String hostName;              // e.g., "studio-pc.local" oder IP
        int port = 7777;                    // Default Eoel remote port

        juce::String deviceName;            // "MacBook Pro M3 Max"
        juce::String osVersion;             // "macOS 15.1"

        // Hardware specs
        int cpuCores = 0;
        int cpuThreads = 0;
        float cpuFrequency = 0.0f;          // GHz
        int ramGB = 0;
        juce::String gpuModel;
        int gpuVRAM = 0;                    // MB

        // Available capabilities
        juce::Array<RemoteCapability> capabilities;

        // Network status
        float latencyMs = 0.0f;
        float bandwidthMbps = 0.0f;
        float packetLoss = 0.0f;            // 0.0 to 1.0

        // Authentication
        juce::String authToken;             // JWT token
        bool isVerified = false;
        bool isTrusted = false;

        // Status
        bool isOnline = false;
        bool isAvailable = true;            // Not busy
        float cpuLoad = 0.0f;               // 0.0 to 1.0
        float gpuLoad = 0.0f;
    };

    //==========================================================================
    // Processing Task
    //==========================================================================

    struct ProcessingTask
    {
        juce::String taskId;                // Unique ID
        RemoteCapability capability;

        // Audio data
        juce::AudioBuffer<float> inputBuffer;
        int sampleRate = 48000;

        // Video data (optional)
        juce::Image videoFrame;

        // Parameters
        juce::var parameters;               // JSON object with effect params

        // Timing
        int64_t samplePosition = 0;         // For Ableton Link sync
        double tempo = 120.0;
        double timeSignature = 4.0;

        // Priority
        bool isRealtime = true;             // High priority
        int64_t deadline = 0;               // Timestamp in microseconds

        // Callback
        std::function<void(juce::AudioBuffer<float>&, juce::Image&)> onComplete;
        std::function<void(const juce::String&)> onError;
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    RemoteProcessingEngine();
    ~RemoteProcessingEngine();

    //==========================================================================
    // Connection Management
    //==========================================================================

    /** Discover servers on local network (mDNS/Bonjour) */
    void discoverServers();

    /** Get list of discovered servers */
    juce::Array<RemoteServer> getAvailableServers() const;

    /** Connect to a specific server */
    bool connectToServer(const RemoteServer& server);

    /** Disconnect from current server */
    void disconnect();

    /** Check if connected */
    bool isConnected() const;

    /** Get current server info */
    RemoteServer getCurrentServer() const;

    /** Enable auto-reconnect */
    void setAutoReconnect(bool enable);

    //==========================================================================
    // Processing Mode
    //==========================================================================

    void setProcessingMode(ProcessingMode mode);
    ProcessingMode getProcessingMode() const { return currentMode; }

    /** Enable specific capabilities for remote processing */
    void setRemoteCapabilities(const juce::Array<RemoteCapability>& caps);

    /** Check if capability can be processed remotely */
    bool canProcessRemotely(RemoteCapability capability) const;

    //==========================================================================
    // Task Submission
    //==========================================================================

    /** Submit task for processing (async) */
    juce::String submitTask(ProcessingTask task);

    /** Cancel pending task */
    void cancelTask(const juce::String& taskId);

    /** Get task status */
    enum class TaskStatus
    {
        Pending,
        Transmitting,
        Processing,
        Receiving,
        Completed,
        Failed,
        Cancelled
    };

    TaskStatus getTaskStatus(const juce::String& taskId) const;

    //==========================================================================
    // Real-Time Audio Processing
    //==========================================================================

    /** Process audio buffer in real-time (sync with local audio thread) */
    void processBlock(juce::AudioBuffer<float>& buffer,
                     RemoteCapability capability,
                     const juce::var& parameters);

    /** Set local fallback processor (wenn Netzwerk zu langsam) */
    using LocalFallbackProcessor = std::function<void(juce::AudioBuffer<float>&, const juce::var&)>;
    void setLocalFallback(RemoteCapability capability, LocalFallbackProcessor processor);

    //==========================================================================
    // Ableton Link Sync
    //==========================================================================

    /** Enable Ableton Link sync für sample-accurate timing */
    void enableAbletonLink(bool enable);
    bool isAbletonLinkEnabled() const;

    /** Get current Link session state */
    struct LinkState
    {
        double tempo = 120.0;
        double beat = 0.0;
        double phase = 0.0;
        int64_t sampleTime = 0;
        int numPeers = 0;
        bool isPlaying = false;
    };

    LinkState getLinkState() const;

    //==========================================================================
    // Network Quality Monitoring
    //==========================================================================

    struct NetworkStats
    {
        float latencyMs = 0.0f;
        float jitterMs = 0.0f;
        float bandwidthMbps = 0.0f;
        float packetLoss = 0.0f;        // 0.0 to 1.0
        float roundTripMs = 0.0f;
        int droppedFrames = 0;

        // Quality score (0.0 to 1.0)
        float qualityScore = 1.0f;      // 1.0 = perfect, 0.0 = unusable
    };

    NetworkStats getNetworkStats() const;

    /** Callback for network quality changes */
    std::function<void(const NetworkStats&)> onNetworkQualityChanged;

    //==========================================================================
    // Quality Settings
    //==========================================================================

    enum class QualityPreset
    {
        UltraLow,       // 16-bit, 24kHz, mono (Bluetooth)
        Low,            // 16-bit, 44.1kHz, stereo
        Medium,         // 24-bit, 48kHz, stereo (default)
        High,           // 32-bit float, 96kHz, stereo
        Studio          // 32-bit float, 192kHz, multi-channel
    };

    void setQualityPreset(QualityPreset preset);
    QualityPreset getQualityPreset() const { return currentQuality; }

    /** Enable adaptive quality (automatically adjust based on network) */
    void setAdaptiveQuality(bool enable);

    //==========================================================================
    // Security
    //==========================================================================

    /** Set encryption key (AES-256) */
    void setEncryptionKey(const juce::String& key);

    /** Enable end-to-end encryption */
    void setEncryptionEnabled(bool enable);
    bool isEncryptionEnabled() const { return encryptionEnabled; }

    /** Verify server certificate (for HTTPS/WSS connections) */
    void setVerifyServerCertificate(bool verify);

    //==========================================================================
    // Server Mode (this device as server)
    //==========================================================================

    /** Start server mode (allow other devices to connect) */
    bool startServer(int port = 7777);

    /** Stop server mode */
    void stopServer();

    /** Check if server is running */
    bool isServerRunning() const;

    /** Set allowed client authentication */
    void setAllowedClients(const juce::StringArray& clientTokens);

    /** Callback for incoming client connection */
    std::function<bool(const juce::String& clientId)> onClientConnecting;

    //==========================================================================
    // Recording to Remote Storage
    //==========================================================================

    /** Start recording directly to remote server (saves local storage) */
    bool startRemoteRecording(const juce::File& remoteFilePath);

    /** Stop remote recording */
    void stopRemoteRecording();

    /** Check if currently recording to remote */
    bool isRemoteRecording() const;

    /** Get remote recording position (samples) */
    int64_t getRemoteRecordingPosition() const;

    //==========================================================================
    // Statistics
    //==========================================================================

    struct ProcessingStats
    {
        int64_t totalTasksSubmitted = 0;
        int64_t totalTasksCompleted = 0;
        int64_t totalTasksFailed = 0;

        double averageLatencyMs = 0.0;
        double averageProcessingTimeMs = 0.0;

        int64_t totalBytesTransmitted = 0;
        int64_t totalBytesReceived = 0;

        float localCpuSavings = 0.0f;   // 0.0 to 1.0 (how much CPU saved)

        juce::Time connectionStartTime;
        int64_t connectionDurationSeconds = 0;
    };

    ProcessingStats getProcessingStats() const;
    void resetStatistics();

private:
    //==========================================================================
    // Internal State
    //==========================================================================

    ProcessingMode currentMode = ProcessingMode::Adaptive;
    QualityPreset currentQuality = QualityPreset::Medium;

    std::atomic<bool> isConnectedFlag { false };
    std::atomic<bool> encryptionEnabled { true };
    std::atomic<bool> abletonLinkEnabled { false };
    std::atomic<bool> serverModeActive { false };

    RemoteServer currentServer;
    juce::Array<RemoteServer> discoveredServers;

    // Network monitoring
    NetworkStats currentNetworkStats;
    std::atomic<float> currentLatencyMs { 0.0f };

    // Task queue
    struct InternalTask
    {
        ProcessingTask task;
        TaskStatus status;
        juce::Time submissionTime;
        juce::Time completionTime;
    };

    juce::HashMap<juce::String, InternalTask> activeTasks;
    juce::CriticalSection tasksMutex;

    // Local fallback processors
    juce::HashMap<int, LocalFallbackProcessor> fallbackProcessors;

    // Statistics
    ProcessingStats statistics;

    // Ableton Link (forward declaration, implementation uses Link SDK)
    struct LinkImpl;
    std::unique_ptr<LinkImpl> linkImpl;

    // Network transport (WebRTC data channels + audio/video streams)
    struct NetworkTransport;
    std::unique_ptr<NetworkTransport> transport;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    void updateNetworkStats();
    void handleIncomingTask(const ProcessingTask& task);
    void handleTaskCompletion(const juce::String& taskId,
                             const juce::AudioBuffer<float>& result);
    void handleTaskError(const juce::String& taskId, const juce::String& error);

    bool shouldUseRemoteProcessing(RemoteCapability capability) const;
    void fallbackToLocalProcessing(juce::AudioBuffer<float>& buffer,
                                   RemoteCapability capability,
                                   const juce::var& parameters);

    // Network discovery (mDNS/Bonjour)
    void startServerDiscovery();
    void stopServerDiscovery();

    // Codec selection based on network quality
    enum class AudioCodec { Opus, AAC_LD, FLAC, PCM };
    AudioCodec selectOptimalCodec() const;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(RemoteProcessingEngine)
};
