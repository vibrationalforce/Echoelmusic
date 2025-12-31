/**
 * EchoelLiveStream.h
 *
 * ============================================================================
 *   RALPH WIGGUM GENIUS LOOP MODE - LIVE STREAMING ENGINE
 * ============================================================================
 *
 * Multi-protocol live streaming with:
 * - RTMP output for YouTube/Twitch/Facebook
 * - HLS for web playback
 * - WebRTC for ultra-low latency
 * - Adaptive bitrate encoding
 * - GPU-accelerated encoding (NVENC/VideoToolbox/VA-API)
 * - Lock-free frame submission
 *
 * Architecture:
 * ┌─────────────────────────────────────────────────────────────────────┐
 * │                      LIVE STREAMING ENGINE                          │
 * ├─────────────────────────────────────────────────────────────────────┤
 * │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                 │
 * │  │   Video     │  │   Audio     │  │  Metadata   │                 │
 * │  │   Capture   │  │   Capture   │  │   Overlay   │                 │
 * │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘                 │
 * │         │                │                │                         │
 * │         ▼                ▼                ▼                         │
 * │  ┌─────────────────────────────────────────────────────────────┐   │
 * │  │              Lock-Free Frame Queue (Ring Buffer)             │   │
 * │  └─────────────────────────────────────────────────────────────┘   │
 * │         │                │                │                         │
 * │         ▼                ▼                ▼                         │
 * │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                 │
 * │  │   H.264/    │  │   AAC/      │  │   Muxer     │                 │
 * │  │   HEVC      │  │   Opus      │  │   (FLV/TS)  │                 │
 * │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘                 │
 * │         │                │                │                         │
 * │         ▼                ▼                ▼                         │
 * │  ┌─────────────────────────────────────────────────────────────┐   │
 * │  │                    Output Multiplexer                        │   │
 * │  │    ┌────────┐    ┌────────┐    ┌────────┐                    │   │
 * │  │    │  RTMP  │    │  HLS   │    │ WebRTC │                    │   │
 * │  │    └────────┘    └────────┘    └────────┘                    │   │
 * │  └─────────────────────────────────────────────────────────────┘   │
 * └─────────────────────────────────────────────────────────────────────┘
 */

#pragma once

#include <array>
#include <atomic>
#include <chrono>
#include <cstdint>
#include <functional>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <thread>
#include <vector>

namespace Echoel { namespace Stream {

//==============================================================================
// Constants
//==============================================================================

static constexpr size_t MAX_VIDEO_QUEUE_SIZE = 60;   // 1 second at 60fps
static constexpr size_t MAX_AUDIO_QUEUE_SIZE = 100;  // ~2 seconds
static constexpr size_t MAX_OUTPUTS = 4;
static constexpr size_t MAX_QUALITY_LEVELS = 6;

//==============================================================================
// Enums
//==============================================================================

enum class StreamProtocol : uint8_t
{
    RTMP = 0,       // Real-Time Messaging Protocol
    RTMPS,          // RTMP over TLS
    HLS,            // HTTP Live Streaming
    DASH,           // Dynamic Adaptive Streaming over HTTP
    WebRTC,         // Web Real-Time Communication
    SRT,            // Secure Reliable Transport
    RIST            // Reliable Internet Stream Transport
};

enum class VideoCodec : uint8_t
{
    H264 = 0,       // AVC
    H265,           // HEVC
    VP8,
    VP9,
    AV1
};

enum class AudioCodec : uint8_t
{
    AAC = 0,
    Opus,
    MP3,
    FLAC
};

enum class EncoderType : uint8_t
{
    Software = 0,   // x264/x265
    NVENC,          // NVIDIA
    QSV,            // Intel Quick Sync
    AMF,            // AMD
    VideoToolbox,   // Apple
    VAAPI           // Linux VA-API
};

enum class StreamState : uint8_t
{
    Idle = 0,
    Connecting,
    Streaming,
    Reconnecting,
    Error,
    Stopping
};

enum class BitrateMode : uint8_t
{
    CBR = 0,        // Constant Bitrate
    VBR,            // Variable Bitrate
    ABR,            // Average Bitrate
    CRF             // Constant Rate Factor
};

//==============================================================================
// Data Structures
//==============================================================================

struct VideoConfig
{
    uint32_t width = 1920;
    uint32_t height = 1080;
    float frameRate = 30.0f;
    VideoCodec codec = VideoCodec::H264;
    EncoderType encoder = EncoderType::Software;
    BitrateMode bitrateMode = BitrateMode::CBR;

    // Bitrate in kbps
    uint32_t bitrate = 4500;
    uint32_t minBitrate = 1000;
    uint32_t maxBitrate = 8000;

    // Quality settings
    uint32_t keyframeInterval = 2;  // seconds
    std::string preset = "medium";  // ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, veryslow
    std::string profile = "high";   // baseline, main, high
    std::string tune = "";          // film, animation, grain, stillimage, psnr, ssim, fastdecode, zerolatency

    // Advanced
    uint32_t bFrames = 2;
    uint32_t refFrames = 3;
    bool cabac = true;
    uint32_t lookahead = 0;         // 0 for low latency
};

struct AudioConfig
{
    uint32_t sampleRate = 48000;
    uint32_t channels = 2;
    uint32_t bitrate = 160;  // kbps
    AudioCodec codec = AudioCodec::AAC;
};

struct StreamOutput
{
    std::string name;
    std::string url;
    std::string streamKey;
    StreamProtocol protocol = StreamProtocol::RTMP;
    bool enabled = true;

    // Per-output overrides
    std::optional<uint32_t> videoBitrate;
    std::optional<uint32_t> audioBitrate;

    // State
    StreamState state = StreamState::Idle;
    uint64_t bytesTransmitted = 0;
    uint64_t framesDropped = 0;
    float currentBitrate = 0.0f;
    float bufferFillPercent = 0.0f;
};

struct StreamConfig
{
    VideoConfig video;
    AudioConfig audio;
    std::vector<StreamOutput> outputs;

    bool enableAdaptiveBitrate = true;
    bool enableLowLatencyMode = true;
    bool enableMetadataOverlay = true;

    // Reconnection
    uint32_t maxReconnectAttempts = 5;
    uint32_t reconnectDelayMs = 5000;

    // Buffer
    uint32_t outputBufferMs = 1000;
};

struct QualityLevel
{
    std::string name;
    uint32_t width;
    uint32_t height;
    uint32_t videoBitrate;
    uint32_t audioBitrate;
    float frameRate;
};

//==============================================================================
// Video Frame
//==============================================================================

struct VideoFrame
{
    enum class Format : uint8_t
    {
        RGBA = 0,
        BGRA,
        NV12,
        I420,
        P010     // 10-bit
    };

    uint32_t width = 0;
    uint32_t height = 0;
    Format format = Format::RGBA;
    uint64_t timestampUs = 0;
    uint64_t durationUs = 0;
    bool isKeyframe = false;

    std::vector<uint8_t> data;
    std::vector<size_t> planeOffsets;  // For planar formats
    std::vector<size_t> planeStrides;

    // GPU handle (if using GPU path)
    void* gpuHandle = nullptr;
    int gpuTextureId = -1;

    size_t dataSize() const { return data.size(); }
};

//==============================================================================
// Audio Frame
//==============================================================================

struct AudioFrame
{
    enum class Format : uint8_t
    {
        Float32 = 0,
        Int16,
        Int32
    };

    uint32_t sampleRate = 48000;
    uint32_t channels = 2;
    uint32_t numSamples = 0;
    Format format = Format::Float32;
    uint64_t timestampUs = 0;

    std::vector<uint8_t> data;

    size_t dataSize() const { return data.size(); }

    size_t bytesPerSample() const
    {
        switch (format)
        {
            case Format::Float32: return 4;
            case Format::Int16: return 2;
            case Format::Int32: return 4;
        }
        return 4;
    }
};

//==============================================================================
// Encoded Packet
//==============================================================================

struct EncodedPacket
{
    enum class Type : uint8_t
    {
        Video = 0,
        Audio,
        Metadata
    };

    Type type;
    uint64_t pts;  // Presentation timestamp
    uint64_t dts;  // Decode timestamp
    uint64_t duration;
    bool isKeyframe = false;
    std::vector<uint8_t> data;
};

//==============================================================================
// Stream Statistics
//==============================================================================

struct StreamStats
{
    // Timing
    uint64_t streamDurationMs = 0;
    uint64_t uptimeMs = 0;

    // Video
    uint64_t videoFramesEncoded = 0;
    uint64_t videoFramesDropped = 0;
    uint64_t videoBytesEncoded = 0;
    float videoFps = 0.0f;
    float videoEncoderLatencyMs = 0.0f;

    // Audio
    uint64_t audioFramesEncoded = 0;
    uint64_t audioBytesEncoded = 0;
    float audioEncoderLatencyMs = 0.0f;

    // Network
    uint64_t totalBytesTransmitted = 0;
    float currentBitrateKbps = 0.0f;
    float networkRtt = 0.0f;
    float packetLossPercent = 0.0f;

    // Quality
    uint32_t currentQualityLevel = 0;
    float cpuUsagePercent = 0.0f;
    float gpuUsagePercent = 0.0f;
    float memoryUsageMB = 0.0f;

    // Health
    bool isHealthy = true;
    std::string lastError;
};

//==============================================================================
// Lock-Free Frame Queue
//==============================================================================

template<typename T, size_t Capacity>
class FrameQueue
{
public:
    bool push(T&& frame)
    {
        size_t currentTail = tail_.load(std::memory_order_relaxed);
        size_t nextTail = (currentTail + 1) % Capacity;

        if (nextTail == head_.load(std::memory_order_acquire))
        {
            // Queue full - drop oldest frame
            droppedFrames_.fetch_add(1, std::memory_order_relaxed);
            head_.store((head_.load(std::memory_order_relaxed) + 1) % Capacity,
                       std::memory_order_release);
        }

        frames_[currentTail] = std::move(frame);
        tail_.store(nextTail, std::memory_order_release);
        return true;
    }

    std::optional<T> pop()
    {
        size_t currentHead = head_.load(std::memory_order_relaxed);

        if (currentHead == tail_.load(std::memory_order_acquire))
            return std::nullopt;

        T frame = std::move(frames_[currentHead]);
        head_.store((currentHead + 1) % Capacity, std::memory_order_release);
        return frame;
    }

    size_t size() const
    {
        size_t h = head_.load(std::memory_order_acquire);
        size_t t = tail_.load(std::memory_order_acquire);
        return (t >= h) ? (t - h) : (Capacity - h + t);
    }

    uint64_t droppedFrames() const
    {
        return droppedFrames_.load(std::memory_order_relaxed);
    }

    void clear()
    {
        head_.store(0, std::memory_order_release);
        tail_.store(0, std::memory_order_release);
    }

private:
    std::array<T, Capacity> frames_;
    alignas(64) std::atomic<size_t> head_{0};
    alignas(64) std::atomic<size_t> tail_{0};
    alignas(64) std::atomic<uint64_t> droppedFrames_{0};
};

//==============================================================================
// Metadata Overlay
//==============================================================================

struct OverlayConfig
{
    bool enabled = true;

    // Bio data display
    bool showHeartRate = true;
    bool showCoherence = true;
    bool showBreathRate = true;
    bool showBrainwaveState = true;

    // Session info
    bool showSessionName = true;
    bool showDuration = true;
    bool showViewerCount = true;

    // Audio visualization
    bool showWaveform = true;
    bool showSpectrum = true;
    bool showBPM = true;

    // Styling
    float opacity = 0.8f;
    uint32_t primaryColor = 0xFF00FFFF;   // Cyan
    uint32_t secondaryColor = 0xFFFF00FF; // Magenta
    std::string fontName = "Roboto";
    uint32_t fontSize = 24;

    // Position (0-1 normalized)
    float bioDataX = 0.02f;
    float bioDataY = 0.02f;
    float sessionInfoX = 0.98f;
    float sessionInfoY = 0.02f;
    float visualizerX = 0.5f;
    float visualizerY = 0.95f;
};

struct OverlayData
{
    // Bio
    float heartRate = 0.0f;
    float coherence = 0.0f;
    float breathRate = 0.0f;
    std::string brainwaveState;

    // Session
    std::string sessionName;
    uint64_t durationSeconds = 0;
    uint32_t viewerCount = 0;

    // Audio
    float bpm = 0.0f;
    std::array<float, 32> spectrum{};
    std::array<float, 128> waveform{};

    // Laser
    std::string currentPattern;
    float laserIntensity = 0.0f;
};

//==============================================================================
// Callbacks
//==============================================================================

using OnStreamStartedCallback = std::function<void(const std::string& outputName)>;
using OnStreamStoppedCallback = std::function<void(const std::string& outputName, const std::string& reason)>;
using OnStreamErrorCallback = std::function<void(const std::string& outputName, int code, const std::string& message)>;
using OnStatsUpdateCallback = std::function<void(const StreamStats&)>;
using OnViewerCountCallback = std::function<void(uint32_t count)>;

//==============================================================================
// Main Live Streaming Engine
//==============================================================================

class EchoelLiveStream
{
public:
    static EchoelLiveStream& getInstance()
    {
        static EchoelLiveStream instance;
        return instance;
    }

    //==========================================================================
    // Lifecycle
    //==========================================================================

    bool initialize(const StreamConfig& config)
    {
        if (initialized_) return true;

        config_ = config;

        // Initialize encoder
        if (!initializeEncoder())
            return false;

        // Initialize output connections
        for (auto& output : config_.outputs)
        {
            outputs_.push_back(output);
        }

        // Setup quality levels for adaptive bitrate
        setupQualityLevels();

        initialized_ = true;
        return true;
    }

    void shutdown()
    {
        if (!initialized_) return;

        stopStreaming();
        shutdownEncoder();

        initialized_ = false;
    }

    //==========================================================================
    // Streaming Control
    //==========================================================================

    bool startStreaming()
    {
        if (!initialized_ || isStreaming_) return false;

        // Connect to all enabled outputs
        for (auto& output : outputs_)
        {
            if (output.enabled)
            {
                if (!connectOutput(output))
                {
                    if (onStreamError_)
                        onStreamError_(output.name, 1, "Failed to connect to " + output.url);
                }
            }
        }

        // Start encoding thread
        isStreaming_ = true;
        encodingThread_ = std::thread(&EchoelLiveStream::encodingLoop, this);
        outputThread_ = std::thread(&EchoelLiveStream::outputLoop, this);

        streamStartTime_ = std::chrono::steady_clock::now();

        return true;
    }

    void stopStreaming()
    {
        if (!isStreaming_) return;

        isStreaming_ = false;

        if (encodingThread_.joinable())
            encodingThread_.join();

        if (outputThread_.joinable())
            outputThread_.join();

        // Disconnect all outputs
        for (auto& output : outputs_)
        {
            disconnectOutput(output);
        }

        // Clear queues
        videoQueue_.clear();
        audioQueue_.clear();
    }

    bool isStreaming() const { return isStreaming_; }

    //==========================================================================
    // Frame Submission
    //==========================================================================

    /**
     * Submit video frame for encoding (lock-free)
     */
    bool submitVideoFrame(VideoFrame&& frame)
    {
        if (!isStreaming_) return false;
        return videoQueue_.push(std::move(frame));
    }

    /**
     * Submit audio frame for encoding (lock-free)
     */
    bool submitAudioFrame(AudioFrame&& frame)
    {
        if (!isStreaming_) return false;
        return audioQueue_.push(std::move(frame));
    }

    /**
     * Submit frame from GPU texture (zero-copy path)
     */
    bool submitGPUFrame(void* textureHandle, uint64_t timestampUs)
    {
        if (!isStreaming_) return false;

        VideoFrame frame;
        frame.gpuHandle = textureHandle;
        frame.timestampUs = timestampUs;
        frame.width = config_.video.width;
        frame.height = config_.video.height;

        return videoQueue_.push(std::move(frame));
    }

    //==========================================================================
    // Overlay
    //==========================================================================

    void setOverlayConfig(const OverlayConfig& config)
    {
        overlayConfig_ = config;
    }

    void updateOverlayData(const OverlayData& data)
    {
        std::lock_guard<std::mutex> lock(overlayMutex_);
        overlayData_ = data;
    }

    //==========================================================================
    // Output Management
    //==========================================================================

    bool addOutput(const StreamOutput& output)
    {
        if (outputs_.size() >= MAX_OUTPUTS)
            return false;

        outputs_.push_back(output);

        if (isStreaming_ && output.enabled)
        {
            StreamOutput& newOutput = outputs_.back();
            connectOutput(newOutput);
        }

        return true;
    }

    bool removeOutput(const std::string& name)
    {
        auto it = std::find_if(outputs_.begin(), outputs_.end(),
            [&](const StreamOutput& o) { return o.name == name; });

        if (it == outputs_.end())
            return false;

        if (isStreaming_)
            disconnectOutput(*it);

        outputs_.erase(it);
        return true;
    }

    void setOutputEnabled(const std::string& name, bool enabled)
    {
        for (auto& output : outputs_)
        {
            if (output.name == name)
            {
                if (output.enabled != enabled)
                {
                    output.enabled = enabled;
                    if (isStreaming_)
                    {
                        if (enabled)
                            connectOutput(output);
                        else
                            disconnectOutput(output);
                    }
                }
                break;
            }
        }
    }

    std::vector<StreamOutput> getOutputs() const { return outputs_; }

    //==========================================================================
    // Adaptive Bitrate
    //==========================================================================

    void setTargetBitrate(uint32_t kbps)
    {
        std::lock_guard<std::mutex> lock(configMutex_);
        config_.video.bitrate = kbps;
        updateEncoderBitrate(kbps);
    }

    void setQualityLevel(uint32_t level)
    {
        if (level >= qualityLevels_.size())
            return;

        currentQualityLevel_ = level;
        const auto& quality = qualityLevels_[level];

        setTargetBitrate(quality.videoBitrate);
    }

    uint32_t getCurrentQualityLevel() const { return currentQualityLevel_; }

    std::vector<QualityLevel> getQualityLevels() const { return qualityLevels_; }

    //==========================================================================
    // Statistics
    //==========================================================================

    StreamStats getStats() const
    {
        std::lock_guard<std::mutex> lock(statsMutex_);
        return stats_;
    }

    uint64_t getStreamDuration() const
    {
        if (!isStreaming_) return 0;
        auto now = std::chrono::steady_clock::now();
        return std::chrono::duration_cast<std::chrono::milliseconds>(
            now - streamStartTime_).count();
    }

    //==========================================================================
    // Callbacks
    //==========================================================================

    void setOnStreamStarted(OnStreamStartedCallback cb) { onStreamStarted_ = std::move(cb); }
    void setOnStreamStopped(OnStreamStoppedCallback cb) { onStreamStopped_ = std::move(cb); }
    void setOnStreamError(OnStreamErrorCallback cb) { onStreamError_ = std::move(cb); }
    void setOnStatsUpdate(OnStatsUpdateCallback cb) { onStatsUpdate_ = std::move(cb); }
    void setOnViewerCount(OnViewerCountCallback cb) { onViewerCount_ = std::move(cb); }

    //==========================================================================
    // Configuration
    //==========================================================================

    void setVideoConfig(const VideoConfig& config)
    {
        std::lock_guard<std::mutex> lock(configMutex_);
        config_.video = config;

        if (isStreaming_)
        {
            // Apply changes that can be done dynamically
            updateEncoderBitrate(config.bitrate);
        }
    }

    void setAudioConfig(const AudioConfig& config)
    {
        std::lock_guard<std::mutex> lock(configMutex_);
        config_.audio = config;
    }

    VideoConfig getVideoConfig() const { return config_.video; }
    AudioConfig getAudioConfig() const { return config_.audio; }

private:
    EchoelLiveStream() = default;
    ~EchoelLiveStream() { shutdown(); }

    EchoelLiveStream(const EchoelLiveStream&) = delete;
    EchoelLiveStream& operator=(const EchoelLiveStream&) = delete;

    //==========================================================================
    // Encoder Management
    //==========================================================================

    bool initializeEncoder()
    {
        // Detect available hardware encoders
        detectHardwareEncoders();

        // Choose best encoder
        chooseOptimalEncoder();

        // Initialize video encoder
        if (!initVideoEncoder())
            return false;

        // Initialize audio encoder
        if (!initAudioEncoder())
            return false;

        return true;
    }

    void shutdownEncoder()
    {
        // Cleanup encoder resources
    }

    void detectHardwareEncoders()
    {
        // Check for NVENC
        #ifdef __NVENC__
        hasNVENC_ = true;
        #endif

        // Check for VideoToolbox (macOS/iOS)
        #ifdef __APPLE__
        hasVideoToolbox_ = true;
        #endif

        // Check for QSV (Intel)
        // Check for AMF (AMD)
        // Check for VA-API (Linux)
    }

    void chooseOptimalEncoder()
    {
        // Priority: Hardware > Software
        if (hasNVENC_ && config_.video.encoder == EncoderType::NVENC)
            activeEncoderType_ = EncoderType::NVENC;
        else if (hasVideoToolbox_ && config_.video.encoder == EncoderType::VideoToolbox)
            activeEncoderType_ = EncoderType::VideoToolbox;
        else if (hasQSV_ && config_.video.encoder == EncoderType::QSV)
            activeEncoderType_ = EncoderType::QSV;
        else
            activeEncoderType_ = EncoderType::Software;
    }

    bool initVideoEncoder()
    {
        // Initialize x264/x265 or hardware encoder
        // This would integrate with actual encoder libraries
        return true;
    }

    bool initAudioEncoder()
    {
        // Initialize AAC/Opus encoder
        return true;
    }

    void updateEncoderBitrate(uint32_t kbps)
    {
        // Dynamically update encoder bitrate
        // For x264: x264_encoder_reconfig()
    }

    //==========================================================================
    // Encoding Loop
    //==========================================================================

    void encodingLoop()
    {
        using namespace std::chrono;

        auto lastStatsUpdate = steady_clock::now();

        while (isStreaming_)
        {
            bool didWork = false;

            // Encode video frames
            while (auto frame = videoQueue_.pop())
            {
                encodeVideoFrame(*frame);
                didWork = true;
            }

            // Encode audio frames
            while (auto frame = audioQueue_.pop())
            {
                encodeAudioFrame(*frame);
                didWork = true;
            }

            // Update stats periodically
            auto now = steady_clock::now();
            if (duration_cast<milliseconds>(now - lastStatsUpdate).count() >= 1000)
            {
                updateStats();
                lastStatsUpdate = now;

                // Adaptive bitrate adjustment
                if (config_.enableAdaptiveBitrate)
                    adjustBitrateAdaptively();
            }

            if (!didWork)
            {
                std::this_thread::sleep_for(microseconds(100));
            }
        }
    }

    void encodeVideoFrame(VideoFrame& frame)
    {
        auto encodeStart = std::chrono::high_resolution_clock::now();

        // Apply overlay if enabled
        if (overlayConfig_.enabled)
        {
            applyOverlay(frame);
        }

        // Encode frame
        EncodedPacket packet;
        packet.type = EncodedPacket::Type::Video;
        packet.pts = frame.timestampUs;
        packet.dts = frame.timestampUs;  // Simplified - real impl needs B-frame handling
        packet.isKeyframe = frame.isKeyframe;

        // Actual encoding would happen here
        // For now, just copy data as placeholder
        packet.data = std::move(frame.data);

        // Push to output queue
        encodedQueue_.push(std::move(packet));

        // Update stats
        auto encodeEnd = std::chrono::high_resolution_clock::now();
        float encodeTimeMs = std::chrono::duration<float, std::milli>(encodeEnd - encodeStart).count();

        std::lock_guard<std::mutex> lock(statsMutex_);
        stats_.videoFramesEncoded++;
        stats_.videoBytesEncoded += packet.data.size();
        stats_.videoEncoderLatencyMs = stats_.videoEncoderLatencyMs * 0.9f + encodeTimeMs * 0.1f;
    }

    void encodeAudioFrame(AudioFrame& frame)
    {
        auto encodeStart = std::chrono::high_resolution_clock::now();

        EncodedPacket packet;
        packet.type = EncodedPacket::Type::Audio;
        packet.pts = frame.timestampUs;
        packet.dts = frame.timestampUs;

        // Actual encoding would happen here
        packet.data = std::move(frame.data);

        encodedQueue_.push(std::move(packet));

        auto encodeEnd = std::chrono::high_resolution_clock::now();
        float encodeTimeMs = std::chrono::duration<float, std::milli>(encodeEnd - encodeStart).count();

        std::lock_guard<std::mutex> lock(statsMutex_);
        stats_.audioFramesEncoded++;
        stats_.audioBytesEncoded += packet.data.size();
        stats_.audioEncoderLatencyMs = stats_.audioEncoderLatencyMs * 0.9f + encodeTimeMs * 0.1f;
    }

    void applyOverlay(VideoFrame& frame)
    {
        std::lock_guard<std::mutex> lock(overlayMutex_);

        // Render overlay elements onto frame
        // This would use a simple 2D rendering system
    }

    //==========================================================================
    // Output Loop
    //==========================================================================

    void outputLoop()
    {
        while (isStreaming_)
        {
            while (auto packet = encodedQueue_.pop())
            {
                // Send to all connected outputs
                for (auto& output : outputs_)
                {
                    if (output.enabled && output.state == StreamState::Streaming)
                    {
                        sendPacketToOutput(output, *packet);
                    }
                }
            }

            std::this_thread::sleep_for(std::chrono::microseconds(100));
        }
    }

    bool connectOutput(StreamOutput& output)
    {
        output.state = StreamState::Connecting;

        // Connect based on protocol
        switch (output.protocol)
        {
            case StreamProtocol::RTMP:
            case StreamProtocol::RTMPS:
                if (!connectRTMP(output))
                    return false;
                break;

            case StreamProtocol::HLS:
                if (!setupHLS(output))
                    return false;
                break;

            case StreamProtocol::WebRTC:
                if (!connectWebRTC(output))
                    return false;
                break;

            case StreamProtocol::SRT:
                if (!connectSRT(output))
                    return false;
                break;

            default:
                return false;
        }

        output.state = StreamState::Streaming;

        if (onStreamStarted_)
            onStreamStarted_(output.name);

        return true;
    }

    void disconnectOutput(StreamOutput& output)
    {
        if (output.state == StreamState::Idle)
            return;

        // Disconnect based on protocol
        switch (output.protocol)
        {
            case StreamProtocol::RTMP:
            case StreamProtocol::RTMPS:
                disconnectRTMP(output);
                break;

            case StreamProtocol::HLS:
                cleanupHLS(output);
                break;

            case StreamProtocol::WebRTC:
                disconnectWebRTC(output);
                break;

            case StreamProtocol::SRT:
                disconnectSRT(output);
                break;

            default:
                break;
        }

        output.state = StreamState::Idle;

        if (onStreamStopped_)
            onStreamStopped_(output.name, "Stopped");
    }

    bool connectRTMP(StreamOutput& output)
    {
        // RTMP connection logic
        // Would use librtmp or similar
        return true;
    }

    void disconnectRTMP(StreamOutput& output)
    {
        // RTMP disconnect
    }

    bool setupHLS(StreamOutput& output)
    {
        // HLS segment writer setup
        return true;
    }

    void cleanupHLS(StreamOutput& output)
    {
        // Clean up HLS segments
    }

    bool connectWebRTC(StreamOutput& output)
    {
        // WebRTC connection
        return true;
    }

    void disconnectWebRTC(StreamOutput& output)
    {
        // WebRTC disconnect
    }

    bool connectSRT(StreamOutput& output)
    {
        // SRT connection
        return true;
    }

    void disconnectSRT(StreamOutput& output)
    {
        // SRT disconnect
    }

    void sendPacketToOutput(StreamOutput& output, const EncodedPacket& packet)
    {
        // Send based on protocol
        // Track bytes transmitted
        output.bytesTransmitted += packet.data.size();

        std::lock_guard<std::mutex> lock(statsMutex_);
        stats_.totalBytesTransmitted += packet.data.size();
    }

    //==========================================================================
    // Adaptive Bitrate
    //==========================================================================

    void setupQualityLevels()
    {
        qualityLevels_ = {
            { "360p",  640,  360,  800,  64, 30.0f },
            { "480p",  854,  480, 1500,  96, 30.0f },
            { "720p", 1280,  720, 3000, 128, 30.0f },
            { "720p60", 1280, 720, 4500, 160, 60.0f },
            { "1080p", 1920, 1080, 6000, 160, 30.0f },
            { "1080p60", 1920, 1080, 9000, 192, 60.0f }
        };
    }

    void adjustBitrateAdaptively()
    {
        // Check network conditions
        float packetLoss = stats_.packetLossPercent;
        float bufferFill = getAverageBufferFill();

        // Adjust quality level based on conditions
        if (packetLoss > 5.0f || bufferFill > 80.0f)
        {
            // Decrease quality
            if (currentQualityLevel_ > 0)
            {
                setQualityLevel(currentQualityLevel_ - 1);
            }
        }
        else if (packetLoss < 1.0f && bufferFill < 30.0f)
        {
            // Increase quality
            if (currentQualityLevel_ < qualityLevels_.size() - 1)
            {
                setQualityLevel(currentQualityLevel_ + 1);
            }
        }
    }

    float getAverageBufferFill() const
    {
        float total = 0.0f;
        int count = 0;
        for (const auto& output : outputs_)
        {
            if (output.enabled)
            {
                total += output.bufferFillPercent;
                count++;
            }
        }
        return count > 0 ? total / count : 0.0f;
    }

    //==========================================================================
    // Statistics
    //==========================================================================

    void updateStats()
    {
        std::lock_guard<std::mutex> lock(statsMutex_);

        stats_.streamDurationMs = getStreamDuration();

        // Calculate FPS
        static uint64_t lastFrameCount = 0;
        static auto lastFpsTime = std::chrono::steady_clock::now();

        auto now = std::chrono::steady_clock::now();
        auto elapsed = std::chrono::duration<float>(now - lastFpsTime).count();

        if (elapsed >= 1.0f)
        {
            uint64_t framesDelta = stats_.videoFramesEncoded - lastFrameCount;
            stats_.videoFps = static_cast<float>(framesDelta) / elapsed;

            lastFrameCount = stats_.videoFramesEncoded;
            lastFpsTime = now;
        }

        // Calculate bitrate
        static uint64_t lastByteCount = 0;
        static auto lastBitrateTime = std::chrono::steady_clock::now();

        auto bitrateElapsed = std::chrono::duration<float>(now - lastBitrateTime).count();
        if (bitrateElapsed >= 1.0f)
        {
            uint64_t bytesDelta = stats_.totalBytesTransmitted - lastByteCount;
            stats_.currentBitrateKbps = (bytesDelta * 8.0f / 1000.0f) / bitrateElapsed;

            lastByteCount = stats_.totalBytesTransmitted;
            lastBitrateTime = now;
        }

        stats_.currentQualityLevel = currentQualityLevel_;
        stats_.videoFramesDropped = videoQueue_.droppedFrames();

        // Notify listeners
        if (onStatsUpdate_)
            onStatsUpdate_(stats_);
    }

    //==========================================================================
    // Member Variables
    //==========================================================================

    bool initialized_ = false;
    std::atomic<bool> isStreaming_{false};

    StreamConfig config_;
    mutable std::mutex configMutex_;

    std::vector<StreamOutput> outputs_;

    // Queues
    FrameQueue<VideoFrame, MAX_VIDEO_QUEUE_SIZE> videoQueue_;
    FrameQueue<AudioFrame, MAX_AUDIO_QUEUE_SIZE> audioQueue_;
    FrameQueue<EncodedPacket, 120> encodedQueue_;

    // Threads
    std::thread encodingThread_;
    std::thread outputThread_;

    // Encoder state
    EncoderType activeEncoderType_ = EncoderType::Software;
    bool hasNVENC_ = false;
    bool hasVideoToolbox_ = false;
    bool hasQSV_ = false;
    bool hasAMF_ = false;
    bool hasVAAPI_ = false;

    // Quality
    std::vector<QualityLevel> qualityLevels_;
    uint32_t currentQualityLevel_ = 2;  // Default 720p

    // Overlay
    OverlayConfig overlayConfig_;
    OverlayData overlayData_;
    std::mutex overlayMutex_;

    // Timing
    std::chrono::steady_clock::time_point streamStartTime_;

    // Stats
    StreamStats stats_;
    mutable std::mutex statsMutex_;

    // Callbacks
    OnStreamStartedCallback onStreamStarted_;
    OnStreamStoppedCallback onStreamStopped_;
    OnStreamErrorCallback onStreamError_;
    OnStatsUpdateCallback onStatsUpdate_;
    OnViewerCountCallback onViewerCount_;
};

}} // namespace Echoel::Stream
