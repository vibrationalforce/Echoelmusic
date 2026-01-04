/*
  ==============================================================================

    VideoEditEngine.h
    Echoelmusic - Bio-Reactive DAW

    Comprehensive Video Editing Engine with AI-powered features
    Non-linear editing, effects, transitions, and music sync

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include "../Core/RalphWiggumAPI.h"
#include <memory>
#include <vector>
#include <map>
#include <mutex>
#include <atomic>
#include <thread>
#include <queue>
#include <functional>

namespace Echoel {
namespace Video {

//==============================================================================
/**
    Video clip representation
*/
struct VideoClip
{
    juce::String id;
    juce::String name;
    juce::File sourceFile;

    // Timing
    double sourceIn = 0.0;           // In point in source (seconds)
    double sourceOut = 0.0;          // Out point in source (seconds)
    double timelineStart = 0.0;      // Position on timeline (seconds)
    double duration = 0.0;           // Duration on timeline

    // Track
    int trackIndex = 0;

    // Transform
    float scaleX = 1.0f;
    float scaleY = 1.0f;
    float rotation = 0.0f;           // Degrees
    float positionX = 0.0f;          // -1 to 1
    float positionY = 0.0f;
    float opacity = 1.0f;

    // Speed
    float playbackSpeed = 1.0f;
    bool reversePlayback = false;

    // Color
    float brightness = 0.0f;         // -1 to 1
    float contrast = 0.0f;
    float saturation = 0.0f;
    float hue = 0.0f;                // -180 to 180

    // Blend
    enum class BlendMode
    {
        Normal,
        Add,
        Multiply,
        Screen,
        Overlay,
        Difference
    };
    BlendMode blendMode = BlendMode::Normal;

    // Audio
    bool hasAudio = false;
    float audioVolume = 1.0f;
    bool audioMuted = false;

    VideoClip() : id(juce::Uuid().toString()) {}
};

//==============================================================================
/**
    Video effect
*/
struct VideoEffect
{
    enum class Type
    {
        // Color
        ColorCorrection,
        LUT,
        ChromaKey,
        ColorBalance,

        // Blur/Sharpen
        GaussianBlur,
        MotionBlur,
        Sharpen,

        // Distortion
        Lens,
        Wave,
        Twirl,
        Bulge,

        // Stylize
        Glow,
        Vignette,
        FilmGrain,
        Pixelate,
        Posterize,

        // Time
        Echo,
        MotionTrail,

        // AI
        AIStyleTransfer,
        AIUpscale,
        AIDenoiser,
        AIBackgroundRemove,

        // Bio-Reactive
        BioReactiveGlow,
        BioReactiveDistort,
        CoherenceVignette
    };

    juce::String id;
    Type type;
    juce::String name;
    bool enabled = true;
    std::map<juce::String, float> parameters;

    VideoEffect() : id(juce::Uuid().toString()) {}
};

//==============================================================================
/**
    Video transition
*/
struct VideoTransition
{
    enum class Type
    {
        Cut,
        CrossDissolve,
        Fade,
        Wipe,
        Slide,
        Zoom,
        Spin,
        Blur,
        Glitch,
        BioReactiveFlow,
        AudioReactiveBeat
    };

    juce::String id;
    Type type;
    double duration = 0.5;           // Seconds
    float progress = 0.0f;
    bool audioSync = false;          // Sync to beat

    VideoTransition() : id(juce::Uuid().toString()) {}
};

//==============================================================================
/**
    Video track
*/
struct VideoTrack
{
    juce::String id;
    juce::String name;
    bool visible = true;
    bool locked = false;
    float opacity = 1.0f;
    VideoClip::BlendMode blendMode = VideoClip::BlendMode::Normal;
    std::vector<juce::String> clipIds;
    std::vector<VideoEffect> trackEffects;

    VideoTrack() : id(juce::Uuid().toString()) {}
};

//==============================================================================
/**
    Keyframe for animation
*/
struct Keyframe
{
    double time = 0.0;
    float value = 0.0f;

    enum class Interpolation
    {
        Linear,
        EaseIn,
        EaseOut,
        EaseInOut,
        Bezier,
        Hold
    };
    Interpolation interpolation = Interpolation::Linear;

    // Bezier handles
    float handleInX = -0.1f;
    float handleInY = 0.0f;
    float handleOutX = 0.1f;
    float handleOutY = 0.0f;
};

//==============================================================================
/**
    Animation property
*/
struct AnimationProperty
{
    juce::String targetClipId;
    juce::String propertyName;       // "positionX", "opacity", etc.
    std::vector<Keyframe> keyframes;

    float getValueAtTime(double time) const
    {
        if (keyframes.empty())
            return 0.0f;

        if (keyframes.size() == 1)
            return keyframes[0].value;

        // Find surrounding keyframes
        const Keyframe* before = nullptr;
        const Keyframe* after = nullptr;

        for (const auto& kf : keyframes)
        {
            if (kf.time <= time)
                before = &kf;
            if (kf.time >= time && !after)
                after = &kf;
        }

        if (!before)
            return keyframes.front().value;
        if (!after)
            return keyframes.back().value;
        if (before == after)
            return before->value;

        // Interpolate
        double t = (time - before->time) / (after->time - before->time);

        switch (before->interpolation)
        {
            case Keyframe::Interpolation::Linear:
                return before->value + static_cast<float>(t) * (after->value - before->value);

            case Keyframe::Interpolation::EaseIn:
                t = t * t;
                return before->value + static_cast<float>(t) * (after->value - before->value);

            case Keyframe::Interpolation::EaseOut:
                t = 1.0 - (1.0 - t) * (1.0 - t);
                return before->value + static_cast<float>(t) * (after->value - before->value);

            case Keyframe::Interpolation::EaseInOut:
                t = t < 0.5 ? 2.0 * t * t : 1.0 - std::pow(-2.0 * t + 2.0, 2.0) / 2.0;
                return before->value + static_cast<float>(t) * (after->value - before->value);

            case Keyframe::Interpolation::Hold:
                return before->value;

            default:
                return before->value + static_cast<float>(t) * (after->value - before->value);
        }
    }
};

//==============================================================================
/**
    Video project
*/
struct VideoProject
{
    juce::String id;
    juce::String name;

    // Resolution
    int width = 1920;
    int height = 1080;
    double frameRate = 30.0;

    // Timeline
    double duration = 0.0;

    // Tracks and clips
    std::vector<VideoTrack> tracks;
    std::map<juce::String, VideoClip> clips;
    std::vector<VideoTransition> transitions;
    std::vector<AnimationProperty> animations;

    // Master effects
    std::vector<VideoEffect> masterEffects;

    // Audio sync
    juce::File audioFile;
    bool audioSyncEnabled = false;

    VideoProject() : id(juce::Uuid().toString()) {}
};

//==============================================================================
/**
    Rendered video frame
*/
struct VideoFrame
{
    std::vector<uint8_t> pixels;     // RGBA
    int width = 0;
    int height = 0;
    double timestamp = 0.0;
    int frameNumber = 0;
};

//==============================================================================
/**
    Main Video Edit Engine
*/
class VideoEditEngine
{
public:
    //--------------------------------------------------------------------------
    static VideoEditEngine& getInstance()
    {
        static VideoEditEngine instance;
        return instance;
    }

    //--------------------------------------------------------------------------
    void initialize()
    {
        std::lock_guard<std::mutex> lock(engineMutex);

        if (initialized)
            return;

        // Start render thread
        renderRunning = true;
        renderThread = std::thread(&VideoEditEngine::renderLoop, this);

        // Start decode thread
        decodeRunning = true;
        decodeThread = std::thread(&VideoEditEngine::decodeLoop, this);

        initialized = true;
    }

    void shutdown()
    {
        renderRunning = false;
        decodeRunning = false;

        renderCondition.notify_all();
        decodeCondition.notify_all();

        if (renderThread.joinable())
            renderThread.join();
        if (decodeThread.joinable())
            decodeThread.join();

        initialized = false;
    }

    //--------------------------------------------------------------------------
    // Project management
    void newProject(int width, int height, double frameRate)
    {
        std::lock_guard<std::mutex> lock(engineMutex);

        project = VideoProject();
        project.width = width;
        project.height = height;
        project.frameRate = frameRate;

        // Add default video track
        VideoTrack track;
        track.name = "Video 1";
        project.tracks.push_back(track);
    }

    const VideoProject& getProject() const { return project; }

    void setProjectResolution(int width, int height)
    {
        std::lock_guard<std::mutex> lock(engineMutex);
        project.width = width;
        project.height = height;
    }

    //--------------------------------------------------------------------------
    // Clip management
    juce::String importClip(const juce::File& file)
    {
        std::lock_guard<std::mutex> lock(engineMutex);

        VideoClip clip;
        clip.sourceFile = file;
        clip.name = file.getFileNameWithoutExtension();

        // Analyze clip (would use FFmpeg in real implementation)
        clip.duration = 10.0;  // Placeholder
        clip.sourceOut = clip.duration;

        project.clips[clip.id] = clip;

        return clip.id;
    }

    void addClipToTimeline(const juce::String& clipId, int trackIndex, double startTime)
    {
        std::lock_guard<std::mutex> lock(engineMutex);

        auto it = project.clips.find(clipId);
        if (it != project.clips.end())
        {
            it->second.trackIndex = trackIndex;
            it->second.timelineStart = startTime;

            // Ensure track exists
            while (project.tracks.size() <= static_cast<size_t>(trackIndex))
            {
                VideoTrack track;
                track.name = "Video " + juce::String(project.tracks.size() + 1);
                project.tracks.push_back(track);
            }

            project.tracks[trackIndex].clipIds.push_back(clipId);

            // Update project duration
            double clipEnd = startTime + it->second.duration;
            if (clipEnd > project.duration)
                project.duration = clipEnd;
        }
    }

    void removeClip(const juce::String& clipId)
    {
        std::lock_guard<std::mutex> lock(engineMutex);

        auto it = project.clips.find(clipId);
        if (it != project.clips.end())
        {
            // Remove from track
            for (auto& track : project.tracks)
            {
                track.clipIds.erase(
                    std::remove(track.clipIds.begin(), track.clipIds.end(), clipId),
                    track.clipIds.end());
            }

            project.clips.erase(it);
        }
    }

    void moveClip(const juce::String& clipId, double newStartTime)
    {
        std::lock_guard<std::mutex> lock(engineMutex);

        auto it = project.clips.find(clipId);
        if (it != project.clips.end())
        {
            it->second.timelineStart = newStartTime;
        }
    }

    void trimClip(const juce::String& clipId, double sourceIn, double sourceOut)
    {
        std::lock_guard<std::mutex> lock(engineMutex);

        auto it = project.clips.find(clipId);
        if (it != project.clips.end())
        {
            it->second.sourceIn = sourceIn;
            it->second.sourceOut = sourceOut;
            it->second.duration = (sourceOut - sourceIn) / it->second.playbackSpeed;
        }
    }

    void splitClip(const juce::String& clipId, double splitTime)
    {
        std::lock_guard<std::mutex> lock(engineMutex);

        auto it = project.clips.find(clipId);
        if (it == project.clips.end())
            return;

        VideoClip& original = it->second;
        double relativeTime = splitTime - original.timelineStart;

        if (relativeTime <= 0 || relativeTime >= original.duration)
            return;

        // Create second clip
        VideoClip newClip = original;
        newClip.id = juce::Uuid().toString();
        newClip.name = original.name + " (2)";
        newClip.timelineStart = splitTime;
        newClip.sourceIn = original.sourceIn + relativeTime * original.playbackSpeed;
        newClip.duration = original.duration - relativeTime;

        // Trim original
        original.duration = relativeTime;
        original.sourceOut = original.sourceIn + relativeTime * original.playbackSpeed;

        // Add new clip
        project.clips[newClip.id] = newClip;
        project.tracks[original.trackIndex].clipIds.push_back(newClip.id);
    }

    //--------------------------------------------------------------------------
    // Effects
    void addEffectToClip(const juce::String& clipId, const VideoEffect& effect)
    {
        std::lock_guard<std::mutex> lock(engineMutex);

        auto it = project.clips.find(clipId);
        if (it != project.clips.end())
        {
            clipEffects[clipId].push_back(effect);
        }
    }

    void addMasterEffect(const VideoEffect& effect)
    {
        std::lock_guard<std::mutex> lock(engineMutex);
        project.masterEffects.push_back(effect);
    }

    void removeEffect(const juce::String& clipId, const juce::String& effectId)
    {
        std::lock_guard<std::mutex> lock(engineMutex);

        auto it = clipEffects.find(clipId);
        if (it != clipEffects.end())
        {
            it->second.erase(
                std::remove_if(it->second.begin(), it->second.end(),
                    [&effectId](const VideoEffect& e) { return e.id == effectId; }),
                it->second.end());
        }
    }

    //--------------------------------------------------------------------------
    // Transitions
    void addTransition(const juce::String& clipAId, const juce::String& clipBId,
                       const VideoTransition& transition)
    {
        std::lock_guard<std::mutex> lock(engineMutex);
        project.transitions.push_back(transition);
        transitionMap[{clipAId, clipBId}] = transition.id;
    }

    //--------------------------------------------------------------------------
    // Animation
    void addKeyframe(const juce::String& clipId, const juce::String& property,
                     const Keyframe& keyframe)
    {
        std::lock_guard<std::mutex> lock(engineMutex);

        // Find or create animation property
        AnimationProperty* anim = nullptr;
        for (auto& a : project.animations)
        {
            if (a.targetClipId == clipId && a.propertyName == property)
            {
                anim = &a;
                break;
            }
        }

        if (!anim)
        {
            AnimationProperty newAnim;
            newAnim.targetClipId = clipId;
            newAnim.propertyName = property;
            project.animations.push_back(newAnim);
            anim = &project.animations.back();
        }

        // Insert keyframe in sorted order
        auto insertPos = std::lower_bound(anim->keyframes.begin(), anim->keyframes.end(),
            keyframe.time, [](const Keyframe& kf, double t) { return kf.time < t; });

        anim->keyframes.insert(insertPos, keyframe);
    }

    //--------------------------------------------------------------------------
    // Playback
    void play()
    {
        isPlaying.store(true);
        playbackStartTime = std::chrono::steady_clock::now();
        playbackStartPosition = currentTime.load();
    }

    void pause()
    {
        isPlaying.store(false);
    }

    void stop()
    {
        isPlaying.store(false);
        currentTime.store(0.0);
    }

    void seek(double time)
    {
        currentTime.store(juce::jlimit(0.0, project.duration, time));
        if (isPlaying.load())
        {
            playbackStartTime = std::chrono::steady_clock::now();
            playbackStartPosition = currentTime.load();
        }
    }

    double getCurrentTime() const { return currentTime.load(); }
    bool getIsPlaying() const { return isPlaying.load(); }

    //--------------------------------------------------------------------------
    // Rendering
    VideoFrame renderFrame(double time)
    {
        std::lock_guard<std::mutex> lock(engineMutex);

        VideoFrame frame;
        frame.width = project.width;
        frame.height = project.height;
        frame.timestamp = time;
        frame.frameNumber = static_cast<int>(time * project.frameRate);
        frame.pixels.resize(frame.width * frame.height * 4, 0);

        // Composite all visible tracks (bottom to top)
        for (int i = static_cast<int>(project.tracks.size()) - 1; i >= 0; --i)
        {
            const auto& track = project.tracks[i];
            if (!track.visible)
                continue;

            for (const auto& clipId : track.clipIds)
            {
                auto it = project.clips.find(clipId);
                if (it == project.clips.end())
                    continue;

                const VideoClip& clip = it->second;

                // Check if clip is active at this time
                double clipEnd = clip.timelineStart + clip.duration;
                if (time < clip.timelineStart || time >= clipEnd)
                    continue;

                // Get source time
                double sourceTime = clip.sourceIn +
                    (time - clip.timelineStart) * clip.playbackSpeed;
                if (clip.reversePlayback)
                    sourceTime = clip.sourceOut - (time - clip.timelineStart) * clip.playbackSpeed;

                // Apply animations
                applyAnimations(clipId, time);

                // Render clip frame (simplified - actual would decode video)
                VideoFrame clipFrame = decodeFrame(clip, sourceTime);

                // Apply clip effects
                auto effectsIt = clipEffects.find(clipId);
                if (effectsIt != clipEffects.end())
                {
                    for (const auto& effect : effectsIt->second)
                    {
                        if (effect.enabled)
                            applyEffect(clipFrame, effect);
                    }
                }

                // Apply transform
                clipFrame = applyTransform(clipFrame, clip);

                // Composite onto main frame
                compositeFrame(frame, clipFrame, clip.blendMode, clip.opacity);
            }
        }

        // Apply master effects
        for (const auto& effect : project.masterEffects)
        {
            if (effect.enabled)
                applyEffect(frame, effect);
        }

        return frame;
    }

    void requestRender(double time)
    {
        {
            std::lock_guard<std::mutex> lock(renderMutex);
            renderQueue.push(time);
        }
        renderCondition.notify_one();
    }

    VideoFrame getRenderedFrame()
    {
        std::lock_guard<std::mutex> lock(frameMutex);
        return currentFrame;
    }

    //--------------------------------------------------------------------------
    // Export
    struct ExportSettings
    {
        juce::File outputFile;
        int width = 1920;
        int height = 1080;
        double frameRate = 30.0;
        juce::String codec = "h264";
        int bitrate = 10000000;      // 10 Mbps
        juce::String audioCodec = "aac";
        int audioBitrate = 256000;   // 256 kbps
    };

    void startExport(const ExportSettings& settings)
    {
        exportSettings = settings;
        exportProgress.store(0.0f);
        isExporting.store(true);

        exportThread = std::thread(&VideoEditEngine::exportLoop, this);
    }

    void cancelExport()
    {
        isExporting.store(false);
        if (exportThread.joinable())
            exportThread.join();
    }

    float getExportProgress() const { return exportProgress.load(); }
    bool getIsExporting() const { return isExporting.load(); }

    //--------------------------------------------------------------------------
    // Bio-reactive integration
    void updateBioState(float coherence, float hrv)
    {
        currentCoherence.store(coherence);
        currentHRV.store(hrv);
    }

    //--------------------------------------------------------------------------
    // Audio sync
    void setAudioAnalysis(const std::vector<float>& spectrum,
                          const std::vector<float>& waveform,
                          float bpm, bool beatDetected)
    {
        std::lock_guard<std::mutex> lock(audioMutex);
        audioSpectrum = spectrum;
        audioWaveform = waveform;
        currentBPM = bpm;
        this->beatDetected = beatDetected;
    }

    //--------------------------------------------------------------------------
    // Callbacks
    void setOnFrameRendered(std::function<void(const VideoFrame&)> callback)
    {
        onFrameRendered = callback;
    }

    void setOnExportComplete(std::function<void(bool)> callback)
    {
        onExportComplete = callback;
    }

private:
    VideoEditEngine() = default;
    ~VideoEditEngine() { shutdown(); }

    VideoEditEngine(const VideoEditEngine&) = delete;
    VideoEditEngine& operator=(const VideoEditEngine&) = delete;

    //--------------------------------------------------------------------------
    void renderLoop()
    {
        while (renderRunning)
        {
            double timeToRender = -1.0;

            {
                std::unique_lock<std::mutex> lock(renderMutex);
                renderCondition.wait(lock, [this] {
                    return !renderQueue.empty() || !renderRunning;
                });

                if (!renderRunning)
                    break;

                if (!renderQueue.empty())
                {
                    timeToRender = renderQueue.front();
                    renderQueue.pop();
                }
            }

            if (timeToRender >= 0)
            {
                VideoFrame frame = renderFrame(timeToRender);

                {
                    std::lock_guard<std::mutex> lock(frameMutex);
                    currentFrame = frame;
                }

                if (onFrameRendered)
                    onFrameRendered(frame);
            }

            // Update playback time
            if (isPlaying.load())
            {
                auto now = std::chrono::steady_clock::now();
                auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
                    now - playbackStartTime).count() / 1000.0;
                double newTime = playbackStartPosition + elapsed;

                if (newTime >= project.duration)
                {
                    isPlaying.store(false);
                    currentTime.store(0.0);
                }
                else
                {
                    currentTime.store(newTime);
                }

                // Queue next frame render
                requestRender(currentTime.load());
            }
        }
    }

    void decodeLoop()
    {
        while (decodeRunning)
        {
            {
                std::unique_lock<std::mutex> lock(decodeMutex);
                decodeCondition.wait_for(lock, std::chrono::milliseconds(100));
            }

            if (!decodeRunning)
                break;

            // Pre-decode upcoming frames (would use FFmpeg)
            // This is a placeholder for actual video decoding
        }
    }

    void exportLoop()
    {
        int totalFrames = static_cast<int>(project.duration * exportSettings.frameRate);

        for (int i = 0; i < totalFrames && isExporting.load(); ++i)
        {
            double time = i / exportSettings.frameRate;
            VideoFrame frame = renderFrame(time);

            // Encode frame (would use FFmpeg)
            // This is a placeholder

            exportProgress.store(static_cast<float>(i) / totalFrames);
        }

        bool success = isExporting.load();
        isExporting.store(false);

        if (onExportComplete)
            onExportComplete(success);
    }

    //--------------------------------------------------------------------------
    VideoFrame decodeFrame(const VideoClip& clip, double sourceTime)
    {
        VideoFrame frame;
        frame.width = project.width;
        frame.height = project.height;
        frame.timestamp = sourceTime;
        frame.pixels.resize(frame.width * frame.height * 4);

        // Placeholder - actual implementation would decode from video file
        // Fill with gradient based on time for visualization
        for (int y = 0; y < frame.height; ++y)
        {
            for (int x = 0; x < frame.width; ++x)
            {
                int idx = (y * frame.width + x) * 4;
                frame.pixels[idx] = static_cast<uint8_t>((x * 255) / frame.width);
                frame.pixels[idx + 1] = static_cast<uint8_t>((y * 255) / frame.height);
                frame.pixels[idx + 2] = static_cast<uint8_t>((sourceTime * 25) * 255) % 256;
                frame.pixels[idx + 3] = 255;
            }
        }

        return frame;
    }

    void applyAnimations(const juce::String& clipId, double time)
    {
        auto it = project.clips.find(clipId);
        if (it == project.clips.end())
            return;

        VideoClip& clip = it->second;

        for (const auto& anim : project.animations)
        {
            if (anim.targetClipId != clipId)
                continue;

            float value = anim.getValueAtTime(time);

            if (anim.propertyName == "positionX")
                clip.positionX = value;
            else if (anim.propertyName == "positionY")
                clip.positionY = value;
            else if (anim.propertyName == "scaleX")
                clip.scaleX = value;
            else if (anim.propertyName == "scaleY")
                clip.scaleY = value;
            else if (anim.propertyName == "rotation")
                clip.rotation = value;
            else if (anim.propertyName == "opacity")
                clip.opacity = value;
        }
    }

    void applyEffect(VideoFrame& frame, const VideoEffect& effect)
    {
        float coherence = currentCoherence.load();

        switch (effect.type)
        {
            case VideoEffect::Type::BioReactiveGlow:
            {
                float intensity = coherence * 0.5f;
                // Apply glow effect based on coherence
                for (size_t i = 0; i < frame.pixels.size(); i += 4)
                {
                    frame.pixels[i] = std::min(255, static_cast<int>(frame.pixels[i] * (1.0f + intensity)));
                    frame.pixels[i + 1] = std::min(255, static_cast<int>(frame.pixels[i + 1] * (1.0f + intensity)));
                    frame.pixels[i + 2] = std::min(255, static_cast<int>(frame.pixels[i + 2] * (1.0f + intensity)));
                }
                break;
            }

            case VideoEffect::Type::CoherenceVignette:
            {
                float vignetteStrength = 1.0f - coherence;
                int centerX = frame.width / 2;
                int centerY = frame.height / 2;
                float maxDist = std::sqrt(static_cast<float>(centerX * centerX + centerY * centerY));

                for (int y = 0; y < frame.height; ++y)
                {
                    for (int x = 0; x < frame.width; ++x)
                    {
                        float dx = static_cast<float>(x - centerX);
                        float dy = static_cast<float>(y - centerY);
                        float dist = std::sqrt(dx * dx + dy * dy) / maxDist;
                        float vignette = 1.0f - (dist * vignetteStrength);

                        int idx = (y * frame.width + x) * 4;
                        frame.pixels[idx] = static_cast<uint8_t>(frame.pixels[idx] * vignette);
                        frame.pixels[idx + 1] = static_cast<uint8_t>(frame.pixels[idx + 1] * vignette);
                        frame.pixels[idx + 2] = static_cast<uint8_t>(frame.pixels[idx + 2] * vignette);
                    }
                }
                break;
            }

            case VideoEffect::Type::GaussianBlur:
            {
                // Simplified box blur
                float radius = effect.parameters.count("radius") ? effect.parameters.at("radius") : 5.0f;
                // Apply blur (simplified)
                break;
            }

            case VideoEffect::Type::ColorCorrection:
            {
                float brightness = effect.parameters.count("brightness") ? effect.parameters.at("brightness") : 0.0f;
                float contrast = effect.parameters.count("contrast") ? effect.parameters.at("contrast") : 0.0f;
                float saturation = effect.parameters.count("saturation") ? effect.parameters.at("saturation") : 0.0f;

                for (size_t i = 0; i < frame.pixels.size(); i += 4)
                {
                    // Apply brightness
                    int r = static_cast<int>(frame.pixels[i]) + static_cast<int>(brightness * 255);
                    int g = static_cast<int>(frame.pixels[i + 1]) + static_cast<int>(brightness * 255);
                    int b = static_cast<int>(frame.pixels[i + 2]) + static_cast<int>(brightness * 255);

                    // Apply contrast
                    float factor = (1.0f + contrast);
                    r = static_cast<int>((r - 128) * factor + 128);
                    g = static_cast<int>((g - 128) * factor + 128);
                    b = static_cast<int>((b - 128) * factor + 128);

                    frame.pixels[i] = static_cast<uint8_t>(juce::jlimit(0, 255, r));
                    frame.pixels[i + 1] = static_cast<uint8_t>(juce::jlimit(0, 255, g));
                    frame.pixels[i + 2] = static_cast<uint8_t>(juce::jlimit(0, 255, b));
                }
                break;
            }

            default:
                break;
        }
    }

    VideoFrame applyTransform(const VideoFrame& source, const VideoClip& clip)
    {
        VideoFrame result = source;

        // Apply scale, rotation, position
        // This is simplified - actual implementation would use proper 2D transforms

        return result;
    }

    void compositeFrame(VideoFrame& dest, const VideoFrame& src,
                        VideoClip::BlendMode blendMode, float opacity)
    {
        for (size_t i = 0; i < dest.pixels.size(); i += 4)
        {
            float srcR = src.pixels[i] / 255.0f;
            float srcG = src.pixels[i + 1] / 255.0f;
            float srcB = src.pixels[i + 2] / 255.0f;
            float srcA = (src.pixels[i + 3] / 255.0f) * opacity;

            float dstR = dest.pixels[i] / 255.0f;
            float dstG = dest.pixels[i + 1] / 255.0f;
            float dstB = dest.pixels[i + 2] / 255.0f;

            float outR, outG, outB;

            switch (blendMode)
            {
                case VideoClip::BlendMode::Add:
                    outR = std::min(1.0f, dstR + srcR * srcA);
                    outG = std::min(1.0f, dstG + srcG * srcA);
                    outB = std::min(1.0f, dstB + srcB * srcA);
                    break;

                case VideoClip::BlendMode::Multiply:
                    outR = dstR * (1.0f - srcA) + dstR * srcR * srcA;
                    outG = dstG * (1.0f - srcA) + dstG * srcG * srcA;
                    outB = dstB * (1.0f - srcA) + dstB * srcB * srcA;
                    break;

                case VideoClip::BlendMode::Screen:
                    outR = 1.0f - (1.0f - dstR) * (1.0f - srcR * srcA);
                    outG = 1.0f - (1.0f - dstG) * (1.0f - srcG * srcA);
                    outB = 1.0f - (1.0f - dstB) * (1.0f - srcB * srcA);
                    break;

                default:  // Normal
                    outR = dstR * (1.0f - srcA) + srcR * srcA;
                    outG = dstG * (1.0f - srcA) + srcG * srcA;
                    outB = dstB * (1.0f - srcA) + srcB * srcA;
                    break;
            }

            dest.pixels[i] = static_cast<uint8_t>(outR * 255);
            dest.pixels[i + 1] = static_cast<uint8_t>(outG * 255);
            dest.pixels[i + 2] = static_cast<uint8_t>(outB * 255);
        }
    }

    //--------------------------------------------------------------------------
    mutable std::mutex engineMutex;
    mutable std::mutex renderMutex;
    mutable std::mutex decodeMutex;
    mutable std::mutex frameMutex;
    mutable std::mutex audioMutex;

    std::condition_variable renderCondition;
    std::condition_variable decodeCondition;

    bool initialized = false;
    std::atomic<bool> renderRunning{false};
    std::atomic<bool> decodeRunning{false};
    std::thread renderThread;
    std::thread decodeThread;

    VideoProject project;
    std::map<juce::String, std::vector<VideoEffect>> clipEffects;
    std::map<std::pair<juce::String, juce::String>, juce::String> transitionMap;

    std::queue<double> renderQueue;
    VideoFrame currentFrame;

    // Playback
    std::atomic<double> currentTime{0.0};
    std::atomic<bool> isPlaying{false};
    std::chrono::steady_clock::time_point playbackStartTime;
    double playbackStartPosition = 0.0;

    // Export
    std::atomic<bool> isExporting{false};
    std::atomic<float> exportProgress{0.0f};
    ExportSettings exportSettings;
    std::thread exportThread;

    // Bio-reactive
    std::atomic<float> currentCoherence{0.5f};
    std::atomic<float> currentHRV{50.0f};

    // Audio sync
    std::vector<float> audioSpectrum;
    std::vector<float> audioWaveform;
    float currentBPM = 120.0f;
    bool beatDetected = false;

    // Callbacks
    std::function<void(const VideoFrame&)> onFrameRendered;
    std::function<void(bool)> onExportComplete;
};

} // namespace Video
} // namespace Echoel
