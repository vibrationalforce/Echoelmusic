#pragma once

#include <JuceHeader.h>

#if JUCE_MAC

#include <memory>
#include <functional>

/**
 * SyphonManager - macOS Syphon Video Sharing
 *
 * Syphon is the standard for real-time video sharing on macOS.
 * Zero-copy GPU texture sharing between applications.
 *
 * Used by:
 * - Resolume
 * - VDMX
 * - MadMapper
 * - TouchDesigner
 * - Max/MSP/Jitter
 * - Quartz Composer
 * - Unity
 * - Unreal Engine
 *
 * Features:
 * - Zero-copy OpenGL/Metal texture sharing
 * - ~1ms latency (same machine)
 * - Auto-discovery of Syphon servers
 * - Alpha channel support
 * - Works with Metal/OpenGL
 *
 * SDK:
 * - https://github.com/Syphon/Syphon-Framework
 * - Free, open-source
 * - Objective-C++ API
 *
 * Use Cases:
 * - Send Echoelmusic visuals to VJ software
 * - Receive video from other apps (cameras, generative art)
 * - Multi-app visual pipelines
 * - Live performance video routing
 */
class SyphonManager
{
public:
    //==========================================================================
    // Syphon Server Info
    //==========================================================================

    struct SyphonServer
    {
        juce::String name;          // "Echoelmusic Output"
        juce::String appName;       // "Echoelmusic"
        juce::String uuid;          // Unique ID
        bool isLocal = true;        // Always true (Syphon is local only)
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    SyphonManager();
    ~SyphonManager();

    //==========================================================================
    // Initialization
    //==========================================================================

    /** Check if Syphon is available */
    bool isAvailable() const;

    //==========================================================================
    // Server Discovery
    //==========================================================================

    /** Start discovering Syphon servers */
    void startDiscovery();

    /** Stop discovery */
    void stopDiscovery();

    /** Get list of available servers */
    juce::Array<SyphonServer> getAvailableServers() const;

    /** Callback when servers change */
    std::function<void(const juce::Array<SyphonServer>&)> onServersChanged;

    //==========================================================================
    // Sender (Output)
    //==========================================================================

    /** Create Syphon server (publisher) */
    bool createServer(const juce::String& name);

    /** Publish OpenGL texture */
    bool publishTexture(unsigned int textureID, int width, int height);

    /** Publish Metal texture */
    bool publishMetalTexture(void* metalTexture, int width, int height);

    /** Publish juce::Image (will be uploaded to GPU) */
    bool publishImage(const juce::Image& image);

    /** Close server */
    void closeServer();

    /** Check if publishing */
    bool isPublishing() const;

    //==========================================================================
    // Receiver (Input)
    //==========================================================================

    /** Connect to Syphon server */
    bool connectToServer(const SyphonServer& server);

    /** Disconnect */
    void disconnectServer();

    /** Get latest frame as OpenGL texture */
    unsigned int receiveTexture(int& width, int& height);

    /** Get latest frame as juce::Image */
    bool receiveImage(juce::Image& image);

    /** Check if receiving */
    bool isReceiving() const;

    /** Check if new frame is available */
    bool hasNewFrame() const;

    //==========================================================================
    // Stats
    //==========================================================================

    struct Stats
    {
        int framesSent = 0;
        int framesReceived = 0;
        bool isConnected = false;
    };

    Stats getStats() const;

private:
    //==========================================================================
    // Syphon Implementation (Objective-C++)
    //==========================================================================

    struct SyphonImpl;
    std::unique_ptr<SyphonImpl> impl;

    std::atomic<bool> publishing { false };
    std::atomic<bool> receiving { false };

    Stats currentStats;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SyphonManager)
};

#endif // JUCE_MAC
