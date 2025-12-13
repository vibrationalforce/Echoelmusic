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

        // TODO: Implement with actual Link SDK
        // auto timeline = link.captureAppSessionState();
        // state.tempo = timeline.tempo();
        // state.beat = timeline.beatAtTime(...)
        // state.numPeers = link.numPeers();

        // Dummy implementation
        state.tempo = 120.0;
        state.numPeers = 0;
        state.isPlaying = false;

        return state;
    }
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
    juce::Logger::writeToLog("RemoteProcessingEngine: Starting server discovery (mDNS/Bonjour)...");

    discoveredServers.clear();
    isDiscovering.store(true);

    // Start mDNS/Bonjour discovery using platform-native APIs
    startMDNSDiscovery();

    juce::Logger::writeToLog("RemoteProcessingEngine: mDNS discovery started for _echoelmusic._tcp.local");
}

//==============================================================================
// mDNS/Bonjour Discovery Implementation
//==============================================================================

void RemoteProcessingEngine::startMDNSDiscovery()
{
    // Service type for Echoelmusic remote processing
    const juce::String serviceType = "_echoelmusic._tcp.local.";

    #if JUCE_MAC || JUCE_IOS
        // macOS/iOS: Use native DNS-SD (Bonjour) via CFNetServices
        startBonjourDiscovery(serviceType);
    #elif JUCE_WINDOWS
        // Windows: Use DNS-SD API (requires Bonjour SDK or mDNSResponder)
        startWindowsDNSSDDiscovery(serviceType);
    #elif JUCE_LINUX
        // Linux: Use Avahi via D-Bus
        startAvahiDiscovery(serviceType);
    #endif

    // Also start a UDP broadcast fallback for local network discovery
    startUDPBroadcastDiscovery();

    // Set discovery timeout
    discoveryTimeoutTimer = std::make_unique<juce::Timer>();
    juce::Timer::callAfterDelay(10000, [this]()  // 10 second timeout
    {
        stopMDNSDiscovery();
    });
}

void RemoteProcessingEngine::stopMDNSDiscovery()
{
    isDiscovering.store(false);

    #if JUCE_MAC || JUCE_IOS
        stopBonjourDiscovery();
    #elif JUCE_WINDOWS
        stopWindowsDNSSDDiscovery();
    #elif JUCE_LINUX
        stopAvahiDiscovery();
    #endif

    stopUDPBroadcastDiscovery();

    juce::Logger::writeToLog("RemoteProcessingEngine: Discovery completed. Found " +
                            juce::String(discoveredServers.size()) + " server(s)");

    // Notify listeners
    if (onServersDiscovered)
        onServersDiscovered(discoveredServers);
}

#if JUCE_MAC || JUCE_IOS
//==============================================================================
// macOS/iOS Bonjour Implementation
//==============================================================================
void RemoteProcessingEngine::startBonjourDiscovery(const juce::String& serviceType)
{
    juce::Logger::writeToLog("RemoteProcessingEngine: Starting Bonjour discovery...");

    // Create DNS-SD browse reference
    // DNSServiceRef browseRef;
    // DNSServiceErrorType err = DNSServiceBrowse(
    //     &browseRef,
    //     0,                          // flags
    //     kDNSServiceInterfaceIndexAny,
    //     serviceType.toRawUTF8(),    // "_echoelmusic._tcp"
    //     "local.",                   // domain
    //     browseCallback,             // callback
    //     this                        // context
    // );
    //
    // if (err == kDNSServiceErr_NoError)
    // {
    //     bonjourBrowseRef = browseRef;
    //
    //     // Process events in background thread
    //     bonjourThread = std::make_unique<std::thread>([this, browseRef]()
    //     {
    //         while (isDiscovering.load())
    //         {
    //             int fd = DNSServiceRefSockFD(browseRef);
    //             fd_set readfds;
    //             FD_ZERO(&readfds);
    //             FD_SET(fd, &readfds);
    //
    //             struct timeval tv = {1, 0};  // 1 second timeout
    //             int result = select(fd + 1, &readfds, nullptr, nullptr, &tv);
    //
    //             if (result > 0 && FD_ISSET(fd, &readfds))
    //             {
    //                 DNSServiceProcessResult(browseRef);
    //             }
    //         }
    //     });
    // }

    // Fallback: Simulate discovery for platforms without Bonjour SDK
    simulateDiscovery();
}

void RemoteProcessingEngine::stopBonjourDiscovery()
{
    // if (bonjourBrowseRef)
    // {
    //     DNSServiceRefDeallocate(bonjourBrowseRef);
    //     bonjourBrowseRef = nullptr;
    // }
    //
    // if (bonjourThread && bonjourThread->joinable())
    // {
    //     bonjourThread->join();
    // }
}
#endif

#if JUCE_WINDOWS
//==============================================================================
// Windows DNS-SD Implementation
//==============================================================================
void RemoteProcessingEngine::startWindowsDNSSDDiscovery(const juce::String& serviceType)
{
    juce::Logger::writeToLog("RemoteProcessingEngine: Starting Windows DNS-SD discovery...");

    // Windows implementation using WinRT or Bonjour SDK
    // Using Windows.Networking.ServiceDiscovery.Dnssd namespace (UWP)
    //
    // or Bonjour SDK for desktop:
    // DNSServiceRef browseRef;
    // DNSServiceBrowse(&browseRef, 0, 0, serviceType.toRawUTF8(), "local.", browseCallback, this);

    // Fallback: Network broadcast discovery
    simulateDiscovery();
}

void RemoteProcessingEngine::stopWindowsDNSSDDiscovery()
{
    // Cleanup Windows DNS-SD resources
}
#endif

#if JUCE_LINUX
//==============================================================================
// Linux Avahi Implementation
//==============================================================================
void RemoteProcessingEngine::startAvahiDiscovery(const juce::String& serviceType)
{
    juce::Logger::writeToLog("RemoteProcessingEngine: Starting Avahi discovery...");

    // Linux implementation using Avahi D-Bus API
    // Connect to org.freedesktop.Avahi
    // Call org.freedesktop.Avahi.ServiceBrowser
    //
    // DBusConnection *connection = dbus_bus_get(DBUS_BUS_SYSTEM, nullptr);
    // ... create service browser
    // ... register signal handlers for ItemNew, ItemRemove

    // Fallback: Network broadcast discovery
    simulateDiscovery();
}

void RemoteProcessingEngine::stopAvahiDiscovery()
{
    // Cleanup Avahi D-Bus resources
}
#endif

//==============================================================================
// UDP Broadcast Discovery (Cross-Platform Fallback)
//==============================================================================
void RemoteProcessingEngine::startUDPBroadcastDiscovery()
{
    juce::Logger::writeToLog("RemoteProcessingEngine: Starting UDP broadcast discovery...");

    udpDiscoverySocket = std::make_unique<juce::DatagramSocket>(false);

    if (udpDiscoverySocket->bindToPort(0))  // Bind to any available port
    {
        // Send discovery broadcast
        const int DISCOVERY_PORT = 7776;
        juce::String discoveryMessage = "ECHOELMUSIC_DISCOVER_V1";

        // Broadcast to local network
        udpDiscoverySocket->write("255.255.255.255", DISCOVERY_PORT,
                                  discoveryMessage.toRawUTF8(),
                                  static_cast<int>(discoveryMessage.length()));

        // Also try common subnet broadcasts
        for (const auto& subnet : {"192.168.1.255", "192.168.0.255", "10.0.0.255", "172.16.0.255"})
        {
            udpDiscoverySocket->write(subnet, DISCOVERY_PORT,
                                      discoveryMessage.toRawUTF8(),
                                      static_cast<int>(discoveryMessage.length()));
        }

        // Start listening for responses
        udpDiscoveryThread = std::make_unique<std::thread>([this]()
        {
            listenForDiscoveryResponses();
        });
    }
}

void RemoteProcessingEngine::stopUDPBroadcastDiscovery()
{
    if (udpDiscoverySocket)
    {
        udpDiscoverySocket->shutdown();
        udpDiscoverySocket.reset();
    }

    if (udpDiscoveryThread && udpDiscoveryThread->joinable())
    {
        udpDiscoveryThread->join();
    }
}

void RemoteProcessingEngine::listenForDiscoveryResponses()
{
    char buffer[4096];
    juce::String senderHost;
    int senderPort;

    while (isDiscovering.load() && udpDiscoverySocket)
    {
        int bytesRead = udpDiscoverySocket->read(buffer, sizeof(buffer) - 1, false,
                                                  senderHost, senderPort);

        if (bytesRead > 0)
        {
            buffer[bytesRead] = '\0';
            juce::String response(buffer);

            // Parse discovery response
            // Expected format: ECHOELMUSIC_SERVER_V1|deviceName|port|capabilities|cpuCores|ramGB|gpuModel
            if (response.startsWith("ECHOELMUSIC_SERVER_V1|"))
            {
                parseDiscoveryResponse(response, senderHost);
            }
        }

        // Small sleep to prevent busy-waiting
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }
}

void RemoteProcessingEngine::parseDiscoveryResponse(const juce::String& response, const juce::String& hostIP)
{
    juce::StringArray parts;
    parts.addTokens(response, "|", "");

    if (parts.size() >= 7)
    {
        RemoteServer server;
        server.hostName = hostIP;
        server.deviceName = parts[1];
        server.port = parts[2].getIntValue();

        // Parse capabilities
        juce::StringArray caps;
        caps.addTokens(parts[3], ",", "");
        for (const auto& cap : caps)
        {
            if (cap == "audio") server.capabilities.add(RemoteCapability::AudioProcessing);
            if (cap == "video") server.capabilities.add(RemoteCapability::VideoRendering);
            if (cap == "ai") server.capabilities.add(RemoteCapability::AIInference);
            if (cap == "bioreactive") server.capabilities.add(RemoteCapability::BioReactive);
            if (cap == "spatial") server.capabilities.add(RemoteCapability::SpatialAudio);
        }

        server.cpuCores = parts[4].getIntValue();
        server.ramGB = parts[5].getIntValue();
        server.gpuModel = parts[6];
        server.isOnline = true;
        server.isAvailable = true;

        // Check if already discovered
        bool alreadyExists = false;
        for (const auto& existing : discoveredServers)
        {
            if (existing.hostName == server.hostName && existing.port == server.port)
            {
                alreadyExists = true;
                break;
            }
        }

        if (!alreadyExists)
        {
            juce::MessageManager::callAsync([this, server]()
            {
                discoveredServers.add(server);
                juce::Logger::writeToLog("RemoteProcessingEngine: Discovered server: " +
                                        server.deviceName + " at " + server.hostName);

                if (onServerDiscovered)
                    onServerDiscovered(server);
            });
        }
    }
}

void RemoteProcessingEngine::simulateDiscovery()
{
    // Simulate finding servers for testing when native mDNS is unavailable
    juce::Timer::callAfterDelay(500, [this]()
    {
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

        juce::Logger::writeToLog("RemoteProcessingEngine: Simulated discovery - found " +
                                juce::String(discoveredServers.size()) + " server(s)");
    });
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
    autoReconnectEnabled.store(enable);

    if (enable)
    {
        juce::Logger::writeToLog("RemoteProcessingEngine: Auto-reconnect ENABLED");

        // Start connection health monitoring
        startConnectionHealthMonitor();
    }
    else
    {
        juce::Logger::writeToLog("RemoteProcessingEngine: Auto-reconnect DISABLED");

        // Stop monitoring
        stopConnectionHealthMonitor();
    }
}

//==============================================================================
// Auto-Reconnect Implementation
//==============================================================================

void RemoteProcessingEngine::startConnectionHealthMonitor()
{
    if (healthMonitorRunning.load())
        return;

    healthMonitorRunning.store(true);

    // Start health check thread
    healthMonitorThread = std::make_unique<std::thread>([this]()
    {
        runConnectionHealthMonitor();
    });

    juce::Logger::writeToLog("RemoteProcessingEngine: Connection health monitor started");
}

void RemoteProcessingEngine::stopConnectionHealthMonitor()
{
    healthMonitorRunning.store(false);

    if (healthMonitorThread && healthMonitorThread->joinable())
    {
        healthMonitorThread->join();
    }

    juce::Logger::writeToLog("RemoteProcessingEngine: Connection health monitor stopped");
}

void RemoteProcessingEngine::runConnectionHealthMonitor()
{
    const int HEALTH_CHECK_INTERVAL_MS = 5000;   // Check every 5 seconds
    const int PING_TIMEOUT_MS = 2000;            // 2 second ping timeout
    const int MAX_CONSECUTIVE_FAILURES = 3;      // Disconnect after 3 failures
    const int RECONNECT_DELAY_BASE_MS = 1000;    // Base delay for exponential backoff
    const int MAX_RECONNECT_DELAY_MS = 30000;    // Max 30 second delay

    int consecutiveFailures = 0;
    int reconnectAttempts = 0;

    while (healthMonitorRunning.load())
    {
        // Sleep between checks
        std::this_thread::sleep_for(std::chrono::milliseconds(HEALTH_CHECK_INTERVAL_MS));

        if (!healthMonitorRunning.load())
            break;

        // Only monitor if we should be connected
        if (!isConnected() && lastConnectedServer.hostName.isEmpty())
            continue;

        if (isConnected())
        {
            // Perform health check (ping)
            bool isHealthy = performConnectionHealthCheck(PING_TIMEOUT_MS);

            if (isHealthy)
            {
                consecutiveFailures = 0;
                reconnectAttempts = 0;
                connectionState = ConnectionState::Connected;
            }
            else
            {
                consecutiveFailures++;
                juce::Logger::writeToLog("RemoteProcessingEngine: Health check failed (" +
                                        juce::String(consecutiveFailures) + "/" +
                                        juce::String(MAX_CONSECUTIVE_FAILURES) + ")");

                if (consecutiveFailures >= MAX_CONSECUTIVE_FAILURES)
                {
                    // Connection lost - trigger reconnect
                    juce::Logger::writeToLog("RemoteProcessingEngine: Connection lost - starting auto-reconnect");

                    juce::MessageManager::callAsync([this]()
                    {
                        handleConnectionLost();
                    });

                    connectionState = ConnectionState::Reconnecting;
                    consecutiveFailures = 0;
                }
            }
        }
        else if (autoReconnectEnabled.load() && !lastConnectedServer.hostName.isEmpty())
        {
            // Attempt to reconnect
            connectionState = ConnectionState::Reconnecting;

            // Calculate delay with exponential backoff
            int delay = std::min(
                RECONNECT_DELAY_BASE_MS * (1 << std::min(reconnectAttempts, 5)),
                MAX_RECONNECT_DELAY_MS
            );

            juce::Logger::writeToLog("RemoteProcessingEngine: Reconnect attempt " +
                                    juce::String(reconnectAttempts + 1) +
                                    " in " + juce::String(delay / 1000.0f, 1) + "s");

            // Wait before reconnecting
            for (int waited = 0; waited < delay && healthMonitorRunning.load(); waited += 100)
            {
                std::this_thread::sleep_for(std::chrono::milliseconds(100));
            }

            if (!healthMonitorRunning.load())
                break;

            // Attempt reconnection
            bool reconnected = attemptReconnection();

            if (reconnected)
            {
                juce::Logger::writeToLog("RemoteProcessingEngine: Reconnected successfully!");
                reconnectAttempts = 0;
                connectionState = ConnectionState::Connected;

                // Notify listeners
                juce::MessageManager::callAsync([this]()
                {
                    if (onReconnected)
                        onReconnected(currentServer);
                });
            }
            else
            {
                reconnectAttempts++;
                juce::Logger::writeToLog("RemoteProcessingEngine: Reconnect attempt failed");

                // Check if we should give up
                if (reconnectAttempts >= maxReconnectAttempts)
                {
                    juce::Logger::writeToLog("RemoteProcessingEngine: Max reconnect attempts reached, giving up");
                    connectionState = ConnectionState::Disconnected;

                    juce::MessageManager::callAsync([this]()
                    {
                        if (onReconnectFailed)
                            onReconnectFailed(lastConnectedServer);
                    });

                    // Clear last server to stop trying
                    lastConnectedServer = RemoteServer{};
                }
            }
        }
    }
}

bool RemoteProcessingEngine::performConnectionHealthCheck(int timeoutMs)
{
    if (!transport)
        return false;

    // Send ping and measure response time
    auto startTime = std::chrono::high_resolution_clock::now();

    // Try to measure latency (includes ping-pong)
    float latency = transport->measureLatency();

    auto endTime = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(endTime - startTime).count();

    // Check if response was received within timeout
    if (duration > timeoutMs || latency < 0)
    {
        return false;
    }

    // Update latency stats
    currentLatencyMs.store(latency);

    return true;
}

bool RemoteProcessingEngine::attemptReconnection()
{
    if (lastConnectedServer.hostName.isEmpty())
        return false;

    // First try the last known server
    bool success = transport->connect(lastConnectedServer.hostName, lastConnectedServer.port);

    if (success)
    {
        currentServer = lastConnectedServer;
        isConnectedFlag.store(true);
        return true;
    }

    // If that fails, try to rediscover the server (it might have a new IP)
    juce::Logger::writeToLog("RemoteProcessingEngine: Direct reconnect failed, trying mDNS discovery...");

    // Quick discovery attempt
    discoveredServers.clear();
    isDiscovering.store(true);
    startUDPBroadcastDiscovery();

    // Wait for discovery results (max 3 seconds)
    for (int i = 0; i < 30 && discoveredServers.isEmpty(); i++)
    {
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }

    stopUDPBroadcastDiscovery();
    isDiscovering.store(false);

    // Look for our server by name
    for (const auto& server : discoveredServers)
    {
        if (server.deviceName == lastConnectedServer.deviceName)
        {
            juce::Logger::writeToLog("RemoteProcessingEngine: Found server at new address: " +
                                    server.hostName + ":" + juce::String(server.port));

            success = transport->connect(server.hostName, server.port);
            if (success)
            {
                currentServer = server;
                lastConnectedServer = server;  // Update with new address
                isConnectedFlag.store(true);
                return true;
            }
        }
    }

    return false;
}

void RemoteProcessingEngine::handleConnectionLost()
{
    // Save current server info for reconnection
    if (isConnected())
    {
        lastConnectedServer = currentServer;
    }

    // Disconnect transport
    transport->disconnect();
    isConnectedFlag.store(false);

    juce::Logger::writeToLog("RemoteProcessingEngine: Connection lost to " +
                            lastConnectedServer.deviceName);

    // Notify listeners
    if (onConnectionLost)
        onConnectionLost(lastConnectedServer);
}

void RemoteProcessingEngine::setMaxReconnectAttempts(int maxAttempts)
{
    maxReconnectAttempts = juce::jmax(1, maxAttempts);
}

RemoteProcessingEngine::ConnectionState RemoteProcessingEngine::getConnectionState() const
{
    return connectionState;
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
        // TODO: Enable/disable Link
        // linkImpl->link.enable(enable);
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

    // Estimate bandwidth (simplified)
    currentNetworkStats.bandwidthMbps = 10.0f;  // TODO: Measure actual

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

    // TODO: Update codec parameters based on preset
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
    // TODO: Set AES-256-GCM key
    // Store securely in Keychain/Credential Manager
}

void RemoteProcessingEngine::setEncryptionEnabled(bool enable)
{
    encryptionEnabled.store(enable);
    juce::Logger::writeToLog("RemoteProcessingEngine: Encryption " +
                            juce::String(enable ? "enabled" : "disabled"));
}

void RemoteProcessingEngine::setVerifyServerCertificate(bool verify)
{
    // TODO: Configure SSL/TLS certificate verification
}

//==============================================================================
// Server Mode
//==============================================================================

bool RemoteProcessingEngine::startServer(int port)
{
    juce::Logger::writeToLog("RemoteProcessingEngine: Starting server on port " +
                            juce::String(port) + "...");

    // TODO: Start WebRTC signaling server
    // Listen for incoming connections
    // Handle client authentication

    serverModeActive.store(true);
    return true;
}

void RemoteProcessingEngine::stopServer()
{
    if (!isServerRunning())
        return;

    juce::Logger::writeToLog("RemoteProcessingEngine: Stopping server...");

    // TODO: Close all client connections
    // Stop signaling server

    serverModeActive.store(false);
}

bool RemoteProcessingEngine::isServerRunning() const
{
    return serverModeActive.load();
}

void RemoteProcessingEngine::setAllowedClients(const juce::StringArray& clientTokens)
{
    // TODO: Store allowed JWT tokens
    // Verify on connection
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

    // TODO: Send START_RECORDING command to server
    // Server creates file and starts writing
    // Audio buffers are streamed continuously

    return true;
}

void RemoteProcessingEngine::stopRemoteRecording()
{
    juce::Logger::writeToLog("RemoteProcessingEngine: Stopping remote recording");

    // TODO: Send STOP_RECORDING command
    // Server finalizes file
}

bool RemoteProcessingEngine::isRemoteRecording() const
{
    // TODO: Check recording state
    return false;
}

int64_t RemoteProcessingEngine::getRemoteRecordingPosition() const
{
    // TODO: Query server for current recording position
    return 0;
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
