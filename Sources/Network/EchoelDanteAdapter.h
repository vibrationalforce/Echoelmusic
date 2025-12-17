#pragma once

#include <JuceHeader.h>
#include "../Quantum/EchoelNetworkSync.h"

/**
 * EchoelDanteAdapter - Professional Dante Audio-over-IP Integration
 *
 * Dante by Audinate - Industry-standard professional audio networking
 *
 * FEATURES:
 * - Ultra-low latency: <1ms on local network
 * - Multi-channel: Up to 512x512 channels
 * - Sample rates: 48kHz, 96kHz (AES67 compatible)
 * - Bit depth: 24-bit, 32-bit float
 * - Automatic device discovery
 * - Plug-and-play operation
 * - AES67 interoperability
 * - Redundant audio paths
 * - Sample-accurate synchronization
 *
 * REQUIREMENTS:
 * - Dante Virtual Soundcard (DVS) OR
 * - Dante-enabled hardware interface OR
 * - Dante SDK (commercial license required)
 *
 * COMPATIBILITY:
 * - Dante Controller
 * - Dante Domain Manager
 * - AES67 devices
 * - SMPTE ST 2110
 *
 * PROFESSIONAL ENVIRONMENTS:
 * - Recording studios
 * - Live sound reinforcement
 * - Broadcast facilities
 * - Post-production
 * - Immersive audio installations
 * - Multi-room systems
 *
 * INTEGRATION WITH ECHOELMUSIC:
 * - Bio-reactive audio streaming
 * - Quantum state synchronization
 * - Global collaboration (<20ms with Laser Scanner Mode)
 * - Network-distributed DSP processing
 */

class EchoelDanteAdapter
{
public:
    //==========================================================================
    // DANTE DEVICE CONFIGURATION
    //==========================================================================

    struct DanteDevice
    {
        juce::String deviceName;
        juce::String deviceID;
        juce::String ipAddress;
        juce::String manufacturer;
        juce::String model;

        int txChannelCount = 0;      // Transmit channels
        int rxChannelCount = 0;      // Receive channels

        enum class Status
        {
            Online,
            Offline,
            Warning,
            Error
        };
        Status status = Status::Offline;

        // Sample rate (Hz)
        int sampleRate = 48000;

        // Bit depth
        enum class BitDepth
        {
            Bit24,              // Standard Dante
            Bit32Float          // High-precision
        };
        BitDepth bitDepth = BitDepth::Bit24;

        // Latency
        float latencyMs = 1.0f;

        // AES67 compatibility
        bool aes67Compatible = false;

        // Dante firmware version
        juce::String firmwareVersion;
    };

    //==========================================================================
    // CHANNEL ROUTING
    //==========================================================================

    struct ChannelRoute
    {
        juce::String sourceName;        // "Device1:Output1"
        juce::String destinationName;   // "Device2:Input1"

        int sourceChannel = 0;
        int destChannel = 0;

        enum class State
        {
            Active,
            Inactive,
            Resolving,
            Error
        };
        State state = State::Inactive;

        // Quality metrics
        float packetLoss = 0.0f;       // 0.0-1.0
        float latencyMs = 1.0f;
        int dropouts = 0;
    };

    //==========================================================================
    // DANTE NETWORK CONFIGURATION
    //==========================================================================

    enum class NetworkMode
    {
        Unicast,           // Point-to-point
        Multicast,         // One-to-many
        Redundant          // Dual network paths (Primary + Secondary)
    };

    enum class LatencyMode
    {
        UltraLow,          // 0.15ms - 0.25ms (local network)
        Low,               // 0.5ms - 1ms
        Standard,          // 2ms (default)
        High               // 5ms (WAN/internet)
    };

    //==========================================================================
    // CONSTRUCTOR / DESTRUCTOR
    //==========================================================================

    EchoelDanteAdapter();
    ~EchoelDanteAdapter();

    //==========================================================================
    // DANTE VIRTUAL SOUNDCARD (DVS) INTEGRATION
    //==========================================================================

    /**
     * Check if Dante Virtual Soundcard is installed
     */
    bool isDVSInstalled() const;

    /**
     * Get DVS version
     */
    juce::String getDVSVersion() const;

    /**
     * Enable/disable Dante Virtual Soundcard mode
     */
    void setDVSMode(bool enabled);
    bool isDVSMode() const { return dvsMode; }

    //==========================================================================
    // DEVICE DISCOVERY
    //==========================================================================

    /**
     * Scan network for Dante devices
     */
    void scanForDevices();

    /**
     * Get list of discovered Dante devices
     */
    std::vector<DanteDevice> getAvailableDevices() const { return discoveredDevices; }

    /**
     * Get device by name
     */
    DanteDevice* getDevice(const juce::String& deviceName);

    /**
     * Get local device info (this device)
     */
    DanteDevice getLocalDevice() const { return localDevice; }

    //==========================================================================
    // CHANNEL ROUTING
    //==========================================================================

    /**
     * Create audio route
     * @param sourceName "DeviceName:ChannelName" or "DeviceName:Channel1"
     * @param destName "DeviceName:ChannelName"
     */
    bool createRoute(const juce::String& sourceName, const juce::String& destName);

    /**
     * Remove audio route
     */
    bool removeRoute(const juce::String& sourceName, const juce::String& destName);

    /**
     * Get all active routes
     */
    std::vector<ChannelRoute> getActiveRoutes() const { return activeRoutes; }

    /**
     * Clear all routes
     */
    void clearAllRoutes();

    //==========================================================================
    // AUDIO STREAMING
    //==========================================================================

    /**
     * Start Dante audio streaming
     */
    void startStreaming();

    /**
     * Stop Dante audio streaming
     */
    void stopStreaming();

    /**
     * Is currently streaming
     */
    bool isStreaming() const { return streaming; }

    /**
     * Send audio to Dante network
     */
    void sendAudioBlock(const juce::AudioBuffer<float>& buffer);

    /**
     * Receive audio from Dante network
     */
    void receiveAudioBlock(juce::AudioBuffer<float>& buffer);

    //==========================================================================
    // NETWORK CONFIGURATION
    //==========================================================================

    /**
     * Set network mode
     */
    void setNetworkMode(NetworkMode mode);
    NetworkMode getNetworkMode() const { return networkMode; }

    /**
     * Set latency mode
     */
    void setLatencyMode(LatencyMode mode);
    LatencyMode getLatencyMode() const { return latencyMode; }

    /**
     * Set sample rate (48000 or 96000 Hz)
     */
    void setSampleRate(int sampleRate);
    int getSampleRate() const { return currentSampleRate; }

    /**
     * Enable AES67 compatibility mode
     */
    void setAES67Mode(bool enabled);
    bool isAES67Mode() const { return aes67Mode; }

    //==========================================================================
    // SYNCHRONIZATION
    //==========================================================================

    /**
     * Get PTP (Precision Time Protocol) sync status
     */
    enum class PTPStatus
    {
        Master,            // This device is PTP master
        Slave,             // Synced to master
        Listening,         // Discovering master
        Error
    };
    PTPStatus getPTPStatus() const { return ptpStatus; }

    /**
     * Get clock offset from PTP master (microseconds)
     */
    double getClockOffset() const { return clockOffsetUs; }

    //==========================================================================
    // INTEGRATION WITH ECHOELMUSIC QUANTUM ARCHITECTURE
    //==========================================================================

    /**
     * Link with EchoelNetworkSync for bio-reactive streaming
     */
    void linkNetworkSync(EchoelNetworkSync* networkSync);

    /**
     * Enable bio-reactive Dante streaming
     * - Routes bio-data (HRV, EEG) alongside audio
     * - Synchronizes quantum states across Dante network
     */
    void enableBioReactiveStreaming(bool enabled);
    bool isBioReactiveStreamingEnabled() const { return bioReactiveStreaming; }

    /**
     * Set this device's Dante device name
     */
    void setDeviceName(const juce::String& name);
    juce::String getDeviceName() const { return deviceName; }

    //==========================================================================
    // DIAGNOSTICS & MONITORING
    //==========================================================================

    struct NetworkStats
    {
        float bandwidth = 0.0f;        // Mbps
        float packetLoss = 0.0f;       // 0.0-1.0
        float latency = 1.0f;          // ms
        int activeChannels = 0;
        int totalRoutes = 0;

        // Clock sync quality
        double ptpJitter = 0.0;        // microseconds
        bool ptpLocked = false;
    };

    NetworkStats getNetworkStats() const;

    /**
     * Get Dante Controller API status
     */
    bool isDanteControllerConnected() const { return danteControllerConnected; }

    /**
     * Export routing configuration
     */
    juce::String exportRoutingConfig() const;

    /**
     * Import routing configuration
     */
    bool importRoutingConfig(const juce::String& config);

private:
    //==========================================================================
    // INTERNAL STATE
    //==========================================================================

    bool dvsMode = false;
    bool streaming = false;
    bool aes67Mode = false;
    bool bioReactiveStreaming = false;
    bool danteControllerConnected = false;

    juce::String deviceName = "Echoelmusic";

    NetworkMode networkMode = NetworkMode::Unicast;
    LatencyMode latencyMode = LatencyMode::Standard;

    int currentSampleRate = 48000;

    PTPStatus ptpStatus = PTPStatus::Listening;
    double clockOffsetUs = 0.0;

    // Discovered devices
    std::vector<DanteDevice> discoveredDevices;
    DanteDevice localDevice;

    // Active routes
    std::vector<ChannelRoute> activeRoutes;

    // Integration
    EchoelNetworkSync* linkedNetworkSync = nullptr;

    //==========================================================================
    // INTERNAL METHODS
    //==========================================================================

    void initializeDante();
    void shutdownDante();

    void updateDeviceDiscovery();
    void updatePTPSync();
    void updateRouteQuality();

    // Dante SDK interface (requires commercial license)
    void* danteSDKHandle = nullptr;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(EchoelDanteAdapter)
};

/**
 * DANTE INTEGRATION NOTES:
 *
 * OPTION 1: Dante Virtual Soundcard (DVS)
 * - Consumer/prosumer solution
 * - $30/year subscription or $300 lifetime
 * - Creates virtual audio device
 * - Use JUCE's AudioDeviceManager to access DVS
 * - No SDK required
 *
 * OPTION 2: Dante SDK
 * - Professional integration
 * - Commercial license required (contact Audinate)
 * - Full programmatic control
 * - Device discovery, routing, control
 * - Best for embedded systems
 *
 * OPTION 3: AES67 Mode
 * - Open standard (royalty-free)
 * - Interoperable with Dante (AES67 mode)
 * - Can be implemented without license
 * - Limited features vs. full Dante
 *
 * RECOMMENDED APPROACH FOR ECHOELMUSIC:
 * 1. Start with DVS support (accessible to all users)
 * 2. Add AES67 implementation (open-source, no license)
 * 3. Offer Dante SDK integration as premium feature
 *
 * IMPLEMENTATION STRATEGY:
 * - Use JUCE AudioDeviceManager for DVS
 * - Implement AES67 using RTP/RTCP
 * - Optionally load Dante SDK dynamically
 */
