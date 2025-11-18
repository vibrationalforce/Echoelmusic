#pragma once

#include <JuceHeader.h>
#include <memory>
#include <functional>
#include <atomic>

/**
 * WebRTCTransport - Ultra-Low-Latency P2P Audio/Video Streaming
 *
 * Uses WebRTC for real-time peer-to-peer communication:
 * - Audio streaming via Opus codec (<10ms latency)
 * - Video streaming via VP8/VP9/H.264
 * - Data channels for control messages
 * - ICE/STUN/TURN for NAT traversal
 * - End-to-end encryption (DTLS-SRTP)
 *
 * Target Latency:
 * - LAN: <5ms (ideal)
 * - WiFi 6: <10ms (good)
 * - Internet: <50ms (acceptable)
 * - 5G: <30ms (mobile)
 *
 * Integration:
 * - Works with libdatachannel (C++ WebRTC library)
 * - Alternative: Google's WebRTC native library
 * - Alternative: Pion WebRTC (Go, via CGO)
 *
 * Dependencies:
 * - libdatachannel: https://github.com/paullouisageneau/libdatachannel
 * - libopus: https://opus-codec.org/
 */
class WebRTCTransport
{
public:
    //==========================================================================
    // Connection State
    //==========================================================================

    enum class ConnectionState
    {
        Disconnected,
        Connecting,
        Connected,
        Reconnecting,
        Failed,
        Closed
    };

    //==========================================================================
    // ICE Configuration
    //==========================================================================

    struct ICEServer
    {
        juce::String url;           // stun:stun.l.google.com:19302
        juce::String username;      // For TURN servers
        juce::String credential;    // For TURN servers
    };

    struct ICEConfiguration
    {
        juce::Array<ICEServer> servers;
        bool enableIPv6 = true;

        // Default STUN servers (Google)
        static ICEConfiguration getDefault()
        {
            ICEConfiguration config;
            config.servers.add({"stun:stun.l.google.com:19302", "", ""});
            config.servers.add({"stun:stun1.l.google.com:19302", "", ""});
            return config;
        }
    };

    //==========================================================================
    // Audio/Video Configuration
    //==========================================================================

    struct AudioConfig
    {
        int sampleRate = 48000;
        int numChannels = 2;
        int bitrate = 64000;            // 64 kbps (good quality)

        // Opus settings
        bool useOpus = true;
        int opusComplexity = 5;         // 0-10 (5 = balanced)
        int opusFrameSize = 480;        // 10ms @ 48kHz (ultra-low latency)
        bool enableFEC = true;          // Forward Error Correction
        bool enableDTX = false;         // Discontinuous Transmission (save bandwidth)
    };

    struct VideoConfig
    {
        int width = 1280;
        int height = 720;
        int framerate = 30;
        int bitrate = 1000000;          // 1 Mbps

        enum class Codec { VP8, VP9, H264, AV1 };
        Codec codec = Codec::VP8;       // VP8 = best compatibility

        bool hardwareAcceleration = true;
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    WebRTCTransport();
    ~WebRTCTransport();

    //==========================================================================
    // Connection Management
    //==========================================================================

    /** Set ICE servers (STUN/TURN) */
    void setICEConfiguration(const ICEConfiguration& config);

    /** Create offer (as initiator) */
    juce::String createOffer();

    /** Create answer (as responder) */
    juce::String createAnswer(const juce::String& remoteOffer);

    /** Set remote description */
    void setRemoteDescription(const juce::String& remoteSDP);

    /** Add ICE candidate */
    void addICECandidate(const juce::String& candidate);

    /** Connect to peer */
    bool connect(const juce::String& peerID);

    /** Disconnect */
    void disconnect();

    /** Get connection state */
    ConnectionState getConnectionState() const { return connectionState; }

    //==========================================================================
    // Audio Streaming
    //==========================================================================

    /** Configure audio streaming */
    void setAudioConfig(const AudioConfig& config);

    /** Send audio buffer (will be Opus encoded) */
    bool sendAudioBuffer(const juce::AudioBuffer<float>& buffer);

    /** Receive audio buffer (Opus decoded) */
    bool receiveAudioBuffer(juce::AudioBuffer<float>& buffer, int timeoutMs = 10);

    /** Enable audio streaming */
    void setAudioEnabled(bool enabled);
    bool isAudioEnabled() const { return audioEnabled; }

    //==========================================================================
    // Video Streaming
    //==========================================================================

    /** Configure video streaming */
    void setVideoConfig(const VideoConfig& config);

    /** Send video frame (will be VP8/H.264 encoded) */
    bool sendVideoFrame(const juce::Image& frame);

    /** Receive video frame (decoded) */
    bool receiveVideoFrame(juce::Image& frame, int timeoutMs = 33);

    /** Enable video streaming */
    void setVideoEnabled(bool enabled);
    bool isVideoEnabled() const { return videoEnabled; }

    //==========================================================================
    // Data Channels
    //==========================================================================

    /** Send control message via data channel */
    bool sendMessage(const juce::String& message);
    bool sendBinaryMessage(const juce::MemoryBlock& data);

    /** Callback for incoming messages */
    std::function<void(const juce::String&)> onMessageReceived;
    std::function<void(const juce::MemoryBlock&)> onBinaryMessageReceived;

    //==========================================================================
    // Network Quality
    //==========================================================================

    struct NetworkStats
    {
        float roundTripTimeMs = 0.0f;
        float jitterMs = 0.0f;
        float packetLoss = 0.0f;        // 0.0 to 1.0

        int64_t bytesSent = 0;
        int64_t bytesReceived = 0;

        int audioPacketsSent = 0;
        int audioPacketsReceived = 0;
        int audioPacketsLost = 0;

        int videoFramesSent = 0;
        int videoFramesReceived = 0;
        int videoFramesDropped = 0;
    };

    NetworkStats getNetworkStats() const;

    /** Measure latency (send ping, wait for pong) */
    float measureLatency();

    //==========================================================================
    // Callbacks
    //==========================================================================

    std::function<void(ConnectionState)> onConnectionStateChanged;
    std::function<void(const juce::String& candidate)> onICECandidate;
    std::function<void(const NetworkStats&)> onNetworkStatsUpdated;

private:
    //==========================================================================
    // Internal State
    //==========================================================================

    std::atomic<ConnectionState> connectionState { ConnectionState::Disconnected };
    std::atomic<bool> audioEnabled { true };
    std::atomic<bool> videoEnabled { false };

    AudioConfig audioConfig;
    VideoConfig videoConfig;
    ICEConfiguration iceConfig;

    NetworkStats currentStats;

    // Audio encoding/decoding (Opus)
    struct OpusEncoder;
    struct OpusDecoder;
    std::unique_ptr<OpusEncoder> opusEncoder;
    std::unique_ptr<OpusDecoder> opusDecoder;

    // Video encoding/decoding (VP8/H.264)
    struct VideoEncoder;
    struct VideoDecoder;
    std::unique_ptr<VideoEncoder> videoEncoder;
    std::unique_ptr<VideoDecoder> videoDecoder;

    // WebRTC peer connection (libdatachannel)
    struct PeerConnectionImpl;
    std::unique_ptr<PeerConnectionImpl> peerConnection;

    // Jitter buffer for audio
    struct JitterBuffer;
    std::unique_ptr<JitterBuffer> jitterBuffer;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    void initializeOpusCodec();
    void initializeVideoCodec();
    void cleanupCodecs();

    void handleIncomingAudioPacket(const uint8_t* data, size_t size);
    void handleIncomingVideoPacket(const uint8_t* data, size_t size);

    void updateNetworkStats();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(WebRTCTransport)
};
