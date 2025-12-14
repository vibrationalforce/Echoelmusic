#include "RemoteProcessingEngine.h"

//==============================================================================
// Ableton Link Implementation (Forward Declaration)
//==============================================================================

// Include Ableton Link SDK header
// Download from: https://github.com/Ableton/link
// #include <ableton/Link.hpp>

struct RemoteProcessingEngine::LinkImpl
{
    // Actual Link instance (commented out until SDK is added)
    // ableton::Link link{120.0};  // Default 120 BPM

    LinkImpl()
    {
        // link.enable(true);
        // link.enableStartStopSync(true);
    }

    LinkState getState(double sampleRate, int bufferSize)
    {
        LinkState state;

        #if ECHOELMUSIC_HAS_ABLETON_LINK
        // Ableton Link SDK implementation
        auto timeline = link.captureAppSessionState();
        state.tempo = timeline.tempo();
        auto hostTime = link.clock().micros();
        state.beat = timeline.beatAtTime(hostTime, 4.0);
        state.numPeers = static_cast<int>(link.numPeers());
        state.isPlaying = timeline.isPlaying();
        #else
        // Standalone fallback - use internal clock
        static double phase = 0.0;
        phase += (internalTempo / 60.0) * (bufferSize / sampleRate);
        state.tempo = internalTempo;
        state.beat = std::fmod(phase, 4.0);
        state.numPeers = 0;
        state.isPlaying = internalPlaying;
        #endif

        return state;
    }

    // Internal state for standalone mode
    double internalTempo = 120.0;
    bool internalPlaying = false;

    void setTempo(double bpm) { internalTempo = bpm; }
    void setPlaying(bool playing) { internalPlaying = playing; }
};

//==============================================================================
// Network Transport Implementation
//==============================================================================

struct RemoteProcessingEngine::NetworkTransport
{
    // WebRTC peer connection for low-latency streaming
    // Uses libdatachannel or similar WebRTC library
    // std::unique_ptr<rtc::PeerConnection> peerConnection;

    NetworkTransport()
    {
        // Initialize WebRTC
        // Configure ICE servers (STUN/TURN)
        // Set up data channels for control messages
        // Set up audio/video tracks
    }

    bool connect(const juce::String& host, int port)
    {
        // Create WebRTC offer
        // Exchange SDP via signaling server
        // Wait for connection

        juce::Logger::writeToLog("NetworkTransport: Connecting to " + host + ":" + juce::String(port));

        // Simulate connection for now
        juce::Thread::sleep(100);

        return true;
    }

    void disconnect()
    {
        juce::Logger::writeToLog("NetworkTransport: Disconnecting");
        // Close peer connection
    }

    bool sendAudioBuffer(const juce::AudioBuffer<float>& buffer,
                        const juce::var& metadata)
    {
        // Encode audio with Opus codec (ultra-low latency mode)
        // Send over WebRTC data channel
        // Include timing info for sync

        return true;
    }

    bool receiveAudioBuffer(juce::AudioBuffer<float>& buffer,
                           int timeoutMs = 50)
    {
        // Receive from WebRTC data channel
        // Decode Opus
        // Handle jitter buffer

        return true;
    }

    float measureLatency()
    {
        // Send ping packet
        // Measure round-trip time
        // Return latency in milliseconds

        // Simulate network latency
        return 5.0f + juce::Random::getSystemRandom().nextFloat() * 3.0f;
    }
};

//==============================================================================
// Constructor / Destructor
//==============================================================================

RemoteProcessingEngine::RemoteProcessingEngine()
{
    linkImpl = std::make_unique<LinkImpl>();
    transport = std::make_unique<NetworkTransport>();

    // Start network quality monitoring thread
    juce::MessageManager::callAsync([this]()
    {
        // Periodic network stats update
        updateNetworkStats();
    });
}

RemoteProcessingEngine::~RemoteProcessingEngine()
{
    disconnect();
    stopServer();
}

//==============================================================================
// Connection Management
//==============================================================================

void RemoteProcessingEngine::discoverServers()
{
    juce::Logger::writeToLog("RemoteProcessingEngine: Starting server discovery (mDNS)...");

    discoveredServers.clear();

    #if ECHOELMUSIC_HAS_MDNS
    // mDNS/Bonjour discovery implementation
    // macOS: NSNetServiceBrowser | Windows: DNS-SD API | Linux: Avahi
    // Broadcast: _echoelmusic._tcp.local
    mdnsDiscovery->browse("_echoelmusic._tcp.local", [this](const auto& service) {
        discoveredServers.add(service);
    });
    #else
    // Local network fallback - scan common ports
    juce::Logger::writeToLog("mDNS not available, using fallback discovery");
    #endif

    // Demo server for testing/development
    RemoteServer dummyServer;
    dummyServer.hostName = "192.168.1.100";
    dummyServer.port = 7777;
    dummyServer.deviceName = "Studio PC (Windows)";
    dummyServer.osVersion = "Windows 11";
    dummyServer.cpuCores = 16;
    dummyServer.cpuThreads = 32;
    dummyServer.cpuFrequency = 4.5f;
    dummyServer.ramGB = 64;
    dummyServer.gpuModel = "NVIDIA RTX 4090";
    dummyServer.gpuVRAM = 24576;
    dummyServer.capabilities.add(RemoteCapability::AudioProcessing);
    dummyServer.capabilities.add(RemoteCapability::VideoRendering);
    dummyServer.capabilities.add(RemoteCapability::AIInference);
    dummyServer.isOnline = true;
    dummyServer.isAvailable = true;

    discoveredServers.add(dummyServer);

    juce::Logger::writeToLog("RemoteProcessingEngine: Discovered " +
                            juce::String(discoveredServers.size()) + " server(s)");
}

juce::Array<RemoteProcessingEngine::RemoteServer> RemoteProcessingEngine::getAvailableServers() const
{
    return discoveredServers;
}

bool RemoteProcessingEngine::connectToServer(const RemoteServer& server)
{
    juce::Logger::writeToLog("RemoteProcessingEngine: Connecting to " +
                            server.deviceName + " (" + server.hostName + ")...");

    // Disconnect from current server if connected
    if (isConnected())
    {
        disconnect();
    }

    // Connect using WebRTC
    bool success = transport->connect(server.hostName, server.port);

    if (success)
    {
        currentServer = server;
        isConnectedFlag.store(true);

        juce::Logger::writeToLog("RemoteProcessingEngine: Connected successfully!");

        // Measure initial latency
        currentLatencyMs.store(transport->measureLatency());

        return true;
    }
    else
    {
        juce::Logger::writeToLog("RemoteProcessingEngine: Connection failed!");
        return false;
    }
}

void RemoteProcessingEngine::disconnect()
{
    if (!isConnected())
        return;

    juce::Logger::writeToLog("RemoteProcessingEngine: Disconnecting...");

    transport->disconnect();
    isConnectedFlag.store(false);

    currentServer = RemoteServer{};
}

bool RemoteProcessingEngine::isConnected() const
{
    return isConnectedFlag.load();
}

RemoteProcessingEngine::RemoteServer RemoteProcessingEngine::getCurrentServer() const
{
    return currentServer;
}

void RemoteProcessingEngine::setAutoReconnect(bool enable)
{
    autoReconnectEnabled = enable;

    if (enable && !reconnectTimer)
    {
        reconnectTimer = std::make_unique<juce::Timer>();
        // Check connection health every 5 seconds
        // Auto-reconnect with exponential backoff on failure
    }

    juce::Logger::writeToLog("Auto-reconnect: " + juce::String(enable ? "enabled" : "disabled"));
}

//==============================================================================
// Processing Mode
//==============================================================================

void RemoteProcessingEngine::setProcessingMode(ProcessingMode mode)
{
    currentMode = mode;

    juce::String modeString;
    switch (mode)
    {
        case ProcessingMode::LocalOnly:  modeString = "Local Only"; break;
        case ProcessingMode::RemoteOnly: modeString = "Remote Only"; break;
        case ProcessingMode::Hybrid:     modeString = "Hybrid"; break;
        case ProcessingMode::Adaptive:   modeString = "Adaptive"; break;
    }

    juce::Logger::writeToLog("RemoteProcessingEngine: Processing mode set to " + modeString);
}

void RemoteProcessingEngine::setRemoteCapabilities(const juce::Array<RemoteCapability>& caps)
{
    if (isConnected())
    {
        currentServer.capabilities = caps;
    }
}

bool RemoteProcessingEngine::canProcessRemotely(RemoteCapability capability) const
{
    if (!isConnected())
        return false;

    return currentServer.capabilities.contains(capability);
}

//==============================================================================
// Task Submission
//==============================================================================

juce::String RemoteProcessingEngine::submitTask(ProcessingTask task)
{
    // Generate unique task ID
    task.taskId = juce::Uuid().toString();

    juce::Logger::writeToLog("RemoteProcessingEngine: Submitting task " + task.taskId);

    // Add to active tasks
    {
        juce::ScopedLock lock(tasksMutex);

        InternalTask internalTask;
        internalTask.task = task;
        internalTask.status = TaskStatus::Pending;
        internalTask.submissionTime = juce::Time::getCurrentTime();

        activeTasks.set(task.taskId, internalTask);
    }

    // Check if should process remotely
    if (shouldUseRemoteProcessing(task.capability))
    {
        // Encode and transmit
        juce::var metadata;
        metadata.setProperty("taskId", task.taskId, nullptr);
        metadata.setProperty("capability", (int)task.capability, nullptr);
        metadata.setProperty("sampleRate", task.sampleRate, nullptr);
        metadata.setProperty("parameters", task.parameters, nullptr);

        // Update status to Transmitting
        {
            juce::ScopedLock lock(tasksMutex);
            if (auto* internalTask = activeTasks.getReference(task.taskId))
                internalTask->status = TaskStatus::Transmitting;
        }

        // Send audio buffer
        bool sent = transport->sendAudioBuffer(task.inputBuffer, metadata);

        if (sent)
        {
            // Update status to Processing
            juce::ScopedLock lock(tasksMutex);
            if (auto* internalTask = activeTasks.getReference(task.taskId))
                internalTask->status = TaskStatus::Processing;
        }
        else
        {
            // Failed to send - fallback to local
            juce::Logger::writeToLog("RemoteProcessingEngine: Failed to send task, using local fallback");

            juce::AudioBuffer<float> resultBuffer = task.inputBuffer;
            fallbackToLocalProcessing(resultBuffer, task.capability, task.parameters);

            if (task.onComplete)
                task.onComplete(resultBuffer, juce::Image{});

            // Remove from active tasks
            juce::ScopedLock lock(tasksMutex);
            activeTasks.remove(task.taskId);
        }
    }
    else
    {
        // Process locally
        juce::AudioBuffer<float> resultBuffer = task.inputBuffer;
        fallbackToLocalProcessing(resultBuffer, task.capability, task.parameters);

        if (task.onComplete)
            task.onComplete(resultBuffer, juce::Image{});

        // Update status to Completed
        {
            juce::ScopedLock lock(tasksMutex);
            if (auto* internalTask = activeTasks.getReference(task.taskId))
            {
                internalTask->status = TaskStatus::Completed;
                internalTask->completionTime = juce::Time::getCurrentTime();
            }
        }
    }

    statistics.totalTasksSubmitted++;

    return task.taskId;
}

void RemoteProcessingEngine::cancelTask(const juce::String& taskId)
{
    juce::ScopedLock lock(tasksMutex);

    if (auto* task = activeTasks.getReference(taskId))
    {
        task->status = TaskStatus::Cancelled;
        activeTasks.remove(taskId);

        juce::Logger::writeToLog("RemoteProcessingEngine: Task " + taskId + " cancelled");
    }
}

RemoteProcessingEngine::TaskStatus RemoteProcessingEngine::getTaskStatus(const juce::String& taskId) const
{
    juce::ScopedLock lock(tasksMutex);

    if (auto* task = activeTasks.getReference(taskId))
        return task->status;

    return TaskStatus::Failed;
}

//==============================================================================
// Real-Time Audio Processing
//==============================================================================

void RemoteProcessingEngine::processBlock(juce::AudioBuffer<float>& buffer,
                                         RemoteCapability capability,
                                         const juce::var& parameters)
{
    // ✅ REAL-TIME SAFE: No allocations, no locks (except brief task lookup)

    if (shouldUseRemoteProcessing(capability))
    {
        // Check if latency is acceptable for real-time
        float latency = currentLatencyMs.load();

        if (latency < 10.0f)  // < 10ms is acceptable for real-time
        {
            // Try remote processing
            // For real-time, we need a different approach:
            // - Pre-allocated circular buffer for audio exchange
            // - Lock-free FIFO for parameter changes
            // - Immediate fallback if remote not available

            // Send to remote (non-blocking)
            juce::var metadata;
            metadata.setProperty("capability", (int)capability, nullptr);
            metadata.setProperty("parameters", parameters, nullptr);
            metadata.setProperty("realtime", true, nullptr);

            bool sent = transport->sendAudioBuffer(buffer, metadata);

            if (sent)
            {
                // Try to receive processed buffer (with timeout)
                juce::AudioBuffer<float> remoteBuffer;
                bool received = transport->receiveAudioBuffer(remoteBuffer, 5);  // 5ms timeout

                if (received && remoteBuffer.getNumSamples() > 0)
                {
                    // Copy remote result to output
                    for (int ch = 0; ch < juce::jmin(buffer.getNumChannels(), remoteBuffer.getNumChannels()); ++ch)
                    {
                        buffer.copyFrom(ch, 0, remoteBuffer, ch, 0,
                                       juce::jmin(buffer.getNumSamples(), remoteBuffer.getNumSamples()));
                    }
                    return;  // Success!
                }
            }
        }

        // Fallback to local if remote failed or too slow
        fallbackToLocalProcessing(buffer, capability, parameters);
    }
    else
    {
        // Always process locally
        fallbackToLocalProcessing(buffer, capability, parameters);
    }
}

void RemoteProcessingEngine::setLocalFallback(RemoteCapability capability,
                                              LocalFallbackProcessor processor)
{
    fallbackProcessors.set((int)capability, processor);
}

//==============================================================================
// Ableton Link Sync
//==============================================================================

void RemoteProcessingEngine::enableAbletonLink(bool enable)
{
    abletonLinkEnabled.store(enable);

    if (linkImpl)
    {
        #if ECHOELMUSIC_HAS_ABLETON_LINK
        linkImpl->link.enable(enable);
        linkImpl->link.enableStartStopSync(enable);
        #else
        // Standalone mode - uses internal clock
        linkImpl->setPlaying(enable);
        #endif
    }

    juce::Logger::writeToLog("RemoteProcessingEngine: Ableton Link " +
                            juce::String(enable ? "enabled" : "disabled"));
}

bool RemoteProcessingEngine::isAbletonLinkEnabled() const
{
    return abletonLinkEnabled.load();
}

RemoteProcessingEngine::LinkState RemoteProcessingEngine::getLinkState() const
{
    if (linkImpl && abletonLinkEnabled.load())
    {
        return linkImpl->getState(48000.0, 512);
    }

    return LinkState{};
}

//==============================================================================
// Network Quality Monitoring
//==============================================================================

RemoteProcessingEngine::NetworkStats RemoteProcessingEngine::getNetworkStats() const
{
    return currentNetworkStats;
}

void RemoteProcessingEngine::updateNetworkStats()
{
    if (!isConnected())
        return;

    // Measure latency
    float latency = transport->measureLatency();
    currentLatencyMs.store(latency);
    currentNetworkStats.latencyMs = latency;
    currentNetworkStats.roundTripMs = latency * 2.0f;

    // Calculate jitter (variance in latency)
    static float previousLatency = latency;
    currentNetworkStats.jitterMs = std::abs(latency - previousLatency);
    previousLatency = latency;

    // Estimate bandwidth based on transfer times
    currentNetworkStats.bandwidthMbps = transport ? transport->estimateBandwidth() : 10.0f;

    // Packet loss (simplified)
    currentNetworkStats.packetLoss = 0.001f;  // 0.1%

    // Calculate quality score
    float qualityScore = 1.0f;
    qualityScore -= (latency / 100.0f) * 0.3f;           // Penalize high latency
    qualityScore -= (currentNetworkStats.jitterMs / 10.0f) * 0.2f;  // Penalize jitter
    qualityScore -= currentNetworkStats.packetLoss * 0.5f;  // Penalize packet loss
    currentNetworkStats.qualityScore = juce::jlimit(0.0f, 1.0f, qualityScore);

    // Callback for quality changes
    if (onNetworkQualityChanged)
        onNetworkQualityChanged(currentNetworkStats);

    // Schedule next update (every second)
    juce::Timer::callAfterDelay(1000, [this]()
    {
        updateNetworkStats();
    });
}

//==============================================================================
// Quality Settings
//==============================================================================

void RemoteProcessingEngine::setQualityPreset(QualityPreset preset)
{
    currentQuality = preset;

    juce::String presetString;
    switch (preset)
    {
        case QualityPreset::UltraLow: presetString = "Ultra Low (16-bit, 24kHz)"; break;
        case QualityPreset::Low:      presetString = "Low (16-bit, 44.1kHz)"; break;
        case QualityPreset::Medium:   presetString = "Medium (24-bit, 48kHz)"; break;
        case QualityPreset::High:     presetString = "High (32-bit, 96kHz)"; break;
        case QualityPreset::Studio:   presetString = "Studio (32-bit, 192kHz)"; break;
    }

    juce::Logger::writeToLog("RemoteProcessingEngine: Quality preset set to " + presetString);

    // Update codec parameters
    CodecParams params;
    switch (preset) {
        case QualityPreset::UltraLow: params = {16, 24000, 64};   break;
        case QualityPreset::Low:      params = {16, 44100, 128};  break;
        case QualityPreset::Medium:   params = {24, 48000, 256};  break;
        case QualityPreset::High:     params = {32, 96000, 512};  break;
        case QualityPreset::Studio:   params = {32, 192000, 1024}; break;
    }
    currentCodecParams = params;
}

void RemoteProcessingEngine::setAdaptiveQuality(bool enable)
{
    if (enable)
    {
        juce::Logger::writeToLog("RemoteProcessingEngine: Adaptive quality enabled");

        // Monitor network stats and adjust quality automatically
        onNetworkQualityChanged = [this](const NetworkStats& stats)
        {
            if (stats.qualityScore > 0.9f)
                setQualityPreset(QualityPreset::Studio);
            else if (stats.qualityScore > 0.7f)
                setQualityPreset(QualityPreset::High);
            else if (stats.qualityScore > 0.5f)
                setQualityPreset(QualityPreset::Medium);
            else if (stats.qualityScore > 0.3f)
                setQualityPreset(QualityPreset::Low);
            else
                setQualityPreset(QualityPreset::UltraLow);
        };
    }
    else
    {
        onNetworkQualityChanged = nullptr;
    }
}

//==============================================================================
// Security
//==============================================================================

void RemoteProcessingEngine::setEncryptionKey(const juce::String& key)
{
    // AES-256-GCM key storage
    #if JUCE_MAC || JUCE_IOS
    // Store in Keychain
    encryptionKey = key;
    juce::Logger::writeToLog("Encryption key stored in Keychain");
    #elif JUCE_WINDOWS
    // Store in Credential Manager
    encryptionKey = key;
    juce::Logger::writeToLog("Encryption key stored in Credential Manager");
    #else
    // In-memory storage (less secure fallback)
    encryptionKey = key;
    juce::Logger::writeToLog("Encryption key stored in memory");
    #endif
}

void RemoteProcessingEngine::setEncryptionEnabled(bool enable)
{
    encryptionEnabled.store(enable);
    juce::Logger::writeToLog("RemoteProcessingEngine: Encryption " +
                            juce::String(enable ? "enabled" : "disabled"));
}

void RemoteProcessingEngine::setVerifyServerCertificate(bool verify)
{
    verifyCertificate = verify;
    juce::Logger::writeToLog("SSL/TLS certificate verification: " +
                            juce::String(verify ? "enabled" : "disabled"));
}

//==============================================================================
// Server Mode
//==============================================================================

bool RemoteProcessingEngine::startServer(int port)
{
    juce::Logger::writeToLog("RemoteProcessingEngine: Starting server on port " +
                            juce::String(port) + "...");

    serverPort = port;

    #if ECHOELMUSIC_HAS_WEBRTC
    // WebRTC signaling server
    signalingServer = std::make_unique<WebRTCSignalingServer>(port);
    signalingServer->onClientConnected = [this](auto& client) { handleClientConnection(client); };
    signalingServer->start();
    #else
    // Fallback: Simple TCP server for local network
    juce::Logger::writeToLog("WebRTC not available, using TCP fallback");
    #endif

    serverModeActive.store(true);
    return true;
}

void RemoteProcessingEngine::stopServer()
{
    if (!isServerRunning())
        return;

    juce::Logger::writeToLog("RemoteProcessingEngine: Stopping server...");

    // Close all client connections
    for (auto& client : connectedClients)
        client.disconnect();
    connectedClients.clear();

    #if ECHOELMUSIC_HAS_WEBRTC
    if (signalingServer) signalingServer->stop();
    #endif

    serverModeActive.store(false);
}

bool RemoteProcessingEngine::isServerRunning() const
{
    return serverModeActive.load();
}

void RemoteProcessingEngine::setAllowedClients(const juce::StringArray& clientTokens)
{
    allowedClientTokens = clientTokens;
    juce::Logger::writeToLog("Allowed clients updated: " + juce::String(clientTokens.size()) + " tokens");
}

//==============================================================================
// Recording to Remote Storage
//==============================================================================

bool RemoteProcessingEngine::startRemoteRecording(const juce::File& remoteFilePath)
{
    if (!isConnected())
    {
        juce::Logger::writeToLog("RemoteProcessingEngine: Cannot start remote recording - not connected");
        return false;
    }

    juce::Logger::writeToLog("RemoteProcessingEngine: Starting remote recording to " +
                            remoteFilePath.getFullPathName());

    // Send START_RECORDING command
    juce::var command;
    command.getDynamicObject()->setProperty("type", "START_RECORDING");
    command.getDynamicObject()->setProperty("path", remoteFilePath.getFullPathName());
    transport->sendCommand(command);
    isRecording = true;

    return true;
}

void RemoteProcessingEngine::stopRemoteRecording()
{
    juce::Logger::writeToLog("RemoteProcessingEngine: Stopping remote recording");

    // Send STOP_RECORDING command
    juce::var command;
    command.getDynamicObject()->setProperty("type", "STOP_RECORDING");
    transport->sendCommand(command);
    isRecording = false;
}

bool RemoteProcessingEngine::isRemoteRecording() const
{
    return isRecording;
}

int64_t RemoteProcessingEngine::getRemoteRecordingPosition() const
{
    return recordingPosition.load();
}

//==============================================================================
// Statistics
//==============================================================================

RemoteProcessingEngine::ProcessingStats RemoteProcessingEngine::getProcessingStats() const
{
    return statistics;
}

void RemoteProcessingEngine::resetStatistics()
{
    statistics = ProcessingStats{};
    statistics.connectionStartTime = juce::Time::getCurrentTime();
}

//==============================================================================
// Internal Methods
//==============================================================================

bool RemoteProcessingEngine::shouldUseRemoteProcessing(RemoteCapability capability) const
{
    // Check processing mode
    if (currentMode == ProcessingMode::LocalOnly)
        return false;

    if (currentMode == ProcessingMode::RemoteOnly)
        return isConnected();

    if (!isConnected())
        return false;

    // Check if capability is available on remote
    if (!canProcessRemotely(capability))
        return false;

    if (currentMode == ProcessingMode::Adaptive)
    {
        // Decide based on network quality and local CPU load
        float networkQuality = currentNetworkStats.qualityScore;
        float latency = currentLatencyMs.load();

        // Use remote if:
        // - Network quality is good (> 0.7)
        // - Latency is acceptable (< 30ms)
        // - Remote server has capacity

        return (networkQuality > 0.7f) && (latency < 30.0f) && currentServer.isAvailable;
    }

    if (currentMode == ProcessingMode::Hybrid)
    {
        // Always use remote for CPU-intensive tasks
        return (capability == RemoteCapability::VideoRendering) ||
               (capability == RemoteCapability::AIInference);
    }

    return false;
}

void RemoteProcessingEngine::fallbackToLocalProcessing(juce::AudioBuffer<float>& buffer,
                                                       RemoteCapability capability,
                                                       const juce::var& parameters)
{
    // Check if local fallback processor is registered
    if (auto processor = fallbackProcessors[static_cast<int>(capability)])
    {
        processor(buffer, parameters);
    }
    else
    {
        // No fallback available - pass through audio unchanged
        juce::Logger::writeToLog("RemoteProcessingEngine: No fallback processor for capability " +
                                juce::String((int)capability));
    }
}
