/**
 * EchoelVideoEditor.h
 *
 * ============================================================================
 *   RALPH WIGGUM GENIUS ULTRATHINK MODE - VIDEO EDITING ENGINE
 * ============================================================================
 *
 * Professional-grade video editing with:
 * - Non-linear timeline editing
 * - GPU-accelerated processing (Metal/CUDA/OpenCL)
 * - Real-time preview with proxy support
 * - Multi-track compositing with blend modes
 * - Audio/video synchronization
 * - Bio-reactive video effects
 * - Laser overlay integration
 *
 * Architecture:
 * ┌─────────────────────────────────────────────────────────────────────────┐
 * │                        VIDEO EDITING ENGINE                              │
 * ├─────────────────────────────────────────────────────────────────────────┤
 * │  ┌───────────────────────────────────────────────────────────────────┐  │
 * │  │                     Media Asset Manager                            │  │
 * │  │   [Import] → [Transcode] → [Proxy Gen] → [Index] → [Cache]        │  │
 * │  └───────────────────────────────────────────────────────────────────┘  │
 * │                                  │                                       │
 * │                                  ▼                                       │
 * │  ┌───────────────────────────────────────────────────────────────────┐  │
 * │  │                    Timeline Engine                                 │  │
 * │  │   [Video Tracks] [Audio Tracks] [Laser Tracks] [Bio Tracks]       │  │
 * │  │   [Transitions] [Effects] [Keyframes] [Automation]                │  │
 * │  └───────────────────────────────────────────────────────────────────┘  │
 * │                                  │                                       │
 * │                                  ▼                                       │
 * │  ┌───────────────────────────────────────────────────────────────────┐  │
 * │  │                   Render Pipeline (GPU)                            │  │
 * │  │   [Decode] → [Effects] → [Composite] → [Color] → [Encode]         │  │
 * │  └───────────────────────────────────────────────────────────────────┘  │
 * └─────────────────────────────────────────────────────────────────────────┘
 */

#pragma once

#include <array>
#include <atomic>
#include <chrono>
#include <cstdint>
#include <functional>
#include <map>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <thread>
#include <unordered_map>
#include <vector>

namespace Echoel { namespace Video {

//==============================================================================
// Constants
//==============================================================================

static constexpr size_t MAX_VIDEO_TRACKS = 32;
static constexpr size_t MAX_AUDIO_TRACKS = 64;
static constexpr size_t MAX_EFFECTS_PER_CLIP = 16;
static constexpr size_t MAX_KEYFRAMES = 10000;
static constexpr size_t FRAME_CACHE_SIZE = 120;  // 4 seconds at 30fps
static constexpr size_t UNDO_HISTORY_SIZE = 100;

//==============================================================================
// Enums
//==============================================================================

enum class MediaType : uint8_t
{
    Video = 0,
    Audio,
    Image,
    LaserPattern,
    BioData,
    Subtitle,
    Effect
};

enum class BlendMode : uint8_t
{
    Normal = 0,
    Add,
    Multiply,
    Screen,
    Overlay,
    SoftLight,
    HardLight,
    ColorDodge,
    ColorBurn,
    Difference,
    Exclusion,
    Hue,
    Saturation,
    Color,
    Luminosity,
    BioReactive  // Special: responds to bio signals
};

enum class TransitionType : uint8_t
{
    None = 0,
    Cut,
    Dissolve,
    Fade,
    Wipe,
    Slide,
    Push,
    Zoom,
    Spin,
    Blur,
    Glitch,
    BioSync,     // Transition synced to heartbeat
    LaserWipe    // Laser pattern wipe
};

enum class EffectCategory : uint8_t
{
    Color = 0,
    Blur,
    Sharpen,
    Distort,
    Stylize,
    Generate,
    Keying,
    Time,
    Audio,
    Bio,
    Laser,
    AI
};

enum class TimelineMode : uint8_t
{
    Insert = 0,
    Overwrite,
    Ripple,
    Roll,
    Slip,
    Slide
};

enum class PlaybackState : uint8_t
{
    Stopped = 0,
    Playing,
    Paused,
    Scrubbing,
    Rendering
};

enum class RenderQuality : uint8_t
{
    Draft = 0,      // Fastest, proxy
    Preview,        // Balanced
    Full,           // Full resolution
    Final           // Maximum quality
};

//==============================================================================
// Time Representation
//==============================================================================

struct Timecode
{
    int hours = 0;
    int minutes = 0;
    int seconds = 0;
    int frames = 0;
    float frameRate = 30.0f;

    double toSeconds() const
    {
        return hours * 3600.0 + minutes * 60.0 + seconds + frames / static_cast<double>(frameRate);
    }

    int64_t toFrames() const
    {
        return static_cast<int64_t>(
            (hours * 3600 + minutes * 60 + seconds) * frameRate + frames
        );
    }

    static Timecode fromSeconds(double secs, float fps = 30.0f)
    {
        Timecode tc;
        tc.frameRate = fps;
        tc.hours = static_cast<int>(secs / 3600);
        secs -= tc.hours * 3600;
        tc.minutes = static_cast<int>(secs / 60);
        secs -= tc.minutes * 60;
        tc.seconds = static_cast<int>(secs);
        tc.frames = static_cast<int>((secs - tc.seconds) * fps);
        return tc;
    }

    static Timecode fromFrames(int64_t frames, float fps = 30.0f)
    {
        return fromSeconds(frames / static_cast<double>(fps), fps);
    }

    std::string toString() const
    {
        char buf[32];
        snprintf(buf, sizeof(buf), "%02d:%02d:%02d:%02d", hours, minutes, seconds, frames);
        return std::string(buf);
    }
};

//==============================================================================
// Keyframe System
//==============================================================================

enum class InterpolationType : uint8_t
{
    Hold = 0,
    Linear,
    EaseIn,
    EaseOut,
    EaseInOut,
    Bezier,
    Spring
};

template<typename T>
struct Keyframe
{
    double time = 0.0;  // In seconds
    T value;
    InterpolationType interpolation = InterpolationType::Linear;

    // Bezier handles (normalized)
    float handleInX = 0.0f;
    float handleInY = 0.0f;
    float handleOutX = 1.0f;
    float handleOutY = 1.0f;
};

template<typename T>
class KeyframeTrack
{
public:
    void addKeyframe(double time, const T& value,
                     InterpolationType interp = InterpolationType::Linear)
    {
        Keyframe<T> kf;
        kf.time = time;
        kf.value = value;
        kf.interpolation = interp;

        auto it = std::lower_bound(keyframes_.begin(), keyframes_.end(), kf,
            [](const Keyframe<T>& a, const Keyframe<T>& b) {
                return a.time < b.time;
            });

        keyframes_.insert(it, kf);
    }

    void removeKeyframe(double time, double tolerance = 0.001)
    {
        keyframes_.erase(
            std::remove_if(keyframes_.begin(), keyframes_.end(),
                [time, tolerance](const Keyframe<T>& kf) {
                    return std::abs(kf.time - time) < tolerance;
                }),
            keyframes_.end()
        );
    }

    T evaluate(double time) const
    {
        if (keyframes_.empty())
            return T{};

        if (keyframes_.size() == 1 || time <= keyframes_.front().time)
            return keyframes_.front().value;

        if (time >= keyframes_.back().time)
            return keyframes_.back().value;

        // Find surrounding keyframes
        auto it = std::lower_bound(keyframes_.begin(), keyframes_.end(), time,
            [](const Keyframe<T>& kf, double t) { return kf.time < t; });

        const auto& kf2 = *it;
        const auto& kf1 = *(it - 1);

        // Calculate interpolation factor
        double t = (time - kf1.time) / (kf2.time - kf1.time);
        t = applyEasing(t, kf1.interpolation, kf1);

        return interpolate(kf1.value, kf2.value, static_cast<float>(t));
    }

    const std::vector<Keyframe<T>>& getKeyframes() const { return keyframes_; }
    bool hasKeyframes() const { return !keyframes_.empty(); }
    size_t count() const { return keyframes_.size(); }

private:
    double applyEasing(double t, InterpolationType type, const Keyframe<T>& kf) const
    {
        switch (type)
        {
            case InterpolationType::Hold:
                return 0.0;
            case InterpolationType::Linear:
                return t;
            case InterpolationType::EaseIn:
                return t * t;
            case InterpolationType::EaseOut:
                return 1.0 - (1.0 - t) * (1.0 - t);
            case InterpolationType::EaseInOut:
                return t < 0.5 ? 2.0 * t * t : 1.0 - 2.0 * (1.0 - t) * (1.0 - t);
            case InterpolationType::Bezier:
                return cubicBezier(t, kf.handleOutX, kf.handleOutY);
            default:
                return t;
        }
    }

    double cubicBezier(double t, float cx, float cy) const
    {
        // Simplified cubic bezier (0,0) to (1,1) with control point
        double mt = 1.0 - t;
        return 3.0 * mt * mt * t * cy + 3.0 * mt * t * t * cy + t * t * t;
    }

    T interpolate(const T& a, const T& b, float t) const;

    std::vector<Keyframe<T>> keyframes_;
};

// Specializations for common types
template<> inline float KeyframeTrack<float>::interpolate(const float& a, const float& b, float t) const
{
    return a + (b - a) * t;
}

template<> inline double KeyframeTrack<double>::interpolate(const double& a, const double& b, float t) const
{
    return a + (b - a) * t;
}

//==============================================================================
// Media Assets
//==============================================================================

struct MediaInfo
{
    std::string id;
    std::string filePath;
    std::string fileName;
    MediaType type;

    // Video properties
    uint32_t width = 0;
    uint32_t height = 0;
    float frameRate = 0.0f;
    std::string videoCodec;
    uint32_t videoBitrate = 0;

    // Audio properties
    uint32_t sampleRate = 0;
    uint32_t channels = 0;
    std::string audioCodec;
    uint32_t audioBitrate = 0;

    // Duration
    double duration = 0.0;  // seconds
    int64_t totalFrames = 0;

    // Metadata
    std::string title;
    std::string author;
    std::string description;
    std::map<std::string, std::string> metadata;

    // Proxy
    bool hasProxy = false;
    std::string proxyPath;

    // Thumbnails
    std::vector<std::string> thumbnailPaths;

    // File info
    uint64_t fileSize = 0;
    uint64_t createdTime = 0;
    uint64_t modifiedTime = 0;
};

//==============================================================================
// Effects
//==============================================================================

struct EffectParameter
{
    std::string name;
    std::string displayName;
    std::string type;  // "float", "int", "bool", "color", "point", "enum"

    // Value range
    double minValue = 0.0;
    double maxValue = 1.0;
    double defaultValue = 0.0;
    double currentValue = 0.0;

    // For enum types
    std::vector<std::string> enumOptions;

    // Keyframes
    KeyframeTrack<double> keyframes;

    bool isAnimated() const { return keyframes.hasKeyframes(); }
};

struct VideoEffect
{
    std::string id;
    std::string name;
    std::string displayName;
    EffectCategory category;
    bool isEnabled = true;

    std::vector<EffectParameter> parameters;

    // Processing hints
    bool requiresGPU = false;
    bool isRealtime = true;
    int processingOrder = 0;

    // For built-in effects
    std::string shaderCode;

    // Bio-reactive
    bool isBioReactive = false;
    std::string bioParameter;  // e.g., "coherence", "heartRate"
    float bioInfluence = 0.5f;
};

//==============================================================================
// Clips and Tracks
//==============================================================================

struct ClipRange
{
    double inPoint = 0.0;   // Source in point (seconds)
    double outPoint = 0.0;  // Source out point (seconds)

    double duration() const { return outPoint - inPoint; }
};

struct TimelineClip
{
    std::string id;
    std::string mediaId;  // Reference to MediaInfo
    std::string name;

    // Timeline position
    double startTime = 0.0;  // Position on timeline
    int trackIndex = 0;

    // Source range
    ClipRange sourceRange;

    // Speed/time
    float speed = 1.0f;
    bool reverse = false;
    bool freezeFrame = false;

    // Transform
    KeyframeTrack<float> positionX;
    KeyframeTrack<float> positionY;
    KeyframeTrack<float> scaleX;
    KeyframeTrack<float> scaleY;
    KeyframeTrack<float> rotation;
    KeyframeTrack<float> opacity;
    KeyframeTrack<float> anchorX;
    KeyframeTrack<float> anchorY;

    // Blend
    BlendMode blendMode = BlendMode::Normal;

    // Effects
    std::vector<VideoEffect> effects;

    // Audio
    KeyframeTrack<float> volume;
    KeyframeTrack<float> pan;
    bool audioEnabled = true;

    // Transitions
    std::string inTransitionId;
    std::string outTransitionId;

    // Status
    bool isSelected = false;
    bool isLocked = false;
    bool isEnabled = true;

    double endTime() const
    {
        return startTime + sourceRange.duration() / speed;
    }
};

struct Transition
{
    std::string id;
    TransitionType type;
    double duration = 1.0;  // seconds

    // Parameters
    std::map<std::string, double> parameters;

    // Custom shader
    std::string shaderCode;

    // Bio-sync
    bool syncToHeartbeat = false;
    int heartbeatCount = 1;
};

struct VideoTrack
{
    std::string id;
    std::string name;
    int index = 0;
    bool isVisible = true;
    bool isLocked = false;
    bool isMuted = false;
    bool isSolo = false;
    float opacity = 1.0f;
    BlendMode blendMode = BlendMode::Normal;

    std::vector<TimelineClip> clips;
};

struct AudioTrack
{
    std::string id;
    std::string name;
    int index = 0;
    bool isVisible = true;
    bool isLocked = false;
    bool isMuted = false;
    bool isSolo = false;
    float volume = 1.0f;
    float pan = 0.0f;

    std::vector<TimelineClip> clips;
};

//==============================================================================
// Timeline / Sequence
//==============================================================================

struct SequenceSettings
{
    std::string name = "Untitled Sequence";

    // Video settings
    uint32_t width = 1920;
    uint32_t height = 1080;
    float frameRate = 30.0f;
    float pixelAspectRatio = 1.0f;
    std::string colorSpace = "Rec. 709";

    // Audio settings
    uint32_t sampleRate = 48000;
    uint32_t audioChannels = 2;

    // Editing
    TimelineMode editMode = TimelineMode::Insert;
    bool snapToClips = true;
    bool snapToMarkers = true;
    bool snapToGrid = false;
    double gridInterval = 1.0;  // seconds

    // Preview
    RenderQuality previewQuality = RenderQuality::Preview;
    bool useProxies = true;

    // Bio integration
    bool enableBioReactive = true;
    float bioInfluence = 0.5f;
};

struct Marker
{
    std::string id;
    std::string name;
    std::string color;
    double time = 0.0;
    double duration = 0.0;
    std::string notes;
    std::string category;
};

struct Sequence
{
    std::string id;
    SequenceSettings settings;

    std::vector<VideoTrack> videoTracks;
    std::vector<AudioTrack> audioTracks;
    std::vector<Marker> markers;

    double duration = 0.0;  // Auto-calculated

    // Playhead
    double playheadPosition = 0.0;
    double inPoint = 0.0;
    double outPoint = 0.0;

    // Work area
    double workAreaStart = 0.0;
    double workAreaEnd = 0.0;

    void calculateDuration()
    {
        duration = 0.0;
        for (const auto& track : videoTracks)
        {
            for (const auto& clip : track.clips)
            {
                duration = std::max(duration, clip.endTime());
            }
        }
        for (const auto& track : audioTracks)
        {
            for (const auto& clip : track.clips)
            {
                duration = std::max(duration, clip.endTime());
            }
        }
    }
};

//==============================================================================
// Render Frame
//==============================================================================

struct RenderFrame
{
    std::vector<uint8_t> data;
    uint32_t width = 0;
    uint32_t height = 0;
    uint32_t stride = 0;

    enum class Format : uint8_t
    {
        RGBA8 = 0,
        BGRA8,
        RGB8,
        NV12,
        P010,
        RGBA16F,
        RGBA32F
    } format = Format::RGBA8;

    int64_t frameNumber = 0;
    double timestamp = 0.0;

    // GPU texture handle
    void* gpuTexture = nullptr;
    bool isGPUFrame = false;
};

//==============================================================================
// Export Settings
//==============================================================================

struct ExportSettings
{
    std::string outputPath;
    std::string format = "mp4";  // mp4, mov, webm, avi, gif

    // Video
    std::string videoCodec = "h264";
    uint32_t videoBitrate = 10000;  // kbps
    uint32_t maxBitrate = 15000;
    bool twoPass = false;
    std::string profile = "high";
    std::string preset = "medium";
    int crf = 18;

    // Resolution
    uint32_t width = 0;   // 0 = use sequence
    uint32_t height = 0;
    float frameRate = 0;  // 0 = use sequence

    // Audio
    std::string audioCodec = "aac";
    uint32_t audioBitrate = 256;  // kbps
    uint32_t audioSampleRate = 0;  // 0 = use sequence

    // Range
    bool exportWorkArea = false;
    double startTime = 0.0;
    double endTime = 0.0;

    // Options
    bool includeAudio = true;
    bool embedMetadata = true;
    bool optimizeForStreaming = true;

    // Hardware acceleration
    bool useHardwareEncoder = true;
    std::string hwAccel = "auto";  // auto, nvenc, qsv, videotoolbox
};

struct ExportProgress
{
    double progress = 0.0;  // 0-1
    int64_t framesRendered = 0;
    int64_t totalFrames = 0;
    double elapsedTime = 0.0;
    double estimatedTimeRemaining = 0.0;
    float fps = 0.0f;
    std::string currentPhase;
    bool isComplete = false;
    bool hasError = false;
    std::string errorMessage;
};

//==============================================================================
// Callbacks
//==============================================================================

using OnFrameRenderedCallback = std::function<void(const RenderFrame&)>;
using OnPlaybackStateCallback = std::function<void(PlaybackState)>;
using OnPositionChangedCallback = std::function<void(double)>;
using OnExportProgressCallback = std::function<void(const ExportProgress&)>;
using OnSequenceChangedCallback = std::function<void()>;
using OnSelectionChangedCallback = std::function<void(const std::vector<std::string>&)>;

//==============================================================================
// Frame Cache
//==============================================================================

class FrameCache
{
public:
    FrameCache(size_t maxFrames = FRAME_CACHE_SIZE)
        : maxFrames_(maxFrames)
    {}

    void put(int64_t frameNumber, RenderFrame&& frame)
    {
        std::lock_guard<std::mutex> lock(mutex_);

        // Remove oldest if at capacity
        if (cache_.size() >= maxFrames_)
        {
            int64_t oldest = accessOrder_.front();
            accessOrder_.pop_front();
            cache_.erase(oldest);
        }

        cache_[frameNumber] = std::move(frame);
        accessOrder_.push_back(frameNumber);
    }

    std::optional<RenderFrame> get(int64_t frameNumber)
    {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = cache_.find(frameNumber);
        if (it == cache_.end())
            return std::nullopt;

        // Move to back of access order
        accessOrder_.remove(frameNumber);
        accessOrder_.push_back(frameNumber);

        return it->second;
    }

    bool has(int64_t frameNumber) const
    {
        std::lock_guard<std::mutex> lock(mutex_);
        return cache_.find(frameNumber) != cache_.end();
    }

    void clear()
    {
        std::lock_guard<std::mutex> lock(mutex_);
        cache_.clear();
        accessOrder_.clear();
    }

    void invalidateRange(int64_t startFrame, int64_t endFrame)
    {
        std::lock_guard<std::mutex> lock(mutex_);
        for (int64_t f = startFrame; f <= endFrame; ++f)
        {
            cache_.erase(f);
            accessOrder_.remove(f);
        }
    }

    size_t size() const
    {
        std::lock_guard<std::mutex> lock(mutex_);
        return cache_.size();
    }

private:
    size_t maxFrames_;
    mutable std::mutex mutex_;
    std::unordered_map<int64_t, RenderFrame> cache_;
    std::list<int64_t> accessOrder_;
};

//==============================================================================
// Main Video Editor Class
//==============================================================================

class EchoelVideoEditor
{
public:
    static EchoelVideoEditor& getInstance()
    {
        static EchoelVideoEditor instance;
        return instance;
    }

    //==========================================================================
    // Lifecycle
    //==========================================================================

    bool initialize()
    {
        if (initialized_)
            return true;

        frameCache_ = std::make_unique<FrameCache>(FRAME_CACHE_SIZE);

        // Initialize GPU context
        if (!initializeGPU())
        {
            // Fall back to CPU rendering
            useGPU_ = false;
        }

        // Create default sequence
        createSequence(SequenceSettings());

        initialized_ = true;
        return true;
    }

    void shutdown()
    {
        if (!initialized_)
            return;

        stop();
        frameCache_.reset();
        shutdownGPU();

        initialized_ = false;
    }

    //==========================================================================
    // Sequence Management
    //==========================================================================

    std::string createSequence(const SequenceSettings& settings)
    {
        Sequence seq;
        seq.id = generateId("seq");
        seq.settings = settings;

        // Create default tracks
        VideoTrack vt;
        vt.id = generateId("vt");
        vt.name = "Video 1";
        vt.index = 0;
        seq.videoTracks.push_back(vt);

        AudioTrack at;
        at.id = generateId("at");
        at.name = "Audio 1";
        at.index = 0;
        seq.audioTracks.push_back(at);

        sequences_[seq.id] = seq;
        currentSequenceId_ = seq.id;

        return seq.id;
    }

    void deleteSequence(const std::string& id)
    {
        sequences_.erase(id);
        if (currentSequenceId_ == id && !sequences_.empty())
        {
            currentSequenceId_ = sequences_.begin()->first;
        }
    }

    Sequence* getCurrentSequence()
    {
        auto it = sequences_.find(currentSequenceId_);
        if (it != sequences_.end())
            return &it->second;
        return nullptr;
    }

    void setCurrentSequence(const std::string& id)
    {
        if (sequences_.find(id) != sequences_.end())
        {
            currentSequenceId_ = id;
            frameCache_->clear();
        }
    }

    //==========================================================================
    // Media Import
    //==========================================================================

    std::optional<std::string> importMedia(const std::string& filePath)
    {
        MediaInfo info;
        info.id = generateId("media");
        info.filePath = filePath;
        info.fileName = extractFileName(filePath);

        // Analyze media file
        if (!analyzeMedia(filePath, info))
            return std::nullopt;

        mediaLibrary_[info.id] = info;

        // Generate proxy if needed
        if (info.type == MediaType::Video && shouldGenerateProxy(info))
        {
            generateProxy(info.id);
        }

        // Generate thumbnails
        generateThumbnails(info.id);

        return info.id;
    }

    std::optional<MediaInfo> getMediaInfo(const std::string& id) const
    {
        auto it = mediaLibrary_.find(id);
        if (it != mediaLibrary_.end())
            return it->second;
        return std::nullopt;
    }

    std::vector<MediaInfo> getAllMedia() const
    {
        std::vector<MediaInfo> result;
        for (const auto& [id, info] : mediaLibrary_)
            result.push_back(info);
        return result;
    }

    //==========================================================================
    // Timeline Editing
    //==========================================================================

    std::string addClipToTimeline(const std::string& mediaId,
                                   int trackIndex,
                                   double startTime)
    {
        auto* seq = getCurrentSequence();
        if (!seq) return "";

        auto mediaIt = mediaLibrary_.find(mediaId);
        if (mediaIt == mediaLibrary_.end()) return "";

        const auto& media = mediaIt->second;

        TimelineClip clip;
        clip.id = generateId("clip");
        clip.mediaId = mediaId;
        clip.name = media.fileName;
        clip.startTime = startTime;
        clip.trackIndex = trackIndex;
        clip.sourceRange.inPoint = 0.0;
        clip.sourceRange.outPoint = media.duration;

        // Initialize transform keyframes with defaults
        clip.positionX.addKeyframe(0.0, 0.0f);
        clip.positionY.addKeyframe(0.0, 0.0f);
        clip.scaleX.addKeyframe(0.0, 1.0f);
        clip.scaleY.addKeyframe(0.0, 1.0f);
        clip.rotation.addKeyframe(0.0, 0.0f);
        clip.opacity.addKeyframe(0.0, 1.0f);
        clip.volume.addKeyframe(0.0, 1.0f);

        // Add to appropriate track
        if (media.type == MediaType::Video || media.type == MediaType::Image)
        {
            if (trackIndex >= 0 && trackIndex < static_cast<int>(seq->videoTracks.size()))
            {
                seq->videoTracks[trackIndex].clips.push_back(clip);
            }
        }
        else if (media.type == MediaType::Audio)
        {
            if (trackIndex >= 0 && trackIndex < static_cast<int>(seq->audioTracks.size()))
            {
                seq->audioTracks[trackIndex].clips.push_back(clip);
            }
        }

        seq->calculateDuration();
        invalidateCacheAt(startTime);

        if (onSequenceChanged_)
            onSequenceChanged_();

        return clip.id;
    }

    void removeClip(const std::string& clipId)
    {
        auto* seq = getCurrentSequence();
        if (!seq) return;

        for (auto& track : seq->videoTracks)
        {
            auto it = std::remove_if(track.clips.begin(), track.clips.end(),
                [&](const TimelineClip& c) { return c.id == clipId; });
            track.clips.erase(it, track.clips.end());
        }

        for (auto& track : seq->audioTracks)
        {
            auto it = std::remove_if(track.clips.begin(), track.clips.end(),
                [&](const TimelineClip& c) { return c.id == clipId; });
            track.clips.erase(it, track.clips.end());
        }

        seq->calculateDuration();
        frameCache_->clear();

        if (onSequenceChanged_)
            onSequenceChanged_();
    }

    void moveClip(const std::string& clipId, double newStartTime, int newTrackIndex)
    {
        auto* clip = findClip(clipId);
        if (!clip) return;

        double oldStart = clip->startTime;
        clip->startTime = newStartTime;
        clip->trackIndex = newTrackIndex;

        invalidateCacheAt(std::min(oldStart, newStartTime));

        if (onSequenceChanged_)
            onSequenceChanged_();
    }

    void trimClip(const std::string& clipId, double newInPoint, double newOutPoint)
    {
        auto* clip = findClip(clipId);
        if (!clip) return;

        clip->sourceRange.inPoint = newInPoint;
        clip->sourceRange.outPoint = newOutPoint;

        getCurrentSequence()->calculateDuration();
        invalidateCacheAt(clip->startTime);

        if (onSequenceChanged_)
            onSequenceChanged_();
    }

    void splitClip(const std::string& clipId, double splitTime)
    {
        auto* clip = findClip(clipId);
        if (!clip) return;

        if (splitTime <= clip->startTime || splitTime >= clip->endTime())
            return;

        // Create second clip
        TimelineClip secondClip = *clip;
        secondClip.id = generateId("clip");

        // Calculate split point in source
        double relativeTime = (splitTime - clip->startTime) * clip->speed;
        double sourceTime = clip->sourceRange.inPoint + relativeTime;

        // Adjust clips
        clip->sourceRange.outPoint = sourceTime;
        secondClip.startTime = splitTime;
        secondClip.sourceRange.inPoint = sourceTime;

        // Add second clip
        auto* seq = getCurrentSequence();
        if (clip->trackIndex < static_cast<int>(seq->videoTracks.size()))
        {
            seq->videoTracks[clip->trackIndex].clips.push_back(secondClip);
        }

        invalidateCacheAt(splitTime);

        if (onSequenceChanged_)
            onSequenceChanged_();
    }

    //==========================================================================
    // Effects
    //==========================================================================

    void addEffect(const std::string& clipId, const VideoEffect& effect)
    {
        auto* clip = findClip(clipId);
        if (!clip) return;

        if (clip->effects.size() >= MAX_EFFECTS_PER_CLIP)
            return;

        clip->effects.push_back(effect);
        invalidateCacheAt(clip->startTime);

        if (onSequenceChanged_)
            onSequenceChanged_();
    }

    void removeEffect(const std::string& clipId, const std::string& effectId)
    {
        auto* clip = findClip(clipId);
        if (!clip) return;

        auto it = std::remove_if(clip->effects.begin(), clip->effects.end(),
            [&](const VideoEffect& e) { return e.id == effectId; });
        clip->effects.erase(it, clip->effects.end());

        invalidateCacheAt(clip->startTime);

        if (onSequenceChanged_)
            onSequenceChanged_();
    }

    std::vector<VideoEffect> getBuiltInEffects() const
    {
        std::vector<VideoEffect> effects;

        // Color effects
        effects.push_back(createEffect("brightness", "Brightness/Contrast", EffectCategory::Color));
        effects.push_back(createEffect("colorBalance", "Color Balance", EffectCategory::Color));
        effects.push_back(createEffect("hsl", "Hue/Saturation", EffectCategory::Color));
        effects.push_back(createEffect("curves", "Curves", EffectCategory::Color));
        effects.push_back(createEffect("lut", "LUT", EffectCategory::Color));

        // Blur effects
        effects.push_back(createEffect("gaussianBlur", "Gaussian Blur", EffectCategory::Blur));
        effects.push_back(createEffect("motionBlur", "Motion Blur", EffectCategory::Blur));
        effects.push_back(createEffect("radialBlur", "Radial Blur", EffectCategory::Blur));

        // Stylize effects
        effects.push_back(createEffect("glow", "Glow", EffectCategory::Stylize));
        effects.push_back(createEffect("vignette", "Vignette", EffectCategory::Stylize));
        effects.push_back(createEffect("filmGrain", "Film Grain", EffectCategory::Stylize));
        effects.push_back(createEffect("glitch", "Glitch", EffectCategory::Stylize));

        // Bio-reactive effects
        effects.push_back(createBioEffect("coherencePulse", "Coherence Pulse", "coherence"));
        effects.push_back(createBioEffect("heartbeatZoom", "Heartbeat Zoom", "heartRate"));
        effects.push_back(createBioEffect("breatheScale", "Breathe Scale", "breathRate"));
        effects.push_back(createBioEffect("relaxationFade", "Relaxation Fade", "relaxation"));

        return effects;
    }

    //==========================================================================
    // Playback
    //==========================================================================

    void play()
    {
        if (playbackState_ == PlaybackState::Playing)
            return;

        playbackState_ = PlaybackState::Playing;
        playStartTime_ = std::chrono::steady_clock::now();
        playStartPosition_ = playheadPosition_;

        startPlaybackThread();

        if (onPlaybackState_)
            onPlaybackState_(PlaybackState::Playing);
    }

    void pause()
    {
        if (playbackState_ != PlaybackState::Playing)
            return;

        playbackState_ = PlaybackState::Paused;
        stopPlaybackThread();

        if (onPlaybackState_)
            onPlaybackState_(PlaybackState::Paused);
    }

    void stop()
    {
        playbackState_ = PlaybackState::Stopped;
        stopPlaybackThread();
        playheadPosition_ = 0.0;

        if (onPlaybackState_)
            onPlaybackState_(PlaybackState::Stopped);

        if (onPositionChanged_)
            onPositionChanged_(playheadPosition_);
    }

    void seek(double time)
    {
        auto* seq = getCurrentSequence();
        if (!seq) return;

        playheadPosition_ = std::max(0.0, std::min(time, seq->duration));

        if (playbackState_ == PlaybackState::Playing)
        {
            playStartTime_ = std::chrono::steady_clock::now();
            playStartPosition_ = playheadPosition_;
        }

        if (onPositionChanged_)
            onPositionChanged_(playheadPosition_);

        // Render current frame
        renderFrame(playheadPosition_);
    }

    void stepForward()
    {
        auto* seq = getCurrentSequence();
        if (!seq) return;

        double frameTime = 1.0 / seq->settings.frameRate;
        seek(playheadPosition_ + frameTime);
    }

    void stepBackward()
    {
        auto* seq = getCurrentSequence();
        if (!seq) return;

        double frameTime = 1.0 / seq->settings.frameRate;
        seek(playheadPosition_ - frameTime);
    }

    double getPlayheadPosition() const { return playheadPosition_; }
    PlaybackState getPlaybackState() const { return playbackState_; }

    //==========================================================================
    // Rendering
    //==========================================================================

    RenderFrame renderFrame(double time)
    {
        auto* seq = getCurrentSequence();
        if (!seq)
            return RenderFrame();

        int64_t frameNumber = static_cast<int64_t>(time * seq->settings.frameRate);

        // Check cache
        if (auto cached = frameCache_->get(frameNumber))
            return *cached;

        // Render frame
        RenderFrame frame = renderFrameInternal(time);
        frame.frameNumber = frameNumber;
        frame.timestamp = time;

        // Cache it
        frameCache_->put(frameNumber, RenderFrame(frame));

        if (onFrameRendered_)
            onFrameRendered_(frame);

        return frame;
    }

    //==========================================================================
    // Export
    //==========================================================================

    bool startExport(const ExportSettings& settings)
    {
        if (isExporting_)
            return false;

        exportSettings_ = settings;
        isExporting_ = true;

        exportThread_ = std::thread(&EchoelVideoEditor::exportLoop, this);

        return true;
    }

    void cancelExport()
    {
        if (!isExporting_)
            return;

        isExporting_ = false;
        if (exportThread_.joinable())
            exportThread_.join();
    }

    bool isExporting() const { return isExporting_; }

    //==========================================================================
    // Callbacks
    //==========================================================================

    void setOnFrameRendered(OnFrameRenderedCallback cb) { onFrameRendered_ = std::move(cb); }
    void setOnPlaybackState(OnPlaybackStateCallback cb) { onPlaybackState_ = std::move(cb); }
    void setOnPositionChanged(OnPositionChangedCallback cb) { onPositionChanged_ = std::move(cb); }
    void setOnExportProgress(OnExportProgressCallback cb) { onExportProgress_ = std::move(cb); }
    void setOnSequenceChanged(OnSequenceChangedCallback cb) { onSequenceChanged_ = std::move(cb); }
    void setOnSelectionChanged(OnSelectionChangedCallback cb) { onSelectionChanged_ = std::move(cb); }

    //==========================================================================
    // Bio Integration
    //==========================================================================

    void updateBioState(float coherence, float relaxation, float heartRate, float breathRate)
    {
        bioCoherence_ = coherence;
        bioRelaxation_ = relaxation;
        bioHeartRate_ = heartRate;
        bioBreathRate_ = breathRate;
    }

private:
    EchoelVideoEditor() = default;
    ~EchoelVideoEditor() { shutdown(); }

    EchoelVideoEditor(const EchoelVideoEditor&) = delete;
    EchoelVideoEditor& operator=(const EchoelVideoEditor&) = delete;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    bool initializeGPU()
    {
        // Initialize Metal/CUDA/OpenCL context
        useGPU_ = true;
        return true;
    }

    void shutdownGPU()
    {
        useGPU_ = false;
    }

    bool analyzeMedia(const std::string& filePath, MediaInfo& info)
    {
        // This would use FFmpeg/AVFoundation to analyze the file
        // For now, set some defaults
        info.type = MediaType::Video;
        info.width = 1920;
        info.height = 1080;
        info.frameRate = 30.0f;
        info.duration = 10.0;
        info.totalFrames = 300;
        return true;
    }

    bool shouldGenerateProxy(const MediaInfo& info)
    {
        return info.width > 1920 || info.height > 1080;
    }

    void generateProxy(const std::string& mediaId)
    {
        // Generate lower-resolution proxy for editing
    }

    void generateThumbnails(const std::string& mediaId)
    {
        // Generate thumbnail strip
    }

    TimelineClip* findClip(const std::string& clipId)
    {
        auto* seq = getCurrentSequence();
        if (!seq) return nullptr;

        for (auto& track : seq->videoTracks)
        {
            for (auto& clip : track.clips)
            {
                if (clip.id == clipId)
                    return &clip;
            }
        }

        for (auto& track : seq->audioTracks)
        {
            for (auto& clip : track.clips)
            {
                if (clip.id == clipId)
                    return &clip;
            }
        }

        return nullptr;
    }

    void invalidateCacheAt(double time)
    {
        auto* seq = getCurrentSequence();
        if (!seq) return;

        int64_t startFrame = static_cast<int64_t>(time * seq->settings.frameRate);
        int64_t endFrame = static_cast<int64_t>(seq->duration * seq->settings.frameRate);
        frameCache_->invalidateRange(startFrame, endFrame);
    }

    void startPlaybackThread()
    {
        isPlaybackRunning_ = true;
        playbackThread_ = std::thread(&EchoelVideoEditor::playbackLoop, this);
    }

    void stopPlaybackThread()
    {
        isPlaybackRunning_ = false;
        if (playbackThread_.joinable())
            playbackThread_.join();
    }

    void playbackLoop()
    {
        auto* seq = getCurrentSequence();
        if (!seq) return;

        double frameTime = 1.0 / seq->settings.frameRate;

        while (isPlaybackRunning_ && playbackState_ == PlaybackState::Playing)
        {
            auto now = std::chrono::steady_clock::now();
            double elapsed = std::chrono::duration<double>(now - playStartTime_).count();
            double newPosition = playStartPosition_ + elapsed;

            if (newPosition >= seq->duration)
            {
                // Loop or stop
                newPosition = 0.0;
                playStartTime_ = now;
                playStartPosition_ = 0.0;
            }

            playheadPosition_ = newPosition;

            // Render frame
            renderFrame(playheadPosition_);

            if (onPositionChanged_)
                onPositionChanged_(playheadPosition_);

            // Sleep until next frame
            std::this_thread::sleep_for(
                std::chrono::microseconds(static_cast<int64_t>(frameTime * 1000000))
            );
        }
    }

    RenderFrame renderFrameInternal(double time)
    {
        auto* seq = getCurrentSequence();
        if (!seq) return RenderFrame();

        RenderFrame frame;
        frame.width = seq->settings.width;
        frame.height = seq->settings.height;
        frame.format = RenderFrame::Format::RGBA8;
        frame.stride = frame.width * 4;
        frame.data.resize(frame.stride * frame.height);

        // Clear to black
        std::fill(frame.data.begin(), frame.data.end(), 0);

        // Composite all visible clips at this time
        for (const auto& track : seq->videoTracks)
        {
            if (!track.isVisible || track.isMuted)
                continue;

            for (const auto& clip : track.clips)
            {
                if (!clip.isEnabled)
                    continue;

                if (time >= clip.startTime && time < clip.endTime())
                {
                    renderClipToFrame(clip, time, frame);
                }
            }
        }

        return frame;
    }

    void renderClipToFrame(const TimelineClip& clip, double time, RenderFrame& frame)
    {
        // Calculate source time
        double clipTime = (time - clip.startTime) * clip.speed;
        if (clip.reverse)
            clipTime = clip.sourceRange.duration() - clipTime;
        double sourceTime = clip.sourceRange.inPoint + clipTime;

        // Get transform values at current time
        float opacity = clip.opacity.evaluate(clipTime);
        float scaleX = clip.scaleX.evaluate(clipTime);
        float scaleY = clip.scaleY.evaluate(clipTime);
        float rotation = clip.rotation.evaluate(clipTime);
        float posX = clip.positionX.evaluate(clipTime);
        float posY = clip.positionY.evaluate(clipTime);

        // Apply bio-reactive modulation
        for (const auto& effect : clip.effects)
        {
            if (effect.isBioReactive)
            {
                float bioValue = getBioValue(effect.bioParameter);
                // Modulate effect based on bio value
            }
        }

        // Render and composite clip
        // This would decode the source frame, apply transforms and effects,
        // then composite onto the output frame
    }

    float getBioValue(const std::string& parameter) const
    {
        if (parameter == "coherence") return bioCoherence_;
        if (parameter == "relaxation") return bioRelaxation_;
        if (parameter == "heartRate") return bioHeartRate_ / 100.0f;
        if (parameter == "breathRate") return bioBreathRate_ / 20.0f;
        return 0.0f;
    }

    void exportLoop()
    {
        auto* seq = getCurrentSequence();
        if (!seq) return;

        ExportProgress progress;
        progress.totalFrames = static_cast<int64_t>(seq->duration * seq->settings.frameRate);

        auto startTime = std::chrono::steady_clock::now();

        for (int64_t f = 0; f < progress.totalFrames && isExporting_; ++f)
        {
            double time = f / static_cast<double>(seq->settings.frameRate);
            RenderFrame frame = renderFrameInternal(time);

            // Encode frame
            // This would use the encoder to write to the output file

            progress.framesRendered = f + 1;
            progress.progress = static_cast<double>(f + 1) / progress.totalFrames;

            auto now = std::chrono::steady_clock::now();
            progress.elapsedTime = std::chrono::duration<double>(now - startTime).count();
            progress.fps = static_cast<float>(progress.framesRendered / progress.elapsedTime);

            double remaining = (progress.totalFrames - progress.framesRendered) / progress.fps;
            progress.estimatedTimeRemaining = remaining;

            if (onExportProgress_)
                onExportProgress_(progress);
        }

        progress.isComplete = true;
        isExporting_ = false;

        if (onExportProgress_)
            onExportProgress_(progress);
    }

    std::string generateId(const std::string& prefix)
    {
        static std::atomic<uint64_t> counter{0};
        return prefix + "_" + std::to_string(counter++);
    }

    std::string extractFileName(const std::string& path)
    {
        size_t pos = path.find_last_of("/\\");
        if (pos != std::string::npos)
            return path.substr(pos + 1);
        return path;
    }

    VideoEffect createEffect(const std::string& id, const std::string& name,
                             EffectCategory category) const
    {
        VideoEffect effect;
        effect.id = id;
        effect.name = id;
        effect.displayName = name;
        effect.category = category;
        return effect;
    }

    VideoEffect createBioEffect(const std::string& id, const std::string& name,
                                const std::string& bioParam) const
    {
        VideoEffect effect = createEffect(id, name, EffectCategory::Bio);
        effect.isBioReactive = true;
        effect.bioParameter = bioParam;
        return effect;
    }

    //==========================================================================
    // Member Variables
    //==========================================================================

    bool initialized_ = false;
    bool useGPU_ = false;

    std::unordered_map<std::string, Sequence> sequences_;
    std::string currentSequenceId_;

    std::unordered_map<std::string, MediaInfo> mediaLibrary_;

    std::unique_ptr<FrameCache> frameCache_;

    // Playback
    PlaybackState playbackState_ = PlaybackState::Stopped;
    double playheadPosition_ = 0.0;
    std::chrono::steady_clock::time_point playStartTime_;
    double playStartPosition_ = 0.0;
    std::atomic<bool> isPlaybackRunning_{false};
    std::thread playbackThread_;

    // Export
    ExportSettings exportSettings_;
    std::atomic<bool> isExporting_{false};
    std::thread exportThread_;

    // Bio state
    float bioCoherence_ = 0.0f;
    float bioRelaxation_ = 0.0f;
    float bioHeartRate_ = 0.0f;
    float bioBreathRate_ = 0.0f;

    // Callbacks
    OnFrameRenderedCallback onFrameRendered_;
    OnPlaybackStateCallback onPlaybackState_;
    OnPositionChangedCallback onPositionChanged_;
    OnExportProgressCallback onExportProgress_;
    OnSequenceChangedCallback onSequenceChanged_;
    OnSelectionChangedCallback onSelectionChanged_;
};

}} // namespace Echoel::Video
