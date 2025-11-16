/*
  ==============================================================================
   ECHOELMUSIC - Multi-Platform Streamer Implementation
  ==============================================================================
*/

#include "MultiPlatformStreamer.h"

namespace Echoelmusic {
namespace Video {

//==============================================================================
// MultiPlatformStreamer Implementation
//==============================================================================

MultiPlatformStreamer::MultiPlatformStreamer() {
    automaticHighlights = true;
    highlightDuration = 30.0;
    highlightThreshold = 70.0f;
}

MultiPlatformStreamer::~MultiPlatformStreamer() {
    stopStreaming();
}

//==============================================================================
// Platform Management
//==============================================================================

void MultiPlatformStreamer::addPlatform(const StreamPlatform& platform) {
    platforms.push_back(platform);
    DBG("Added streaming platform: " << platform.name);
}

void MultiPlatformStreamer::removePlatform(StreamPlatform::Type type) {
    platforms.erase(
        std::remove_if(platforms.begin(), platforms.end(),
            [type](const StreamPlatform& p) { return p.type == type; }),
        platforms.end()
    );
}

void MultiPlatformStreamer::enablePlatform(StreamPlatform::Type type, bool enable) {
    auto* platform = getPlatform(type);
    if (platform) {
        platform->enabled = enable;
        DBG("Platform " << platform->name << " " << (enable ? "enabled" : "disabled"));
    }
}

StreamPlatform* MultiPlatformStreamer::getPlatform(StreamPlatform::Type type) {
    for (auto& platform : platforms) {
        if (platform.type == type)
            return &platform;
    }
    return nullptr;
}

//==============================================================================
// Streaming Control
//==============================================================================

void MultiPlatformStreamer::startStreaming() {
    if (streaming) return;

    DBG("Starting multi-platform streaming...");
    streaming = true;
    streamStartTime = juce::Time::getCurrentTime().toMilliseconds() / 1000.0;

    // Connect to all enabled platforms
    for (auto& platform : platforms) {
        if (platform.enabled) {
            connectToPlatform(platform);
        }
    }
}

void MultiPlatformStreamer::stopStreaming() {
    if (!streaming) return;

    DBG("Stopping multi-platform streaming...");
    streaming = false;

    // Disconnect from all platforms
    for (auto& platform : platforms) {
        if (platform.connected) {
            disconnectFromPlatform(platform);
        }
    }
}

void MultiPlatformStreamer::pauseStreaming(bool pause) {
    paused = pause;
    DBG("Streaming " << (pause ? "paused" : "resumed"));
}

//==============================================================================
// Video/Audio Input
//==============================================================================

void MultiPlatformStreamer::setVideoSource(const juce::Image& frame) {
    if (!streaming || paused) return;

    // Send frame to all connected platforms
    for (auto& platform : platforms) {
        if (platform.connected) {
            processVideoFrame(frame, platform);
        }
    }

    // Store in buffer for highlights
    if (automaticHighlights) {
        frameBuffer.push_back(frame);

        // Keep only last N seconds
        int maxFrames = (int)(bufferDuration * 30);  // Assuming 30 FPS
        if (frameBuffer.size() > maxFrames) {
            frameBuffer.erase(frameBuffer.begin());
        }
    }

    totalFrames++;
}

void MultiPlatformStreamer::setAudioSource(const juce::AudioBuffer<float>& audioBuffer) {
    // TODO: Process and send audio to platforms
}

//==============================================================================
// Biofeedback Integration
//==============================================================================

void MultiPlatformStreamer::updateBiofeedback(float heartRate, float hrv, float coherence) {
    currentHeartRate = heartRate;
    currentHRV = hrv;
    currentCoherence = coherence;

    // Check for highlight-worthy moments
    if (automaticHighlights && coherence > highlightThreshold) {
        detectHighlights();
    }
}

void MultiPlatformStreamer::setEmotionPeakCallback(std::function<void(const StreamHighlight&)> callback) {
    // TODO: Implement callback
}

//==============================================================================
// Automatic Highlights
//==============================================================================

void MultiPlatformStreamer::enableAutomaticHighlights(bool enable) {
    automaticHighlights = enable;
    DBG("Automatic highlights " << (enable ? "enabled" : "disabled"));
}

void MultiPlatformStreamer::setHighlightDuration(double seconds) {
    highlightDuration = juce::jlimit(10.0, 120.0, seconds);
}

void MultiPlatformStreamer::setHighlightThreshold(float score) {
    highlightThreshold = juce::jlimit(0.0f, 100.0f, score);
}

void MultiPlatformStreamer::exportHighlightAsShort(const StreamHighlight& highlight, const juce::File& outputFile) {
    DBG("Exporting highlight to: " << outputFile.getFullPathName());
    DBG("Highlight duration: " << (highlight.endTime - highlight.startTime) << " seconds");
    DBG("Reason: " << highlight.reason << ", Score: " << highlight.score);

    // TODO: Export highlight using FFmpeg
}

void MultiPlatformStreamer::autoPostHighlights(bool enable) {
    DBG("Auto-post highlights " << (enable ? "enabled" : "disabled"));
    // TODO: Implement auto-posting to Instagram/TikTok/YouTube Shorts
}

//==============================================================================
// Statistics
//==============================================================================

MultiPlatformStreamer::StreamStats MultiPlatformStreamer::getStats(StreamPlatform::Type type) const {
    StreamStats stats;

    auto* platform = const_cast<MultiPlatformStreamer*>(this)->getPlatform(type);
    if (!platform) return stats;

    double now = juce::Time::getCurrentTime().toMilliseconds() / 1000.0;
    stats.streamDuration = now - streamStartTime;
    stats.totalFrames = totalFrames;
    stats.droppedFrames = platform->droppedFrames;
    stats.currentBitrate = platform->currentBitrate;
    stats.avgBitrate = platform->bitrate;
    stats.avgFPS = stats.streamDuration > 0 ? totalFrames / stats.streamDuration : 0;
    stats.viewers = 0;  // TODO: Get from platform API
    stats.chatMessages = 0;

    return stats;
}

//==============================================================================
// Platform Presets
//==============================================================================

StreamPlatform MultiPlatformStreamer::createTwitchPreset(const juce::String& streamKey) {
    StreamPlatform platform;
    platform.type = StreamPlatform::Type::Twitch;
    platform.name = "Twitch";
    platform.rtmpUrl = RTMPStreamManager::getTwitchRTMPUrl();
    platform.streamKey = streamKey;
    platform.width = 1920;
    platform.height = 1080;
    platform.fps = 60;
    platform.bitrate = 6000;
    platform.audioSampleRate = 48000;
    platform.audioBitrate = 160;
    platform.audioChannels = 2;
    platform.videoCodec = "x264";
    platform.audioCodec = "aac";
    platform.portraitMode = false;
    platform.showChat = true;
    platform.enabled = true;
    platform.connected = false;

    return platform;
}

StreamPlatform MultiPlatformStreamer::createYouTubePreset(const juce::String& streamKey) {
    StreamPlatform platform;
    platform.type = StreamPlatform::Type::YouTube;
    platform.name = "YouTube";
    platform.rtmpUrl = RTMPStreamManager::getYouTubeRTMPUrl();
    platform.streamKey = streamKey;
    platform.width = 1920;
    platform.height = 1080;
    platform.fps = 60;
    platform.bitrate = 8000;
    platform.audioSampleRate = 48000;
    platform.audioBitrate = 192;
    platform.audioChannels = 2;
    platform.videoCodec = "x264";
    platform.audioCodec = "aac";
    platform.portraitMode = false;
    platform.showChat = false;
    platform.enabled = true;
    platform.connected = false;

    return platform;
}

StreamPlatform MultiPlatformStreamer::createInstagramPreset(const juce::String& streamKey) {
    StreamPlatform platform;
    platform.type = StreamPlatform::Type::Instagram;
    platform.name = "Instagram Live";
    platform.rtmpUrl = RTMPStreamManager::getInstagramRTMPUrl();
    platform.streamKey = streamKey;
    platform.width = 1080;
    platform.height = 1920;  // Portrait
    platform.fps = 30;
    platform.bitrate = 4000;
    platform.audioSampleRate = 44100;
    platform.audioBitrate = 128;
    platform.audioChannels = 2;
    platform.videoCodec = "x264";
    platform.audioCodec = "aac";
    platform.portraitMode = true;
    platform.showChat = false;
    platform.enabled = true;
    platform.connected = false;

    return platform;
}

StreamPlatform MultiPlatformStreamer::createTikTokPreset(const juce::String& streamKey) {
    StreamPlatform platform;
    platform.type = StreamPlatform::Type::TikTok;
    platform.name = "TikTok Live";
    platform.rtmpUrl = "rtmp://live.tiktok.com/rtmp/";
    platform.streamKey = streamKey;
    platform.width = 1080;
    platform.height = 1920;  // Portrait
    platform.fps = 30;
    platform.bitrate = 4000;
    platform.audioSampleRate = 44100;
    platform.audioBitrate = 128;
    platform.audioChannels = 2;
    platform.videoCodec = "x264";
    platform.audioCodec = "aac";
    platform.portraitMode = true;
    platform.showChat = true;
    platform.enabled = true;
    platform.connected = false;

    return platform;
}

StreamPlatform MultiPlatformStreamer::createFacebookPreset(const juce::String& streamKey) {
    StreamPlatform platform;
    platform.type = StreamPlatform::Type::Facebook;
    platform.name = "Facebook Live";
    platform.rtmpUrl = RTMPStreamManager::getFacebookRTMPUrl();
    platform.streamKey = streamKey;
    platform.width = 1280;
    platform.height = 720;
    platform.fps = 30;
    platform.bitrate = 4000;
    platform.audioSampleRate = 48000;
    platform.audioBitrate = 128;
    platform.audioChannels = 2;
    platform.videoCodec = "x264";
    platform.audioCodec = "aac";
    platform.portraitMode = false;
    platform.showChat = true;
    platform.enabled = true;
    platform.connected = false;

    return platform;
}

//==============================================================================
// Internal Methods
//==============================================================================

void MultiPlatformStreamer::processVideoFrame(const juce::Image& frame, StreamPlatform& platform) {
    juce::Image processedFrame = frame;

    // Crop/resize for platform
    if (platform.width != frame.getWidth() || platform.height != frame.getHeight()) {
        cropForPlatform(frame, processedFrame, platform);
    }

    // Apply overlay if specified
    if (platform.overlayFile.isNotEmpty()) {
        juce::File overlayFile(platform.overlayFile);
        if (overlayFile.existsAsFile()) {
            applyOverlay(processedFrame, overlayFile);
        }
    }

    // TODO: Send to FFmpeg encoder for this platform
}

void MultiPlatformStreamer::cropForPlatform(const juce::Image& source, juce::Image& dest, const StreamPlatform& platform) {
    dest = juce::Image(source.getFormat(), platform.width, platform.height, true);

    juce::Graphics g(dest);

    if (platform.portraitMode && source.getWidth() > source.getHeight()) {
        // Crop center for portrait
        int cropX = (source.getWidth() - source.getHeight()) / 2;
        g.drawImage(source, 0, 0, dest.getWidth(), dest.getHeight(),
                   cropX, 0, source.getHeight(), source.getHeight());
    } else {
        // Scale to fit
        g.drawImage(source, 0, 0, dest.getWidth(), dest.getHeight(),
                   0, 0, source.getWidth(), source.getHeight());
    }
}

void MultiPlatformStreamer::applyOverlay(juce::Image& frame, const juce::File& overlayFile) {
    juce::Image overlay = juce::ImageFileFormat::loadFrom(overlayFile);
    if (overlay.isValid()) {
        juce::Graphics g(frame);
        g.drawImage(overlay, 0, 0, frame.getWidth(), frame.getHeight(),
                   0, 0, overlay.getWidth(), overlay.getHeight());
    }
}

void MultiPlatformStreamer::detectHighlights() {
    double now = juce::Time::getCurrentTime().toMilliseconds() / 1000.0;
    double startTime = now - highlightDuration;

    float score = calculateExcitementScore(now);

    if (score > highlightThreshold) {
        StreamHighlight highlight;
        highlight.startTime = startTime;
        highlight.endTime = now;
        highlight.score = score;
        highlight.reason = "biofeedback_peak";
        highlight.avgHeartRate = currentHeartRate;
        highlight.avgCoherence = currentCoherence;
        highlight.peakEmotion = score;

        highlights.push_back(highlight);

        DBG("Detected highlight! Score: " << score << ", Duration: " << highlightDuration << "s");

        if (onHighlightDetected)
            onHighlightDetected(highlight);
    }
}

float MultiPlatformStreamer::calculateExcitementScore(double timestamp) {
    // Combine biofeedback metrics into excitement score
    float hrScore = juce::jlimit(0.0f, 1.0f, (currentHeartRate - 60.0f) / 40.0f);  // 60-100 BPM
    float coherenceScore = currentCoherence / 100.0f;

    return (hrScore * 0.5f + coherenceScore * 0.5f) * 100.0f;
}

void MultiPlatformStreamer::connectToPlatform(StreamPlatform& platform) {
    DBG("Connecting to " << platform.name << "...");

    // TODO: Start FFmpeg process with RTMP streaming
    RTMPStreamManager::Config config;
    config.rtmpUrl = platform.rtmpUrl;
    config.streamKey = platform.streamKey;
    config.width = platform.width;
    config.height = platform.height;
    config.fps = platform.fps;
    config.videoBitrate = platform.bitrate;
    config.audioBitrate = platform.audioBitrate;
    config.videoCodec = platform.videoCodec;
    config.audioCodec = platform.audioCodec;
    config.preset = "veryfast";

    juce::String ffmpegCmd = RTMPStreamManager::buildFFmpegCommand(config);
    DBG("FFmpeg command: " << ffmpegCmd);

    platform.connected = true;

    if (onPlatformConnectionChanged)
        onPlatformConnectionChanged(platform.type, true);
}

void MultiPlatformStreamer::disconnectFromPlatform(StreamPlatform& platform) {
    DBG("Disconnecting from " << platform.name << "...");

    // TODO: Stop FFmpeg process
    platform.connected = false;

    if (onPlatformConnectionChanged)
        onPlatformConnectionChanged(platform.type, false);
}

void MultiPlatformStreamer::sendFrameToPlatform(
    const juce::Image& frame,
    const juce::AudioBuffer<float>& audio,
    StreamPlatform& platform)
{
    // TODO: Pipe frame data to FFmpeg stdin
}

} // namespace Video
} // namespace Echoelmusic
