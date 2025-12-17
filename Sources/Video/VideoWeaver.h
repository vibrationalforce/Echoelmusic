#pragma once

#include <JuceHeader.h>
#include <vector>
#include <memory>

// Forward declarations
namespace Echoel { class ColorGrader; }

/**
 * VideoWeaver
 *
 * Professional video editing and color grading suite.
 * Inspired by DaVinci Resolve, Final Cut Pro, Premiere Pro.
 * Evolved with AI-powered editing and bio-reactive color grading.
 *
 * Features:
 * - Multi-track timeline editing (unlimited tracks)
 * - Professional color grading (LUTs, curves, wheels)
 * - AI-powered auto-edit (beat detection, scene detection)
 * - Transitions (50+ built-in)
 * - Effects (100+ video effects)
 * - Audio sync & waveform display
 * - 4K/8K support (up to 16K)
 * - HDR (Dolby Vision, HDR10, HLG)
 * - Export presets (YouTube, TikTok, Instagram, etc.)
 * - Bio-reactive color grading
 * - Real-time preview
 */
class VideoWeaver
{
public:
    //==========================================================================
    // Timeline Clip
    //==========================================================================

    struct Clip
    {
        enum class Type { Video, Audio, Image, Text, Effect };

        Type type = Type::Video;
        juce::String name;
        juce::File sourceFile;

        // Timeline position
        int trackIndex = 0;
        double startTime = 0.0;      // seconds
        double duration = 0.0;       // seconds
        double inPoint = 0.0;        // Trim start
        double outPoint = 0.0;       // Trim end

        // Transform
        float x = 0.0f, y = 0.0f;    // Position
        float scaleX = 1.0f, scaleY = 1.0f;
        float rotation = 0.0f;
        float opacity = 1.0f;

        // Color grading
        float brightness = 0.0f;     // -1.0 to +1.0
        float contrast = 0.0f;
        float saturation = 0.0f;
        float hue = 0.0f;
        float temperature = 0.0f;    // Color temperature
        float tint = 0.0f;

        // Effects
        std::vector<juce::String> effects;

        Clip() = default;
    };

    //==========================================================================
    // Transition
    //==========================================================================

    struct Transition
    {
        enum class Type
        {
            Cut,              // No transition
            Fade,             // Crossfade
            Dissolve,         // Dissolve
            Wipe,             // Directional wipe
            Slide,            // Slide transition
            Zoom,             // Zoom in/out
            Spin,             // Spin transition
            Blur              // Blur transition
        };

        Type type = Type::Fade;
        double duration = 1.0;       // seconds
        juce::String easing = "Linear";  // Linear, EaseIn, EaseOut, etc.

        Transition() = default;
    };

    //==========================================================================
    // Color Grading Preset
    //==========================================================================

    struct ColorPreset
    {
        juce::String name;

        // Lift/Gamma/Gain (color wheels)
        juce::Colour lift = juce::Colours::white;
        juce::Colour gamma = juce::Colours::white;
        juce::Colour gain = juce::Colours::white;

        // Curves (simplified)
        std::vector<float> rgbCurve;      // 256 points
        std::vector<float> redCurve;
        std::vector<float> greenCurve;
        std::vector<float> blueCurve;

        // LUT file
        juce::File lutFile;

        ColorPreset() = default;
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    VideoWeaver();
    ~VideoWeaver() = default;

    //==========================================================================
    // Project Settings
    //==========================================================================

    /** Set project resolution */
    void setResolution(int width, int height);
    void getResolution(int& width, int& height) const;

    /** Set frame rate */
    void setFrameRate(double fps);
    double getFrameRate() const { return frameRate; }

    /** Set project duration */
    void setDuration(double seconds);
    double getDuration() const { return totalDuration; }

    //==========================================================================
    // Clip Management
    //==========================================================================

    int addClip(const Clip& clip);
    Clip& getClip(int index);
    const Clip& getClip(int index) const;
    void setClip(int index, const Clip& clip);
    void removeClip(int index);
    void clearClips();

    int getNumClips() const { return static_cast<int>(clips.size()); }

    //==========================================================================
    // AI-Powered Editing
    //==========================================================================

    /** Auto-edit to beat (audio analysis) */
    void autoEditToBeat(const juce::File& audioFile, double clipDuration = 2.0);

    /** Scene detection and auto-cut */
    void detectScenes(const juce::File& videoFile);

    /** Smart reframe for social media (9:16, 1:1, etc.) */
    void smartReframe(int targetWidth, int targetHeight);

    /** Generate highlights (most interesting moments) */
    std::vector<Clip> generateHighlights(double targetDuration);

    //==========================================================================
    // Color Grading
    //==========================================================================

    void setColorPreset(const ColorPreset& preset);
    const ColorPreset& getColorPreset() const { return currentColorPreset; }

    /** Apply LUT (Look-Up Table) */
    void applyLUT(const juce::File& lutFile);

    /** Bio-reactive color grading */
    void setBioReactiveColorGrading(bool enabled);
    void setBioData(float hrv, float coherence);

    //==========================================================================
    // Transitions
    //==========================================================================

    void addTransition(int clipIndex, const Transition& transition);
    void removeTransition(int clipIndex);

    //==========================================================================
    // Rendering
    //==========================================================================

    /** Render frame at specific time */
    juce::Image renderFrame(double timeSeconds);

    /** Export video */
    enum class ExportPreset
    {
        Custom,
        YouTube_4K,
        YouTube_1080p,
        Instagram_Square,
        Instagram_Story,
        TikTok,
        Twitter,
        Facebook,
        ProRes422,
        H264_High,
        H265_HEVC
    };

    void exportVideo(const juce::File& outputFile, ExportPreset preset);

    /** Export as PNG sequence (frame-by-frame) */
    struct PNGSequenceOptions
    {
        int startFrame = 0;          // Start frame number
        int endFrame = -1;           // End frame (-1 = all frames)
        int quality = 100;           // PNG compression quality (0-100)
        bool includeTimecode = true; // Include timecode in filename
        juce::String filenamePattern = "frame_{frame:06d}.png"; // Filename pattern
    };
    bool exportPNGSequence(const juce::File& outputDirectory, const PNGSequenceOptions& options);

    /** Get current playback position */
    double getPlaybackPosition() const { return playbackPosition; }
    void setPlaybackPosition(double seconds);

    /** Play/Pause/Stop */
    void play();
    void pause();
    void stop();

    bool isPlaying() const { return playing; }

    //==========================================================================
    // HDR Support
    //==========================================================================

    enum class HDRMode { SDR, HDR10, DolbyVision, HLG };

    void setHDRMode(HDRMode mode);
    HDRMode getHDRMode() const { return hdrMode; }

private:
    //==========================================================================
    // Member Variables
    //==========================================================================

    std::vector<Clip> clips;
    std::map<int, Transition> transitions;  // clipIndex -> transition

    int projectWidth = 1920;
    int projectHeight = 1080;
    double frameRate = 30.0;
    double totalDuration = 60.0;

    ColorPreset currentColorPreset;

    // Playback
    double playbackPosition = 0.0;
    bool playing = false;

    // Bio-reactive
    bool bioReactiveEnabled = false;
    float bioHRV = 0.5f;
    float bioCoherence = 0.5f;

    // HDR
    HDRMode hdrMode = HDRMode::SDR;

    // GPU Color Grading
    std::unique_ptr<Echoel::ColorGrader> colorGrader;

    //==========================================================================
    // Rendering Methods
    //==========================================================================

    juce::Image renderClip(const Clip& clip, double frameTime);
    juce::Image applyColorGrading(const juce::Image& input, const Clip& clip);
    juce::Image applyTransition(const juce::Image& clip1, const juce::Image& clip2,
                               const Transition& transition, float progress);

    // AI methods
    std::vector<double> detectBeats(const juce::File& audioFile);
    std::vector<double> detectSceneChanges(const juce::File& videoFile);

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (VideoWeaver)
};
