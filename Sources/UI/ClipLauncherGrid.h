#pragma once

#include <JuceHeader.h>
#include "../Audio/Track.h"
#include "../Video/VideoWeaver.h"
#include "../BioData/BioFeedbackSystem.h"

/**
 * ClipLauncherGrid
 *
 * Ableton Live-style session/clip view for triggering audio/video clips.
 *
 * Features:
 * - Grid of clips (tracks × scenes)
 * - Click to trigger clip
 * - Scene launch (trigger entire row)
 * - Follow actions (auto-advance clips)
 * - Bio-reactive clip selection (HRV → clip speed, coherence → filter)
 * - BPM quantization
 * - Visual feedback (playing clips pulse)
 * - Color-coded clips
 * - Real-time status indicators
 */
class ClipLauncherGrid : public juce::Component,
                          private juce::Timer
{
public:
    //==========================================================================
    // Clip Slot
    //==========================================================================

    struct ClipSlot
    {
        enum class Type { Empty, Audio, Video, Generated };

        Type type = Type::Empty;
        juce::String name;
        juce::Colour color = juce::Colours::grey;

        // Audio clip
        juce::File audioFile;
        double startTime = 0.0;
        double loopLength = 4.0;  // bars

        // Video clip
        VideoWeaver::Clip videoClip;

        // State
        bool isPlaying = false;
        bool isQueued = false;
        float playProgress = 0.0f;  // 0.0 to 1.0

        // Bio-reactive
        bool bioReactive = false;
        juce::String bioParameter;  // "hrv", "coherence", "stress"
        float bioModulation = 1.0f;  // Current bio modulation amount

        // Follow actions
        bool followActionEnabled = false;
        int followActionBars = 4;  // Trigger next clip after N bars
        int nextClipIndex = -1;    // -1 = stop, >= 0 = clip index

        ClipSlot() = default;
    };

    //==========================================================================
    // Scene (horizontal row of clips)
    //==========================================================================

    struct Scene
    {
        juce::String name;
        juce::Colour color = juce::Colour(0xff651fff);  // Purple
        double tempo = 120.0;
        int timeSignatureNum = 4;
        int timeSignatureDen = 4;
        bool isTriggered = false;

        Scene() = default;
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    ClipLauncherGrid();
    ~ClipLauncherGrid() override;

    //==========================================================================
    // Grid Management
    //==========================================================================

    /** Set grid size (tracks × scenes) */
    void setGridSize(int numTracks, int numScenes);

    /** Get/Set clip at position */
    ClipSlot& getClip(int trackIndex, int sceneIndex);
    const ClipSlot& getClip(int trackIndex, int sceneIndex) const;
    void setClip(int trackIndex, int sceneIndex, const ClipSlot& clip);

    /** Get/Set scene */
    Scene& getScene(int sceneIndex);
    const Scene& getScene(int sceneIndex) const;
    void setScene(int sceneIndex, const Scene& scene);

    /** Get grid size */
    int getNumTracks() const { return numTracks; }
    int getNumScenes() const { return numScenes; }

    //==========================================================================
    // Playback Control
    //==========================================================================

    /** Trigger clip (start playing) */
    void triggerClip(int trackIndex, int sceneIndex);

    /** Stop clip */
    void stopClip(int trackIndex, int sceneIndex);

    /** Launch scene (trigger all clips in row) */
    void launchScene(int sceneIndex);

    /** Stop all clips */
    void stopAll();

    /** Stop all clips in track (column) */
    void stopTrack(int trackIndex);

    //==========================================================================
    // Bio-Reactive
    //==========================================================================

    /** Update bio-data for reactive clips */
    void setBioData(float hrv, float coherence, float stress);

    /** Update bio-data from BioFeedbackSystem */
    void updateBioData(const Echoelmusic::BioFeedbackSystem::UnifiedBioData& bioData);

    //==========================================================================
    // BPM & Quantization
    //==========================================================================

    /** Set BPM for clip timing */
    void setBPM(double bpm) { currentBPM = bpm; }
    double getBPM() const { return currentBPM; }

    /** Enable/disable quantization */
    void setQuantizeEnabled(bool enabled) { quantizeEnabled = enabled; }
    bool isQuantizeEnabled() const { return quantizeEnabled; }

    /** Set quantize division (1/4, 1/8, 1/16, etc.) */
    void setQuantizeDivision(double division) { quantizeDivision = division; }

    //==========================================================================
    // Component
    //==========================================================================

    void paint(juce::Graphics& g) override;
    void resized() override;
    void mouseDown(const juce::MouseEvent& event) override;
    void mouseEnter(const juce::MouseEvent& event) override;
    void mouseMove(const juce::MouseEvent& event) override;
    void mouseExit(const juce::MouseEvent& event) override;

    //==========================================================================
    // Callbacks
    //==========================================================================

    std::function<void(int trackIndex, int sceneIndex)> onClipTriggered;
    std::function<void(int trackIndex, int sceneIndex)> onClipStopped;
    std::function<void(int sceneIndex)> onSceneLaunched;

private:
    //==========================================================================
    // Grid Data
    //==========================================================================

    std::vector<std::vector<ClipSlot>> clips;  // [track][scene]
    std::vector<Scene> scenes;

    int numTracks = 8;
    int numScenes = 8;

    // Bio-data
    float currentHRV = 0.5f;
    float currentCoherence = 0.5f;
    float currentStress = 0.5f;

    // BPM & Timing
    double currentBPM = 120.0;
    bool quantizeEnabled = true;
    double quantizeDivision = 0.25;  // 1/16 notes

    //==========================================================================
    // UI State
    //==========================================================================

    int hoveredTrack = -1;
    int hoveredScene = -1;

    // Colors
    juce::Colour emptySlotColor = juce::Colour(0xff1a1a2e);
    juce::Colour audioSlotColor = juce::Colour(0xff00e5ff);  // Cyan
    juce::Colour videoSlotColor = juce::Colour(0xffff00ff);  // Magenta
    juce::Colour generatedSlotColor = juce::Colour(0xff651fff);  // Purple

    // Animation
    float pulsePhase = 0.0f;  // For playing clip animation

    //==========================================================================
    // Timer Callback
    //==========================================================================

    void timerCallback() override;

    //==========================================================================
    // Helper Methods
    //==========================================================================

    juce::Rectangle<int> getClipBounds(int trackIndex, int sceneIndex) const;
    juce::Rectangle<int> getSceneBounds(int sceneIndex) const;
    juce::Rectangle<int> getStopTrackBounds(int trackIndex) const;

    void drawClipSlot(juce::Graphics& g, const ClipSlot& clip, juce::Rectangle<int> bounds);
    void drawScene(juce::Graphics& g, const Scene& scene, juce::Rectangle<int> bounds, int sceneIndex);
    void drawStopButton(juce::Graphics& g, juce::Rectangle<int> bounds, int trackIndex);

    void getClipAtPosition(int x, int y, int& trackIndex, int& sceneIndex) const;
    bool isSceneButtonAtPosition(int x, int y, int& sceneIndex) const;
    bool isStopButtonAtPosition(int x, int y, int& trackIndex) const;

    void updateBioModulation();
    void updateFollowActions();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ClipLauncherGrid)
};
