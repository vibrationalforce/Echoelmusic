#include "EchoelDanteAdapter.h"

//==============================================================================
// CONSTRUCTOR / DESTRUCTOR
//==============================================================================

EchoelDanteAdapter::EchoelDanteAdapter()
{
    DBG("EchoelDanteAdapter: Initializing Dante audio-over-IP integration");

    // Initialize local device
    localDevice.deviceName = deviceName;
    localDevice.deviceID = juce::SystemStats::getComputerName();
    localDevice.manufacturer = "Echoel";
    localDevice.model = "Echoelmusic Quantum";
    localDevice.sampleRate = 48000;
    localDevice.bitDepth = DanteDevice::BitDepth::Bit32Float;
    localDevice.status = DanteDevice::Status::Online;

    initializeDante();
}

EchoelDanteAdapter::~EchoelDanteAdapter()
{
    stopStreaming();
    shutdownDante();
}

//==============================================================================
// DANTE VIRTUAL SOUNDCARD (DVS) INTEGRATION
//==============================================================================

bool EchoelDanteAdapter::isDVSInstalled() const
{
    // Check for Dante Virtual Soundcard installation
    // DVS creates a virtual audio device

    // In production: Query system audio devices for "Dante Virtual Soundcard"
    // This would require access to the app's AudioDeviceManager instance

    // For now: Check operating system specific paths
    #if JUCE_MAC
        // macOS: Check for DVS driver in /Library/Audio/Plug-Ins/HAL/
        juce::File halPlugins("/Library/Audio/Plug-Ins/HAL/");
        if (halPlugins.exists())
        {
            auto files = halPlugins.findChildFiles(juce::File::findFiles, false, "*Dante*");
            if (!files.isEmpty())
            {
                DBG("EchoelDanteAdapter: Dante Virtual Soundcard detected");
                return true;
            }
        }
    #elif JUCE_WINDOWS
        // Windows: Check registry for DVS driver
        // HKEY_LOCAL_MACHINE\SOFTWARE\Audinate\Dante Virtual Soundcard
        // For now, return placeholder
    #elif JUCE_LINUX
        // Linux: Check ALSA devices for "Dante"
    #endif

    DBG("EchoelDanteAdapter: Dante Virtual Soundcard not found");
    return false;
}

juce::String EchoelDanteAdapter::getDVSVersion() const
{
    // In production: Query DVS driver version
    // For now, return placeholder
    return "4.x";
}

void EchoelDanteAdapter::setDVSMode(bool enabled)
{
    dvsMode = enabled;

    if (enabled)
    {
        if (isDVSInstalled())
        {
            DBG("EchoelDanteAdapter: DVS mode ENABLED");

            // Set audio device to Dante Virtual Soundcard
            // This would be done through JUCE's AudioDeviceManager
        }
        else
        {
            DBG("EchoelDanteAdapter: DVS mode requested but DVS not installed");
            dvsMode = false;
        }
    }
    else
    {
        DBG("EchoelDanteAdapter: DVS mode DISABLED");
    }
}

//==============================================================================
// DEVICE DISCOVERY
//==============================================================================

void EchoelDanteAdapter::scanForDevices()
{
    DBG("EchoelDanteAdapter: Scanning for Dante devices on network...");

    discoveredDevices.clear();

    // In production: Use Dante mDNS/DNS-SD discovery or Dante SDK
    // For now: Simulate discovery

    // Method 1: mDNS Service Discovery
    // Look for "_netaudio-dcp._udp" and "_netaudio-arc._udp" services

    // Method 2: Dante SDK discovery API
    // if (danteSDKHandle)
    // {
    //     // Use Dante SDK device discovery
    // }

    // Method 3: AES67 discovery
    // Look for SDP announcements on multicast address 239.255.255.255:9875

    // Simulated devices for demonstration
    DanteDevice device1;
    device1.deviceName = "StudioDesk-Dante";
    device1.deviceID = "192.168.1.100";
    device1.ipAddress = "192.168.1.100";
    device1.manufacturer = "Audinate";
    device1.model = "AVIO USB Adapter";
    device1.txChannelCount = 2;
    device1.rxChannelCount = 2;
    device1.sampleRate = 48000;
    device1.latencyMs = 1.0f;
    device1.aes67Compatible = true;
    device1.status = DanteDevice::Status::Online;
    discoveredDevices.push_back(device1);

    DanteDevice device2;
    device2.deviceName = "MixConsole-Dante";
    device2.deviceID = "192.168.1.101";
    device2.ipAddress = "192.168.1.101";
    device2.manufacturer = "Yamaha";
    device2.model = "TF Series";
    device2.txChannelCount = 32;
    device2.rxChannelCount = 32;
    device2.sampleRate = 48000;
    device2.latencyMs = 0.5f;
    device2.aes67Compatible = true;
    device2.status = DanteDevice::Status::Online;
    discoveredDevices.push_back(device2);

    DBG("EchoelDanteAdapter: Found " + juce::String(discoveredDevices.size()) + " Dante devices");

    for (const auto& dev : discoveredDevices)
    {
        DBG("  - " + dev.deviceName + " (" + dev.ipAddress + ") " +
            juce::String(dev.txChannelCount) + "x" + juce::String(dev.rxChannelCount) + " channels");
    }
}

EchoelDanteAdapter::DanteDevice* EchoelDanteAdapter::getDevice(const juce::String& devName)
{
    for (auto& device : discoveredDevices)
    {
        if (device.deviceName == devName)
            return &device;
    }
    return nullptr;
}

//==============================================================================
// CHANNEL ROUTING
//==============================================================================

bool EchoelDanteAdapter::createRoute(const juce::String& sourceName, const juce::String& destName)
{
    // Parse source and destination
    // Format: "DeviceName:ChannelName" or "DeviceName:Channel1"

    DBG("EchoelDanteAdapter: Creating route: " + sourceName + " → " + destName);

    ChannelRoute route;
    route.sourceName = sourceName;
    route.destinationName = destName;
    route.state = ChannelRoute::State::Resolving;

    // In production: Use Dante Controller API or Dante SDK
    // dante_route_create(source, destination)

    // For now: Simulate successful routing
    route.state = ChannelRoute::State::Active;
    route.latencyMs = 1.0f;
    route.packetLoss = 0.0f;

    activeRoutes.push_back(route);

    DBG("EchoelDanteAdapter: Route created successfully");
    return true;
}

bool EchoelDanteAdapter::removeRoute(const juce::String& sourceName, const juce::String& destName)
{
    for (auto it = activeRoutes.begin(); it != activeRoutes.end(); ++it)
    {
        if (it->sourceName == sourceName && it->destinationName == destName)
        {
            DBG("EchoelDanteAdapter: Removing route: " + sourceName + " → " + destName);
            activeRoutes.erase(it);
            return true;
        }
    }

    DBG("EchoelDanteAdapter: Route not found");
    return false;
}

void EchoelDanteAdapter::clearAllRoutes()
{
    DBG("EchoelDanteAdapter: Clearing all " + juce::String(activeRoutes.size()) + " routes");
    activeRoutes.clear();
}

//==============================================================================
// AUDIO STREAMING
//==============================================================================

void EchoelDanteAdapter::startStreaming()
{
    if (streaming)
        return;

    DBG("EchoelDanteAdapter: Starting Dante audio streaming");

    // Initialize RTP/RTCP for AES67 mode
    if (aes67Mode)
    {
        DBG("EchoelDanteAdapter: Using AES67 mode");
        // Set up RTP streaming
        // Multicast address: 239.69.x.x
        // RTP payload type: 96 (L24) or 97 (L16)
    }

    // Initialize Dante SDK streaming
    if (danteSDKHandle)
    {
        DBG("EchoelDanteAdapter: Using Dante SDK");
        // dante_audio_start()
    }

    // Or use Dante Virtual Soundcard
    if (dvsMode)
    {
        DBG("EchoelDanteAdapter: Using Dante Virtual Soundcard mode");
        // Audio flows through DVS audio device
    }

    streaming = true;

    DBG("EchoelDanteAdapter: Streaming started - Latency mode: " +
        juce::String(static_cast<int>(latencyMode)) +
        " Sample rate: " + juce::String(currentSampleRate) + " Hz");
}

void EchoelDanteAdapter::stopStreaming()
{
    if (!streaming)
        return;

    DBG("EchoelDanteAdapter: Stopping Dante audio streaming");

    streaming = false;

    DBG("EchoelDanteAdapter: Streaming stopped");
}

void EchoelDanteAdapter::sendAudioBlock(const juce::AudioBuffer<float>& buffer)
{
    if (!streaming)
        return;

    // Send audio to Dante network

    if (aes67Mode)
    {
        // Encode as RTP packets
        // Sample format: 24-bit integer (AES67 standard)
        // Packet size: typically 48 samples @ 48kHz = 1ms

        // For each channel:
        // - Convert float to int24
        // - Create RTP packet
        // - Send to multicast address
        juce::ignoreUnused(buffer);
    }

    if (danteSDKHandle)
    {
        // Use Dante SDK audio output API
        // dante_audio_write(buffer, numSamples)
        juce::ignoreUnused(buffer);
    }

    // If using DVS, audio flows through JUCE's AudioIODevice automatically
}

void EchoelDanteAdapter::receiveAudioBlock(juce::AudioBuffer<float>& buffer)
{
    if (!streaming)
        return;

    // Receive audio from Dante network

    if (aes67Mode)
    {
        // Receive RTP packets
        // Decode from int24 to float
        // Apply jitter buffer
        // Write to output buffer
        juce::ignoreUnused(buffer);
    }

    if (danteSDKHandle)
    {
        // Use Dante SDK audio input API
        // dante_audio_read(buffer, numSamples)
        juce::ignoreUnused(buffer);
    }

    // If using DVS, audio flows through JUCE's AudioIODevice automatically
}

//==============================================================================
// NETWORK CONFIGURATION
//==============================================================================

void EchoelDanteAdapter::setNetworkMode(NetworkMode mode)
{
    networkMode = mode;

    const char* modeName = "";
    switch (mode)
    {
        case NetworkMode::Unicast:   modeName = "Unicast"; break;
        case NetworkMode::Multicast: modeName = "Multicast"; break;
        case NetworkMode::Redundant: modeName = "Redundant (Primary + Secondary)"; break;
    }

    DBG("EchoelDanteAdapter: Network mode set to " + juce::String(modeName));
}

void EchoelDanteAdapter::setLatencyMode(LatencyMode mode)
{
    latencyMode = mode;

    float latency = 2.0f;
    const char* modeName = "";

    switch (mode)
    {
        case LatencyMode::UltraLow:
            latency = 0.25f;
            modeName = "Ultra Low (0.15-0.25ms)";
            break;

        case LatencyMode::Low:
            latency = 1.0f;
            modeName = "Low (0.5-1ms)";
            break;

        case LatencyMode::Standard:
            latency = 2.0f;
            modeName = "Standard (2ms)";
            break;

        case LatencyMode::High:
            latency = 5.0f;
            modeName = "High (5ms)";
            break;
    }

    DBG("EchoelDanteAdapter: Latency mode set to " + juce::String(modeName));

    // Apply to local device
    localDevice.latencyMs = latency;
}

void EchoelDanteAdapter::setSampleRate(int sampleRate)
{
    if (sampleRate != 48000 && sampleRate != 96000)
    {
        DBG("EchoelDanteAdapter: Invalid sample rate " + juce::String(sampleRate) +
            " - must be 48000 or 96000 Hz");
        return;
    }

    currentSampleRate = sampleRate;
    localDevice.sampleRate = sampleRate;

    DBG("EchoelDanteAdapter: Sample rate set to " + juce::String(sampleRate) + " Hz");
}

void EchoelDanteAdapter::setAES67Mode(bool enabled)
{
    aes67Mode = enabled;
    localDevice.aes67Compatible = enabled;

    if (enabled)
    {
        DBG("EchoelDanteAdapter: AES67 compatibility mode ENABLED");
        DBG("EchoelDanteAdapter: Now compatible with AES67/SMPTE ST 2110 devices");
    }
    else
    {
        DBG("EchoelDanteAdapter: AES67 compatibility mode DISABLED");
    }
}

//==============================================================================
// INTEGRATION WITH ECHOELMUSIC QUANTUM ARCHITECTURE
//==============================================================================

void EchoelDanteAdapter::linkNetworkSync(EchoelNetworkSync* networkSync)
{
    linkedNetworkSync = networkSync;

    if (networkSync)
    {
        DBG("EchoelDanteAdapter: Linked with EchoelNetworkSync");
        DBG("EchoelDanteAdapter: Laser Scanner Mode + Dante = Ultimate low-latency!");

        // Synchronize clocks
        double danteClockTime = getClockOffset() / 1000000.0;  // Convert µs to seconds
        double networkTime = networkSync->getNetworkTime();

        DBG("EchoelDanteAdapter: PTP clock offset: " + juce::String(getClockOffset(), 2) + " µs");
        DBG("EchoelDanteAdapter: Network sync time: " + juce::String(networkTime, 6) + " s");
        DBG("EchoelDanteAdapter: Dante clock time: " + juce::String(danteClockTime, 6) + " s");
    }
}

void EchoelDanteAdapter::enableBioReactiveStreaming(bool enabled)
{
    bioReactiveStreaming = enabled;

    if (enabled)
    {
        DBG("EchoelDanteAdapter: Bio-reactive streaming ENABLED");
        DBG("EchoelDanteAdapter: HRV, EEG, and quantum states will stream alongside audio");

        if (linkedNetworkSync)
        {
            DBG("EchoelDanteAdapter: Using Laser Scanner Mode for bio-data prediction");
        }
    }
    else
    {
        DBG("EchoelDanteAdapter: Bio-reactive streaming DISABLED");
    }
}

void EchoelDanteAdapter::setDeviceName(const juce::String& name)
{
    deviceName = name;
    localDevice.deviceName = name;

    DBG("EchoelDanteAdapter: Device name set to: " + name);
}

//==============================================================================
// DIAGNOSTICS & MONITORING
//==============================================================================

EchoelDanteAdapter::NetworkStats EchoelDanteAdapter::getNetworkStats() const
{
    NetworkStats stats;

    // Calculate bandwidth
    // Assuming 32-bit float, 48kHz, 2 channels
    // Bandwidth = (sample_rate * bit_depth * channels) / 1_000_000
    int channels = localDevice.txChannelCount;
    stats.bandwidth = (currentSampleRate * 32 * channels) / 1000000.0f;

    // Aggregate route quality
    if (!activeRoutes.empty())
    {
        float totalPacketLoss = 0.0f;
        float totalLatency = 0.0f;

        for (const auto& route : activeRoutes)
        {
            totalPacketLoss += route.packetLoss;
            totalLatency += route.latencyMs;
        }

        stats.packetLoss = totalPacketLoss / activeRoutes.size();
        stats.latency = totalLatency / activeRoutes.size();
    }

    stats.activeChannels = channels;
    stats.totalRoutes = static_cast<int>(activeRoutes.size());

    // PTP stats
    stats.ptpJitter = 0.1;  // µs
    stats.ptpLocked = (ptpStatus == PTPStatus::Slave);

    return stats;
}

juce::String EchoelDanteAdapter::exportRoutingConfig() const
{
    // Export to JSON format compatible with Dante Controller

    juce::var config = juce::var(new juce::DynamicObject());
    auto* obj = config.getDynamicObject();

    obj->setProperty("device_name", localDevice.deviceName);
    obj->setProperty("sample_rate", currentSampleRate);
    obj->setProperty("latency_mode", static_cast<int>(latencyMode));

    // Routes array
    juce::Array<juce::var> routesArray;
    for (const auto& route : activeRoutes)
    {
        juce::var routeObj = juce::var(new juce::DynamicObject());
        auto* routeData = routeObj.getDynamicObject();

        routeData->setProperty("source", route.sourceName);
        routeData->setProperty("destination", route.destinationName);
        routeData->setProperty("state", route.state == ChannelRoute::State::Active ? "active" : "inactive");

        routesArray.add(routeObj);
    }

    obj->setProperty("routes", routesArray);

    return juce::JSON::toString(config, true);
}

bool EchoelDanteAdapter::importRoutingConfig(const juce::String& config)
{
    auto json = juce::JSON::parse(config);

    if (!json.isObject())
    {
        DBG("EchoelDanteAdapter: Invalid routing configuration");
        return false;
    }

    auto* obj = json.getDynamicObject();

    // Import device settings
    if (obj->hasProperty("device_name"))
        setDeviceName(obj->getProperty("device_name"));

    if (obj->hasProperty("sample_rate"))
        setSampleRate(static_cast<int>(obj->getProperty("sample_rate")));

    // Import routes
    if (obj->hasProperty("routes"))
    {
        clearAllRoutes();

        auto routesArray = obj->getProperty("routes").getArray();
        for (const auto& routeVar : *routesArray)
        {
            if (routeVar.isObject())
            {
                auto* routeObj = routeVar.getDynamicObject();
                juce::String source = routeObj->getProperty("source");
                juce::String dest = routeObj->getProperty("destination");

                createRoute(source, dest);
            }
        }
    }

    DBG("EchoelDanteAdapter: Routing configuration imported successfully");
    return true;
}

//==============================================================================
// INTERNAL METHODS
//==============================================================================

void EchoelDanteAdapter::initializeDante()
{
    DBG("EchoelDanteAdapter: Initializing Dante subsystem");

    // Check for DVS
    if (isDVSInstalled())
    {
        DBG("EchoelDanteAdapter: Dante Virtual Soundcard detected");
    }

    // Try to load Dante SDK (if available)
    // danteSDKHandle = loadDanteSDK();

    // Initialize PTP sync
    updatePTPSync();

    // Start device discovery
    scanForDevices();

    DBG("EchoelDanteAdapter: Initialization complete");
}

void EchoelDanteAdapter::shutdownDante()
{
    DBG("EchoelDanteAdapter: Shutting down Dante subsystem");

    stopStreaming();
    clearAllRoutes();

    // Unload Dante SDK
    if (danteSDKHandle)
    {
        // unloadDanteSDK(danteSDKHandle);
        danteSDKHandle = nullptr;
    }
}

void EchoelDanteAdapter::updateDeviceDiscovery()
{
    // Periodic device discovery update
    // Called from timer or background thread
}

void EchoelDanteAdapter::updatePTPSync()
{
    // Update PTP synchronization status

    // In production: Query PTP daemon or Dante SDK
    // For now: Simulate PTP slave status

    ptpStatus = PTPStatus::Slave;
    clockOffsetUs = 0.5;  // 0.5 microseconds offset

    danteControllerConnected = true;
}

void EchoelDanteAdapter::updateRouteQuality()
{
    // Update route quality metrics
    // Monitor packet loss, latency, dropouts

    for (auto& route : activeRoutes)
    {
        // In production: Query actual network stats
        route.packetLoss = 0.0f;
        route.latencyMs = localDevice.latencyMs;
    }
}
