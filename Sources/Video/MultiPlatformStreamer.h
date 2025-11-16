/*
  ==============================================================================
   ECHOELMUSIC - Multi-Platform Live Streamer
   Gleichzeitiges Streaming zu mehreren Plattformen mit automatischer Optimierung

   Platforms:
   - Twitch (1920x1080, 6000 kbps, x264)
   - YouTube (1920x1080, 8000 kbps, x264)
   - Instagram Live (1080x1920 Portrait, 4000 kbps, x264)
   - TikTok Live (1080x1920 Portrait, 4000 kbps, x264)
   - Facebook Live (1280x720, 4000 kbps, x264)

   Features:
   - Automatische Plattform-spezifische Optimierung
   - Verschiedene Crops und Overlays pro Plattform
   - Automatische Highlights als Shorts/Reels/Stories während Stream
   - Biofeedback-Integration (HRV → Streaming-Effekte)
  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include <vector>
#include <memory>

namespace Echoelmusic {
namespace Video {

//==============================================================================
/** Streaming Platform Configuration */
struct StreamPlatform {
    enum class Type {
        Twitch,
        YouTube,
        Instagram,
        TikTok,
        Facebook,
        Custom
    };

    Type type;
    juce::String name;
    juce::String rtmpUrl;
    juce::String streamKey;

    // Video settings
    int width;
    int height;
    int fps;
    int bitrate;  // kbps

    // Audio settings
    int audioSampleRate;
    int audioBitrate;  // kbps
    int audioChannels;

    // Codec
    juce::String videoCodec;  // "x264", "x265", "nvenc"
    juce::String audioCodec;  // "aac", "opus"

    // Platform-specific
    bool portraitMode;      // Instagram/TikTok
    bool showChat;
    juce::String overlayFile;  // Platform-specific overlay PNG

    // Status
    bool enabled;
    bool connected;
    float currentBitrate;
    int droppedFrames;
};

//==============================================================================
/** Automatic Highlight Detection für Shorts/Reels */
struct StreamHighlight {
    double startTime;
    double endTime;
    float score;           // 0-100 (excitement score)
    juce::String reason;   // "emotion_peak", "chat_spike", "donation", "biofeedback_peak"

    // Biofeedback context
    float avgHeartRate;
    float avgCoherence;
    float peakEmotion;
};

//==============================================================================
/**
 * Multi-Platform Live Streamer
 *
 * Gleichzeitiges Streaming zu mehreren Plattformen mit:
 * - Automatischer Bitrate-Anpassung pro Plattform
 * - Plattform-spezifischen Crops (Landscape/Portrait)
 * - Automatischer Highlight-Detection während Stream
 * - Biofeedback-gesteuerter Effekte
 */
class MultiPlatformStreamer {
public:
    MultiPlatformStreamer();
    ~MultiPlatformStreamer();

    //==============================================================================
    // Platform Management
    void addPlatform(const StreamPlatform& platform);
    void removePlatform(StreamPlatform::Type type);
    void enablePlatform(StreamPlatform::Type type, bool enable);

    const std::vector<StreamPlatform>& getPlatforms() const { return platforms; }
    StreamPlatform* getPlatform(StreamPlatform::Type type);

    //==============================================================================
    // Streaming Control
    void startStreaming();
    void stopStreaming();
    bool isStreaming() const { return streaming; }

    void pauseStreaming(bool pause);
    bool isPaused() const { return paused; }

    //==============================================================================
    // Video/Audio Input
    void setVideoSource(const juce::Image& frame);
    void setAudioSource(const juce::AudioBuffer<float>& audioBuffer);

    //==============================================================================
    // Biofeedback Integration
    void updateBiofeedback(float heartRate, float hrv, float coherence);
    void setEmotionPeakCallback(std::function<void(const StreamHighlight&)> callback);

    //==============================================================================
    // Automatic Highlights
    void enableAutomaticHighlights(bool enable);
    void setHighlightDuration(double seconds);  // Default: 30 seconds
    void setHighlightThreshold(float score);    // Minimum score to save highlight

    const std::vector<StreamHighlight>& getHighlights() const { return highlights; }

    void exportHighlightAsShort(const StreamHighlight& highlight, const juce::File& outputFile);
    void autoPostHighlights(bool enable);  // Auto-post to Instagram/TikTok/YouTube Shorts

    //==============================================================================
    // Statistics
    struct StreamStats {
        double streamDuration;
        int totalFrames;
        int droppedFrames;
        float avgBitrate;
        float currentBitrate;
        float avgFPS;
        int viewers;  // From platform API
        int chatMessages;
    };

    StreamStats getStats(StreamPlatform::Type type) const;

    //==============================================================================
    // Platform Presets (Quick Setup)
    static StreamPlatform createTwitchPreset(const juce::String& streamKey);
    static StreamPlatform createYouTubePreset(const juce::String& streamKey);
    static StreamPlatform createInstagramPreset(const juce::String& streamKey);
    static StreamPlatform createTikTokPreset(const juce::String& streamKey);
    static StreamPlatform createFacebookPreset(const juce::String& streamKey);

    //==============================================================================
    // Callbacks
    std::function<void(StreamPlatform::Type, bool connected)> onPlatformConnectionChanged;
    std::function<void(StreamPlatform::Type, const juce::String& error)> onPlatformError;
    std::function<void(const StreamHighlight&)> onHighlightDetected;
    std::function<void(float progress)> onHighlightExportProgress;

private:
    //==============================================================================
    // Internal
    void processVideoFrame(const juce::Image& frame, StreamPlatform& platform);
    void cropForPlatform(const juce::Image& source, juce::Image& dest, const StreamPlatform& platform);
    void applyOverlay(juce::Image& frame, const juce::File& overlayFile);

    void detectHighlights();
    float calculateExcitementScore(double timestamp);

    void connectToPlatform(StreamPlatform& platform);
    void disconnectFromPlatform(StreamPlatform& platform);
    void sendFrameToPlatform(const juce::Image& frame, const juce::AudioBuffer<float>& audio, StreamPlatform& platform);

    //==============================================================================
    // Data
    std::vector<StreamPlatform> platforms;
    bool streaming = false;
    bool paused = false;

    // Biofeedback
    float currentHeartRate = 70.0f;
    float currentHRV = 50.0f;
    float currentCoherence = 50.0f;

    // Highlights
    bool automaticHighlights = true;
    double highlightDuration = 30.0;
    float highlightThreshold = 70.0f;
    std::vector<StreamHighlight> highlights;

    // Recording buffer (for highlight extraction)
    std::vector<juce::Image> frameBuffer;
    std::vector<juce::AudioBuffer<float>> audioBuffer;
    double bufferDuration = 60.0;  // Keep last 60 seconds

    // Stats
    double streamStartTime = 0.0;
    int totalFrames = 0;

    // FFmpeg processes (one per platform)
    struct FFmpegEncoder {
        void* process = nullptr;  // Platform-specific process handle
        juce::String rtmpUrl;
        bool connected = false;
    };
    std::map<StreamPlatform::Type, FFmpegEncoder> encoders;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MultiPlatformStreamer)
};

//==============================================================================
/**
 * RTMP Stream Manager
 *
 * Wrapper um FFmpeg für RTMP streaming
 */
class RTMPStreamManager {
public:
    struct Config {
        juce::String rtmpUrl;
        juce::String streamKey;
        int width;
        int height;
        int fps;
        int videoBitrate;  // kbps
        int audioBitrate;  // kbps
        juce::String videoCodec;  // "libx264", "h264_nvenc"
        juce::String audioCodec;  // "aac"
        juce::String preset;      // "ultrafast", "fast", "medium", "slow"
    };

    static juce::String buildFFmpegCommand(const Config& config) {
        juce::String cmd;

        // FFmpeg base command (input from stdin, output to RTMP)
        cmd << "ffmpeg -y ";
        cmd << "-f rawvideo ";
        cmd << "-pixel_format rgba ";
        cmd << "-video_size " << config.width << "x" << config.height << " ";
        cmd << "-framerate " << config.fps << " ";
        cmd << "-i - ";  // Video from stdin

        // Audio input (TODO: pipe audio separately)
        cmd << "-f f32le ";
        cmd << "-ar 48000 ";
        cmd << "-ac 2 ";
        cmd << "-i - ";  // Audio from stdin

        // Video codec
        cmd << "-c:v " << config.videoCodec << " ";
        cmd << "-preset " << config.preset << " ";
        cmd << "-b:v " << config.videoBitrate << "k ";
        cmd << "-maxrate " << config.videoBitrate << "k ";
        cmd << "-bufsize " << (config.videoBitrate * 2) << "k ";

        // Keyframe interval (2 seconds for streaming)
        cmd << "-g " << (config.fps * 2) << " ";

        // Audio codec
        cmd << "-c:a " << config.audioCodec << " ";
        cmd << "-b:a " << config.audioBitrate << "k ";
        cmd << "-ar 48000 ";

        // RTMP output
        cmd << "-f flv ";
        cmd << "\"" << config.rtmpUrl << "/" << config.streamKey << "\"";

        return cmd;
    }

    /**
     * Platform-specific RTMP URLs
     */
    static juce::String getTwitchRTMPUrl(const juce::String& region = "eu") {
        if (region == "eu") return "rtmp://fra.contribute.live-video.net/app";
        if (region == "us") return "rtmp://lax.contribute.live-video.net/app";
        return "rtmp://live.twitch.tv/app";
    }

    static juce::String getYouTubeRTMPUrl() {
        return "rtmp://a.rtmp.youtube.com/live2";
    }

    static juce::String getInstagramRTMPUrl() {
        return "rtmps://live-upload.instagram.com:443/rtmp";
    }

    static juce::String getFacebookRTMPUrl() {
        return "rtmps://live-api-s.facebook.com:443/rtmp";
    }
};

} // namespace Video
} // namespace Echoelmusic
