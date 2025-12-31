#include "VideoWeaver.h"
#include "../Core/DSPOptimizations.h"
#include <algorithm>
#include <cmath>

//==============================================================================
// Constructor / Destructor
//==============================================================================

VideoWeaver::VideoWeaver()
{
    // Initialize with default HD resolution
    projectWidth = 1920;
    projectHeight = 1080;
    frameRate = 30.0;
    totalDuration = 60.0;

    playbackPosition = 0.0;
    playing = false;

    bioReactiveEnabled = false;
    bioHRV = 0.5f;
    bioCoherence = 0.5f;

    hdrMode = HDRMode::SDR;

    DBG("VideoWeaver: Professional video editor initialized");
    DBG("Resolution: " << projectWidth << "x" << projectHeight);
    DBG("Frame rate: " << frameRate << " fps");
}

//==============================================================================
// Project Settings
//==============================================================================

void VideoWeaver::setResolution(int width, int height)
{
    if (width <= 0 || height <= 0)
    {
        DBG("VideoWeaver: Invalid resolution " << width << "x" << height);
        return;
    }

    projectWidth = width;
    projectHeight = height;

    DBG("VideoWeaver: Resolution set to " << width << "x" << height);

    // Common resolutions:
    // 8K: 7680x4320
    // 4K UHD: 3840x2160
    // 4K DCI: 4096x2160
    // 1080p: 1920x1080
    // 720p: 1280x720
    // Instagram Square: 1080x1080
    // Instagram Story: 1080x1920
    // TikTok: 1080x1920
}

void VideoWeaver::getResolution(int& width, int& height) const
{
    width = projectWidth;
    height = projectHeight;
}

void VideoWeaver::setFrameRate(double fps)
{
    if (fps <= 0.0)
    {
        DBG("VideoWeaver: Invalid frame rate " << fps);
        return;
    }

    frameRate = fps;
    DBG("VideoWeaver: Frame rate set to " << fps << " fps");

    // Common frame rates:
    // 23.976 (24p for film)
    // 24.0 (cinema)
    // 25.0 (PAL)
    // 29.97 (NTSC)
    // 30.0 (HD)
    // 50.0 (PAL high frame rate)
    // 59.94 (NTSC high frame rate)
    // 60.0 (HD high frame rate)
    // 120.0 (high-speed)
}

void VideoWeaver::setDuration(double seconds)
{
    if (seconds < 0.0)
    {
        DBG("VideoWeaver: Invalid duration " << seconds);
        return;
    }

    totalDuration = seconds;
    DBG("VideoWeaver: Duration set to " << seconds << " seconds");
}

//==============================================================================
// Clip Management
//==============================================================================

int VideoWeaver::addClip(const Clip& clip)
{
    clips.push_back(clip);
    int index = static_cast<int>(clips.size()) - 1;

    DBG("VideoWeaver: Clip added at index " << index);
    DBG("  Name: " << clip.name);
    DBG("  Type: " << (int)clip.type);
    DBG("  Track: " << clip.trackIndex);
    DBG("  Start: " << clip.startTime << "s");
    DBG("  Duration: " << clip.duration << "s");

    return index;
}

VideoWeaver::Clip& VideoWeaver::getClip(int index)
{
    if (index < 0 || index >= static_cast<int>(clips.size()))
    {
        DBG("VideoWeaver: Invalid clip index " << index);
        static Clip dummy;
        return dummy;
    }

    return clips[index];
}

const VideoWeaver::Clip& VideoWeaver::getClip(int index) const
{
    if (index < 0 || index >= static_cast<int>(clips.size()))
    {
        DBG("VideoWeaver: Invalid clip index " << index);
        static Clip dummy;
        return dummy;
    }

    return clips[index];
}

void VideoWeaver::setClip(int index, const Clip& clip)
{
    if (index < 0 || index >= static_cast<int>(clips.size()))
    {
        DBG("VideoWeaver: Invalid clip index " << index);
        return;
    }

    clips[index] = clip;
    DBG("VideoWeaver: Clip " << index << " updated");
}

void VideoWeaver::removeClip(int index)
{
    if (index < 0 || index >= static_cast<int>(clips.size()))
    {
        DBG("VideoWeaver: Invalid clip index " << index);
        return;
    }

    clips.erase(clips.begin() + index);

    // Remove associated transition if exists
    transitions.erase(index);

    DBG("VideoWeaver: Clip " << index << " removed");
}

void VideoWeaver::clearClips()
{
    clips.clear();
    transitions.clear();
    DBG("VideoWeaver: All clips cleared");
}

//==============================================================================
// AI-Powered Editing
//==============================================================================

void VideoWeaver::autoEditToBeat(const juce::File& audioFile, double clipDuration)
{
    if (!audioFile.existsAsFile())
    {
        DBG("VideoWeaver: Audio file not found: " << audioFile.getFullPathName());
        return;
    }

    DBG("VideoWeaver: Auto-editing to beat");
    DBG("  Audio file: " << audioFile.getFileName());
    DBG("  Clip duration: " << clipDuration << "s");

    // Detect beats in audio
    std::vector<double> beatTimes = detectBeats(audioFile);

    DBG("  Detected " << beatTimes.size() << " beats");

    // Create clips at each beat
    for (size_t i = 0; i < beatTimes.size(); ++i)
    {
        Clip clip;
        clip.type = Clip::Type::Video;
        clip.name = "Beat Clip " + juce::String(i + 1);
        clip.startTime = beatTimes[i];
        clip.duration = clipDuration;
        clip.trackIndex = 0;

        addClip(clip);

        // Add fade transition
        if (i > 0)
        {
            Transition trans;
            trans.type = Transition::Type::Fade;
            trans.duration = 0.5;
            addTransition(static_cast<int>(i), trans);
        }
    }

    DBG("  Created " << beatTimes.size() << " beat-synced clips");
}

void VideoWeaver::detectScenes(const juce::File& videoFile)
{
    if (!videoFile.existsAsFile())
    {
        DBG("VideoWeaver: Video file not found: " << videoFile.getFullPathName());
        return;
    }

    DBG("VideoWeaver: Detecting scenes");
    DBG("  Video file: " << videoFile.getFileName());

    // Detect scene changes
    std::vector<double> sceneTimes = detectSceneChanges(videoFile);

    DBG("  Detected " << sceneTimes.size() << " scene changes");

    // Create clips for each scene
    for (size_t i = 0; i < sceneTimes.size(); ++i)
    {
        Clip clip;
        clip.type = Clip::Type::Video;
        clip.name = "Scene " + juce::String(i + 1);
        clip.sourceFile = videoFile;
        clip.startTime = sceneTimes[i];
        clip.trackIndex = 0;

        // Calculate duration (to next scene or end)
        if (i < sceneTimes.size() - 1)
            clip.duration = sceneTimes[i + 1] - sceneTimes[i];
        else
            clip.duration = 5.0; // Default 5 seconds for last scene

        addClip(clip);
    }

    DBG("  Created " << sceneTimes.size() << " scene clips");
}

void VideoWeaver::smartReframe(int targetWidth, int targetHeight)
{
    DBG("VideoWeaver: Smart reframing");
    DBG("  Target resolution: " << targetWidth << "x" << targetHeight);
    DBG("  Current resolution: " << projectWidth << "x" << projectHeight);

    float targetAspect = static_cast<float>(targetWidth) / targetHeight;
    float currentAspect = static_cast<float>(projectWidth) / projectHeight;

    DBG("  Target aspect: " << targetAspect);
    DBG("  Current aspect: " << currentAspect);

    // AI-powered content-aware reframing
    // This would analyze each frame to find the most important content
    // and intelligently crop/pan to keep it in frame

    for (auto& clip : clips)
    {
        if (clip.type == Clip::Type::Video || clip.type == Clip::Type::Image)
        {
            // Calculate scale to fit
            float scaleX = static_cast<float>(targetWidth) / projectWidth;
            float scaleY = static_cast<float>(targetHeight) / projectHeight;

            if (targetAspect < currentAspect)
            {
                // Target is taller (e.g., 16:9 -> 9:16)
                // Scale to fit height, crop width
                clip.scaleX = scaleY;
                clip.scaleY = scaleY;

                // Center horizontally (AI would track faces/action)
                clip.x = (targetWidth - projectWidth * scaleY) / 2.0f;
            }
            else
            {
                // Target is wider
                // Scale to fit width, crop height
                clip.scaleX = scaleX;
                clip.scaleY = scaleX;

                // Center vertically (AI would track faces/action)
                clip.y = (targetHeight - projectHeight * scaleX) / 2.0f;
            }

            DBG("  Reframed clip: " << clip.name);
            DBG("    Scale: " << clip.scaleX << ", " << clip.scaleY);
            DBG("    Position: " << clip.x << ", " << clip.y);
        }
    }

    // Update project resolution
    setResolution(targetWidth, targetHeight);

    DBG("  Smart reframe complete");
}

std::vector<VideoWeaver::Clip> VideoWeaver::generateHighlights(double targetDuration)
{
    DBG("VideoWeaver: Generating highlights");
    DBG("  Target duration: " << targetDuration << "s");

    std::vector<Clip> highlights;

    // AI-powered highlight detection
    // This would analyze:
    // - Audio loudness peaks
    // - Motion intensity
    // - Face detection (emotions, reactions)
    // - Scene complexity
    // - User engagement data (if available)

    // For now, simple implementation: take clips with highest "score"
    struct ClipScore
    {
        int index;
        float score;
    };

    std::vector<ClipScore> scored;

    for (int i = 0; i < static_cast<int>(clips.size()); ++i)
    {
        const auto& clip = clips[i];

        // Simple scoring based on clip properties
        float score = 0.0f;

        // Prefer clips with effects (likely important)
        score += clip.effects.size() * 10.0f;

        // Prefer clips with color grading (likely important)
        if (std::abs(clip.brightness) > 0.1f) score += 5.0f;
        if (std::abs(clip.saturation) > 0.1f) score += 5.0f;

        // Prefer clips with transformations (action)
        if (clip.rotation != 0.0f) score += 10.0f;
        if (clip.scaleX != 1.0f || clip.scaleY != 1.0f) score += 5.0f;

        // Random component (simulate AI analysis)
        score += juce::Random::getSystemRandom().nextFloat() * 20.0f;

        scored.push_back({i, score});
    }

    // Sort by score (highest first)
    std::sort(scored.begin(), scored.end(),
              [](const ClipScore& a, const ClipScore& b) { return a.score > b.score; });

    // Select top clips until target duration is reached
    double currentDuration = 0.0;

    for (const auto& cs : scored)
    {
        if (currentDuration >= targetDuration)
            break;

        const auto& clip = clips[cs.index];
        highlights.push_back(clip);
        currentDuration += clip.duration;

        DBG("  Added highlight: " << clip.name << " (score: " << cs.score << ")");
    }

    DBG("  Generated " << highlights.size() << " highlights");
    DBG("  Total duration: " << currentDuration << "s");

    return highlights;
}

//==============================================================================
// Color Grading
//==============================================================================

void VideoWeaver::setColorPreset(const ColorPreset& preset)
{
    currentColorPreset = preset;

    DBG("VideoWeaver: Color preset applied: " << preset.name);

    // Apply to all clips
    for (auto& clip : clips)
    {
        if (clip.type == Clip::Type::Video || clip.type == Clip::Type::Image)
        {
            // LUT would be applied during rendering
            DBG("  Applied to clip: " << clip.name);
        }
    }
}

void VideoWeaver::applyLUT(const juce::File& lutFile)
{
    if (!lutFile.existsAsFile())
    {
        DBG("VideoWeaver: LUT file not found: " << lutFile.getFullPathName());
        return;
    }

    currentColorPreset.lutFile = lutFile;

    DBG("VideoWeaver: LUT loaded: " << lutFile.getFileName());

    // LUT formats:
    // - .cube (most common)
    // - .3dl (Autodesk)
    // - .lut (various)
    // - .png (Hald CLUT)

    // LUT would be parsed and applied during rendering
}

void VideoWeaver::setBioReactiveColorGrading(bool enabled)
{
    bioReactiveEnabled = enabled;

    DBG("VideoWeaver: Bio-reactive color grading "
        << (enabled ? "enabled" : "disabled"));

    if (enabled)
    {
        DBG("  HRV: " << bioHRV);
        DBG("  Coherence: " << bioCoherence);
    }
}

void VideoWeaver::setBioData(float hrv, float coherence)
{
    bioHRV = juce::jlimit(0.0f, 1.0f, hrv);
    bioCoherence = juce::jlimit(0.0f, 1.0f, coherence);

    if (bioReactiveEnabled)
    {
        DBG("VideoWeaver: Bio-data updated");
        DBG("  HRV: " << bioHRV);
        DBG("  Coherence: " << bioCoherence);

        // Adjust color grading based on bio-data
        // High HRV -> warmer colors, increased saturation
        // Low HRV -> cooler colors, decreased saturation
        // High coherence -> increased brightness
        // Low coherence -> decreased brightness

        for (auto& clip : clips)
        {
            if (clip.type == Clip::Type::Video || clip.type == Clip::Type::Image)
            {
                // Bio-reactive adjustments
                clip.temperature = (bioHRV - 0.5f) * 0.4f;  // -0.2 to +0.2
                clip.saturation = (bioHRV - 0.5f) * 0.3f;   // -0.15 to +0.15
                clip.brightness = (bioCoherence - 0.5f) * 0.3f;  // -0.15 to +0.15
            }
        }

        DBG("  Applied bio-reactive color grading to " << clips.size() << " clips");
    }
}

//==============================================================================
// Transitions
//==============================================================================

void VideoWeaver::addTransition(int clipIndex, const Transition& transition)
{
    if (clipIndex < 0 || clipIndex >= static_cast<int>(clips.size()))
    {
        DBG("VideoWeaver: Invalid clip index for transition: " << clipIndex);
        return;
    }

    transitions[clipIndex] = transition;

    DBG("VideoWeaver: Transition added to clip " << clipIndex);
    DBG("  Type: " << (int)transition.type);
    DBG("  Duration: " << transition.duration << "s");
    DBG("  Easing: " << transition.easing);
}

void VideoWeaver::removeTransition(int clipIndex)
{
    auto it = transitions.find(clipIndex);
    if (it != transitions.end())
    {
        transitions.erase(it);
        DBG("VideoWeaver: Transition removed from clip " << clipIndex);
    }
}

//==============================================================================
// Rendering
//==============================================================================

juce::Image VideoWeaver::renderFrame(double timeSeconds)
{
    // Create output image
    juce::Image output(juce::Image::ARGB, projectWidth, projectHeight, true);
    juce::Graphics g(output);

    // Clear to black
    g.fillAll(juce::Colours::black);

    // Find all clips active at this time
    struct ActiveClip
    {
        const Clip* clip;
        float localTime;  // Time within the clip
    };

    std::vector<ActiveClip> activeClips;

    for (const auto& clip : clips)
    {
        double clipEnd = clip.startTime + clip.duration;

        if (timeSeconds >= clip.startTime && timeSeconds < clipEnd)
        {
            float localTime = static_cast<float>(timeSeconds - clip.startTime);
            activeClips.push_back({&clip, localTime});
        }
    }

    // Sort by track index (lower tracks first = background)
    std::sort(activeClips.begin(), activeClips.end(),
              [](const ActiveClip& a, const ActiveClip& b) {
                  return a.clip->trackIndex < b.clip->trackIndex;
              });

    // Render each active clip
    for (size_t i = 0; i < activeClips.size(); ++i)
    {
        const auto& ac = activeClips[i];
        const Clip& clip = *ac.clip;

        // Render clip
        juce::Image clipImage = renderClip(clip, ac.localTime);

        // Apply color grading
        clipImage = applyColorGrading(clipImage, clip);

        // Check for transition
        auto transIt = transitions.find(static_cast<int>(&clip - clips.data()));
        if (transIt != transitions.end() && i > 0)
        {
            const Transition& trans = transIt->second;

            // Check if we're in transition period
            if (ac.localTime < trans.duration)
            {
                // Get previous clip image
                const ActiveClip& prevAc = activeClips[i - 1];
                juce::Image prevImage = renderClip(*prevAc.clip, prevAc.localTime);
                prevImage = applyColorGrading(prevImage, *prevAc.clip);

                // Apply transition
                float progress = ac.localTime / trans.duration;
                clipImage = applyTransition(prevImage, clipImage, trans, progress);
            }
        }

        // Composite onto output with transform
        juce::Graphics clipG(output);

        juce::AffineTransform transform;
        transform = transform.translated(clip.x, clip.y);
        transform = transform.scaled(clip.scaleX, clip.scaleY);
        transform = transform.rotated(clip.rotation,
                                      projectWidth / 2.0f,
                                      projectHeight / 2.0f);

        clipG.setOpacity(clip.opacity);
        clipG.drawImageTransformed(clipImage, transform);
    }

    return output;
}

void VideoWeaver::exportVideo(const juce::File& outputFile, ExportPreset preset)
{
    DBG("VideoWeaver: Exporting video");
    DBG("  Output: " << outputFile.getFullPathName());
    DBG("  Preset: " << (int)preset);

    // Set resolution and settings based on preset
    int exportWidth = projectWidth;
    int exportHeight = projectHeight;
    double exportFPS = frameRate;
    juce::String codec = "H.264";
    int bitrate = 20000;  // kbps

    switch (preset)
    {
        case ExportPreset::YouTube_4K:
            exportWidth = 3840;
            exportHeight = 2160;
            exportFPS = 30.0;
            codec = "H.264";
            bitrate = 50000;
            break;

        case ExportPreset::YouTube_1080p:
            exportWidth = 1920;
            exportHeight = 1080;
            exportFPS = 30.0;
            codec = "H.264";
            bitrate = 12000;
            break;

        case ExportPreset::Instagram_Square:
            exportWidth = 1080;
            exportHeight = 1080;
            exportFPS = 30.0;
            codec = "H.264";
            bitrate = 8000;
            break;

        case ExportPreset::Instagram_Story:
            exportWidth = 1080;
            exportHeight = 1920;
            exportFPS = 30.0;
            codec = "H.264";
            bitrate = 10000;
            break;

        case ExportPreset::TikTok:
            exportWidth = 1080;
            exportHeight = 1920;
            exportFPS = 30.0;
            codec = "H.264";
            bitrate = 10000;
            break;

        case ExportPreset::Twitter:
            exportWidth = 1280;
            exportHeight = 720;
            exportFPS = 30.0;
            codec = "H.264";
            bitrate = 6000;
            break;

        case ExportPreset::Facebook:
            exportWidth = 1280;
            exportHeight = 720;
            exportFPS = 30.0;
            codec = "H.264";
            bitrate = 8000;
            break;

        case ExportPreset::ProRes422:
            exportWidth = projectWidth;
            exportHeight = projectHeight;
            exportFPS = frameRate;
            codec = "ProRes 422";
            bitrate = 147000;  // ~147 Mbps for 1080p ProRes 422
            break;

        case ExportPreset::H264_High:
            exportWidth = projectWidth;
            exportHeight = projectHeight;
            exportFPS = frameRate;
            codec = "H.264 High";
            bitrate = 30000;
            break;

        case ExportPreset::H265_HEVC:
            exportWidth = projectWidth;
            exportHeight = projectHeight;
            exportFPS = frameRate;
            codec = "H.265 HEVC";
            bitrate = 15000;  // H.265 is ~50% more efficient
            break;

        case ExportPreset::Custom:
        default:
            break;
    }

    DBG("  Resolution: " << exportWidth << "x" << exportHeight);
    DBG("  Frame rate: " << exportFPS << " fps");
    DBG("  Codec: " << codec);
    DBG("  Bitrate: " << bitrate << " kbps");

    // Calculate total frames
    int totalFrames = static_cast<int>(totalDuration * exportFPS);

    DBG("  Total frames: " << totalFrames);

    // Export process
    // In a real implementation, this would:
    // 1. Initialize video encoder (FFmpeg, JUCE Video, or platform API)
    // 2. Render each frame at the correct time
    // 3. Encode and write to output file
    // 4. Show progress bar
    // 5. Handle audio encoding and muxing

    for (int frame = 0; frame < totalFrames; ++frame)
    {
        double time = frame / exportFPS;

        // Render frame
        juce::Image frameImage = renderFrame(time);

        // Encode frame (would use FFmpeg or platform encoder)
        // encoder.encodeFrame(frameImage);

        // Progress callback
        if (frame % 30 == 0)  // Every 30 frames
        {
            float progress = static_cast<float>(frame) / totalFrames;
            DBG("  Progress: " << static_cast<int>(progress * 100) << "%");
        }
    }

    DBG("VideoWeaver: Export complete!");
}

void VideoWeaver::setPlaybackPosition(double seconds)
{
    playbackPosition = juce::jlimit(0.0, totalDuration, seconds);
}

void VideoWeaver::play()
{
    playing = true;
    DBG("VideoWeaver: Playback started at " << playbackPosition << "s");
}

void VideoWeaver::pause()
{
    playing = false;
    DBG("VideoWeaver: Playback paused at " << playbackPosition << "s");
}

void VideoWeaver::stop()
{
    playing = false;
    playbackPosition = 0.0;
    DBG("VideoWeaver: Playback stopped");
}

//==============================================================================
// HDR Support
//==============================================================================

void VideoWeaver::setHDRMode(HDRMode mode)
{
    hdrMode = mode;

    DBG("VideoWeaver: HDR mode set to " << (int)mode);

    switch (mode)
    {
        case HDRMode::SDR:
            DBG("  Standard Dynamic Range");
            break;
        case HDRMode::HDR10:
            DBG("  HDR10 (PQ, Rec. 2020)");
            break;
        case HDRMode::DolbyVision:
            DBG("  Dolby Vision (Dynamic Metadata)");
            break;
        case HDRMode::HLG:
            DBG("  Hybrid Log-Gamma (Broadcast HDR)");
            break;
    }
}

//==============================================================================
// Private Rendering Methods
//==============================================================================

juce::Image VideoWeaver::renderClip(const Clip& clip, double frameTime)
{
    // Create clip image
    juce::Image image(juce::Image::ARGB, projectWidth, projectHeight, true);
    juce::Graphics g(image);

    // Clear to transparent
    g.fillAll(juce::Colours::transparentBlack);

    switch (clip.type)
    {
        case Clip::Type::Video:
        {
            // In a real implementation, this would:
            // 1. Open video file with JUCE Video or FFmpeg
            // 2. Seek to correct frame (inPoint + frameTime)
            // 3. Decode and return frame

            // For now, placeholder colored rectangle
            g.setColour(juce::Colours::blue);
            g.fillRect(0, 0, projectWidth, projectHeight);

            g.setColour(juce::Colours::white);
            g.setFont(24.0f);
            g.drawText("VIDEO: " + clip.name,
                      0, 0, projectWidth, projectHeight,
                      juce::Justification::centred);
            break;
        }

        case Clip::Type::Image:
        {
            // Load image from file
            if (clip.sourceFile.existsAsFile())
            {
                juce::Image sourceImage = juce::ImageFileFormat::loadFrom(clip.sourceFile);
                if (sourceImage.isValid())
                {
                    g.drawImage(sourceImage, 0, 0, projectWidth, projectHeight,
                               0, 0, sourceImage.getWidth(), sourceImage.getHeight());
                }
            }
            else
            {
                // Placeholder
                g.setColour(juce::Colours::green);
                g.fillRect(0, 0, projectWidth, projectHeight);

                g.setColour(juce::Colours::white);
                g.setFont(24.0f);
                g.drawText("IMAGE: " + clip.name,
                          0, 0, projectWidth, projectHeight,
                          juce::Justification::centred);
            }
            break;
        }

        case Clip::Type::Text:
        {
            // Render text
            g.setColour(juce::Colours::white);
            g.setFont(48.0f);
            g.drawText(clip.name,
                      0, 0, projectWidth, projectHeight,
                      juce::Justification::centred);
            break;
        }

        case Clip::Type::Audio:
        {
            // Audio-only clip, show waveform
            g.setColour(juce::Colours::grey);
            g.fillRect(0, projectHeight - 100, projectWidth, 100);

            g.setColour(juce::Colours::lightgreen);
            // Would draw actual waveform here
            for (int x = 0; x < projectWidth; x += 4)
            {
                float height = juce::Random::getSystemRandom().nextFloat() * 80.0f;
                g.drawLine(x, projectHeight - 50, x, projectHeight - 50 - height, 2.0f);
            }
            break;
        }

        case Clip::Type::Effect:
        {
            // Effect overlay (particles, lens flare, etc.)
            g.setColour(juce::Colours::yellow.withAlpha(0.5f));
            g.fillEllipse(projectWidth / 2 - 50, projectHeight / 2 - 50, 100, 100);
            break;
        }
    }

    return image;
}

juce::Image VideoWeaver::applyColorGrading(const juce::Image& input, const Clip& clip)
{
    juce::Image output = input.createCopy();

    // Apply color grading parameters
    // In a real implementation, this would use GPU shaders for performance

    juce::Image::BitmapData data(output, juce::Image::BitmapData::readWrite);

    for (int y = 0; y < output.getHeight(); ++y)
    {
        for (int x = 0; x < output.getWidth(); ++x)
        {
            juce::Colour pixel = output.getPixelAt(x, y);

            float r = pixel.getFloatRed();
            float g = pixel.getFloatGreen();
            float b = pixel.getFloatBlue();
            float a = pixel.getFloatAlpha();

            // Apply brightness
            float brightness = 1.0f + clip.brightness;
            r *= brightness;
            g *= brightness;
            b *= brightness;

            // Apply contrast
            float contrast = 1.0f + clip.contrast;
            r = (r - 0.5f) * contrast + 0.5f;
            g = (g - 0.5f) * contrast + 0.5f;
            b = (b - 0.5f) * contrast + 0.5f;

            // Apply saturation
            float gray = 0.299f * r + 0.587f * g + 0.114f * b;
            float saturation = 1.0f + clip.saturation;
            r = gray + (r - gray) * saturation;
            g = gray + (g - gray) * saturation;
            b = gray + (b - gray) * saturation;

            // Apply hue shift (simplified)
            if (std::abs(clip.hue) > 0.01f)
            {
                // Convert to HSV, shift hue, convert back
                juce::Colour hsv = juce::Colour(r, g, b, a);
                float h, s, v;
                hsv.getHSB(h, s, v);
                h += clip.hue;
                if (h > 1.0f) h -= 1.0f;
                if (h < 0.0f) h += 1.0f;
                juce::Colour rgb = juce::Colour::fromHSV(h, s, v, a);
                r = rgb.getFloatRed();
                g = rgb.getFloatGreen();
                b = rgb.getFloatBlue();
            }

            // Apply temperature (warm/cool)
            if (std::abs(clip.temperature) > 0.01f)
            {
                if (clip.temperature > 0.0f)
                {
                    // Warm (more red/yellow)
                    r += clip.temperature * 0.1f;
                    b -= clip.temperature * 0.1f;
                }
                else
                {
                    // Cool (more blue)
                    b -= clip.temperature * 0.1f;
                    r += clip.temperature * 0.1f;
                }
            }

            // Apply tint (magenta/green)
            if (std::abs(clip.tint) > 0.01f)
            {
                if (clip.tint > 0.0f)
                {
                    // Magenta
                    r += clip.tint * 0.1f;
                    b += clip.tint * 0.1f;
                    g -= clip.tint * 0.05f;
                }
                else
                {
                    // Green
                    g -= clip.tint * 0.1f;
                }
            }

            // Clamp
            r = juce::jlimit(0.0f, 1.0f, r);
            g = juce::jlimit(0.0f, 1.0f, g);
            b = juce::jlimit(0.0f, 1.0f, b);

            output.setPixelAt(x, y, juce::Colour(r, g, b, a));
        }
    }

    // Apply LUT if available
    if (currentColorPreset.lutFile.existsAsFile())
    {
        // Would apply 3D LUT lookup here
        // This is a complex operation that maps RGB values through a 3D lookup table
    }

    // Apply lift/gamma/gain (color wheels)
    // This would be done in a shader for performance

    return output;
}

juce::Image VideoWeaver::applyTransition(const juce::Image& clip1,
                                         const juce::Image& clip2,
                                         const Transition& transition,
                                         float progress)
{
    jassert(progress >= 0.0f && progress <= 1.0f);

    juce::Image output(juce::Image::ARGB, projectWidth, projectHeight, true);
    juce::Graphics g(output);

    // Apply easing to progress
    float easedProgress = progress;  // Linear by default

    if (transition.easing == "EaseIn")
        easedProgress = progress * progress;
    else if (transition.easing == "EaseOut")
        easedProgress = 1.0f - (1.0f - progress) * (1.0f - progress);
    else if (transition.easing == "EaseInOut")
        easedProgress = progress < 0.5f
            ? 2.0f * progress * progress
            : 1.0f - 2.0f * (1.0f - progress) * (1.0f - progress);

    switch (transition.type)
    {
        case Transition::Type::Cut:
            // No transition, instant cut
            g.drawImage(easedProgress < 0.5f ? clip1 : clip2,
                       0, 0, projectWidth, projectHeight,
                       0, 0, projectWidth, projectHeight);
            break;

        case Transition::Type::Fade:
        case Transition::Type::Dissolve:
            // Crossfade
            g.setOpacity(1.0f - easedProgress);
            g.drawImage(clip1, 0, 0, projectWidth, projectHeight,
                       0, 0, projectWidth, projectHeight);
            g.setOpacity(easedProgress);
            g.drawImage(clip2, 0, 0, projectWidth, projectHeight,
                       0, 0, projectWidth, projectHeight);
            break;

        case Transition::Type::Wipe:
            // Horizontal wipe (left to right)
            {
                int wipeX = static_cast<int>(easedProgress * projectWidth);
                g.drawImage(clip1, 0, 0, projectWidth, projectHeight,
                           0, 0, projectWidth, projectHeight);
                g.drawImage(clip2, 0, 0, wipeX, projectHeight,
                           0, 0, wipeX, projectHeight);
            }
            break;

        case Transition::Type::Slide:
            // Slide transition (clip2 slides in from right)
            {
                int slideX = static_cast<int>((1.0f - easedProgress) * projectWidth);
                g.drawImage(clip1, 0, 0, projectWidth, projectHeight,
                           0, 0, projectWidth, projectHeight);
                g.drawImage(clip2, slideX, 0, projectWidth, projectHeight,
                           0, 0, projectWidth, projectHeight);
            }
            break;

        case Transition::Type::Zoom:
            // Zoom transition (clip2 zooms in)
            {
                float scale = 0.1f + easedProgress * 0.9f;
                int w = static_cast<int>(projectWidth * scale);
                int h = static_cast<int>(projectHeight * scale);
                int x = (projectWidth - w) / 2;
                int y = (projectHeight - h) / 2;

                g.setOpacity(1.0f - easedProgress);
                g.drawImage(clip1, 0, 0, projectWidth, projectHeight,
                           0, 0, projectWidth, projectHeight);
                g.setOpacity(easedProgress);
                g.drawImage(clip2, x, y, w, h,
                           0, 0, projectWidth, projectHeight);
            }
            break;

        case Transition::Type::Spin:
            // Spin transition (rotate to next clip)
            {
                juce::AffineTransform transform = juce::AffineTransform::rotation(
                    easedProgress * juce::MathConstants<float>::twoPi,
                    projectWidth / 2.0f,
                    projectHeight / 2.0f
                );

                g.setOpacity(1.0f - easedProgress);
                g.drawImage(clip1, 0, 0, projectWidth, projectHeight,
                           0, 0, projectWidth, projectHeight);
                g.setOpacity(easedProgress);
                g.drawImageTransformed(clip2, transform);
            }
            break;

        case Transition::Type::Blur:
            // Blur transition (blur out, blur in)
            // Would use blur shader in real implementation
            {
                // OPTIMIZATION: Use TrigLookupTables (~20x faster than std::sin)
                const auto& trigTables = Echoel::DSP::TrigLookupTables::getInstance();
                float blurAmount = trigTables.fastSinRad(easedProgress * juce::MathConstants<float>::pi);

                // Simplified: just crossfade with opacity
                g.setOpacity(1.0f - easedProgress);
                g.drawImage(clip1, 0, 0, projectWidth, projectHeight,
                           0, 0, projectWidth, projectHeight);
                g.setOpacity(easedProgress);
                g.drawImage(clip2, 0, 0, projectWidth, projectHeight,
                           0, 0, projectWidth, projectHeight);
            }
            break;
    }

    return output;
}

//==============================================================================
// AI Methods
//==============================================================================

std::vector<double> VideoWeaver::detectBeats(const juce::File& audioFile)
{
    std::vector<double> beatTimes;

    // In a real implementation, this would:
    // 1. Load audio file
    // 2. Analyze spectral flux or onset detection
    // 3. Find peaks in onset strength
    // 4. Return beat times

    // For now, generate regular beats at 120 BPM
    double bpm = 120.0;
    double secondsPerBeat = 60.0 / bpm;

    // Assume audio is 60 seconds long
    for (double t = 0.0; t < 60.0; t += secondsPerBeat)
    {
        beatTimes.push_back(t);
    }

    DBG("VideoWeaver: Detected " << beatTimes.size() << " beats");

    return beatTimes;
}

std::vector<double> VideoWeaver::detectSceneChanges(const juce::File& videoFile)
{
    std::vector<double> sceneTimes;

    // In a real implementation, this would:
    // 1. Open video file
    // 2. Analyze frame-to-frame differences (histogram, pixel diff)
    // 3. Find large changes (scene cuts)
    // 4. Return scene change times

    // For now, generate scenes every 5 seconds
    for (double t = 0.0; t < 60.0; t += 5.0)
    {
        sceneTimes.push_back(t);
    }

    DBG("VideoWeaver: Detected " << sceneTimes.size() << " scene changes");

    return sceneTimes;
}
