#pragma once

#include <JuceHeader.h>
#include <functional>
#include <memory>

/**
 * NDIManager - NewTek NDI (Network Device Interface) Integration
 *
 * NDI is the industry standard for low-latency video over IP.
 * Used by professional video production software:
 * - OBS Studio
 * - vMix
 * - Wirecast
 * - TriCaster
 * - TouchDesigner
 * - Resolume
 *
 * Features:
 * - Send/Receive HD/4K video over network
 * - Ultra-low latency (<1 frame, ~16ms @ 60fps)
 * - Hardware-accelerated encoding/decoding
 * - Auto-discovery of NDI sources
 * - Alpha channel support
 * - Audio embedding
 * - PTZ camera control
 *
 * SDK Download:
 * - https://ndi.tv/sdk/
 * - Free for developers
 * - NDI 5.x (latest)
 *
 * Use Cases:
 * - Stream Echoelmusic visuals to OBS/vMix
 * - Receive camera feeds from NDI cameras
 * - Multi-machine rendering (send video between computers)
 * - Live performance video routing
 */
class NDIManager
{
public:
    //==========================================================================
    // NDI Source Info
    //==========================================================================

    struct NDISource
    {
        juce::String name;              // "LAPTOP-ABC (OBS)"
        juce::String url;               // "192.168.1.100:5960"
        juce::String machineName;       // "LAPTOP-ABC"
        juce::String sourceName;        // "OBS"
        bool isLocal = false;
    };

    //==========================================================================
    // Video Format
    //==========================================================================

    struct VideoFormat
    {
        int width = 1920;
        int height = 1080;
        int framerate = 60;
        bool hasAlpha = false;

        enum class ColorFormat
        {
            RGBA,       // 8-bit per channel
            BGRA,       // 8-bit per channel (Windows native)
            YUV420,     // Compressed (saves bandwidth)
            YUV422      // Higher quality chroma
        };

        ColorFormat colorFormat = ColorFormat::RGBA;
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    NDIManager();
    ~NDIManager();

    //==========================================================================
    // Initialization
    //==========================================================================

    /** Initialize NDI library */
    bool initialize();

    /** Check if NDI is available */
    bool isAvailable() const;

    /** Get NDI version */
    juce::String getVersion() const;

    //==========================================================================
    // Source Discovery
    //==========================================================================

    /** Start discovering NDI sources on network */
    void startDiscovery();

    /** Stop discovery */
    void stopDiscovery();

    /** Get list of discovered sources */
    juce::Array<NDISource> getDiscoveredSources() const;

    /** Callback when sources change */
    std::function<void(const juce::Array<NDISource>&)> onSourcesChanged;

    //==========================================================================
    // Sender (Output)
    //==========================================================================

    /** Create NDI sender */
    bool createSender(const juce::String& name, const VideoFormat& format);

    /** Send video frame */
    bool sendVideoFrame(const juce::Image& frame);

    /** Send audio buffer */
    bool sendAudioBuffer(const juce::AudioBuffer<float>& buffer, int sampleRate);

    /** Close sender */
    void closeSender();

    /** Check if sending */
    bool isSending() const;

    //==========================================================================
    // Receiver (Input)
    //==========================================================================

    /** Connect to NDI source */
    bool connectToSource(const NDISource& source);

    /** Disconnect from source */
    void disconnectSource();

    /** Receive video frame (non-blocking) */
    bool receiveVideoFrame(juce::Image& frame, int timeoutMs = 0);

    /** Receive audio buffer (non-blocking) */
    bool receiveAudioBuffer(juce::AudioBuffer<float>& buffer, int timeoutMs = 0);

    /** Check if receiving */
    bool isReceiving() const;

    //==========================================================================
    // Stats
    //==========================================================================

    struct NetworkStats
    {
        int videoFramesSent = 0;
        int videoFramesReceived = 0;
        int audioFramesSent = 0;
        int audioFramesReceived = 0;

        float currentBitrateM bps = 0.0f;
        float latencyMs = 0.0f;

        bool isConnected = false;
    };

    NetworkStats getStats() const;

private:
    //==========================================================================
    // NDI SDK Integration
    //==========================================================================

    struct NDIImpl;
    std::unique_ptr<NDIImpl> impl;

    std::atomic<bool> initialized { false };
    std::atomic<bool> sending { false };
    std::atomic<bool> receiving { false };

    VideoFormat currentFormat;
    NetworkStats currentStats;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(NDIManager)
};
