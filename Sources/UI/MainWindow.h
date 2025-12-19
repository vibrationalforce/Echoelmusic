#pragma once

#include <JuceHeader.h>
#include "../Audio/AudioEngine.h"
#include "../Audio/Track.h"
#include "../Video/VideoWeaver.h"
#include "ParameterAutomationUI.h"
#include "ClipLauncherGrid.h"

/**
 * Echoelmusic Main Window
 * 
 * Features:
 * - Vaporwave aesthetic (cyan/magenta/purple)
 * - Track view with waveform display
 * - Mixer view with faders and meters
 * - Transport controls
 * - EchoelAI™ panel (SIT - Super Intelligence Tools)
 * - Real-time visualization
 */
class MainWindow : public juce::DocumentWindow
{
public:
    MainWindow(const juce::String& name);
    ~MainWindow() override;

    void closeButtonPressed() override;

private:
    friend class UnifiedWorkspaceView;  // Allow access to private MainComponent

    class MainComponent;
    std::unique_ptr<MainComponent> mainComponent;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MainWindow)
};

/**
 * Main application component containing all UI sections
 *
 * EXTENDED: Now supports dual view mode (Arrangement + Session/Clip)
 */
class MainWindow::MainComponent : public juce::Component,
                                   public juce::Timer,
                                   public juce::KeyListener
{
public:
    //==========================================================================
    // View Mode
    //==========================================================================

    enum class ViewMode
    {
        Arrangement,  // Timeline view (audio + video + automation)
        Session       // Clip launcher view
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    MainComponent();
    ~MainComponent() override;

    //==========================================================================
    // Component Methods
    //==========================================================================

    void paint(juce::Graphics& g) override;
    void resized() override;
    void timerCallback() override;

    //==========================================================================
    // View Mode Management
    //==========================================================================

    void setViewMode(ViewMode mode);
    ViewMode getViewMode() const { return currentViewMode; }
    void toggleViewMode();

    //==========================================================================
    // Keyboard Shortcuts
    //==========================================================================

    bool keyPressed(const juce::KeyPress& key, Component* originatingComponent) override;

private:
    friend class UnifiedWorkspaceView;  // Allow access to private TrackView

    //==========================================================================
    // Core References
    //==========================================================================
    std::unique_ptr<AudioEngine> audioEngine;

    //==========================================================================
    // UI Sections
    //==========================================================================
    class TopBar;
    class TrackView;
    class TransportBar;

    std::unique_ptr<TopBar> topBar;
    std::unique_ptr<TrackView> trackView;           // Arrangement view
    std::unique_ptr<ClipLauncherGrid> sessionView;  // Session/Clip view
    std::unique_ptr<TransportBar> transportBar;

    //==========================================================================
    // View Mode UI
    //==========================================================================

    juce::TextButton viewModeButton;
    ViewMode currentViewMode = ViewMode::Arrangement;

    void updateViewVisibility();

    //==========================================================================
    // State
    //==========================================================================
    bool aiPanelVisible = false;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MainComponent)
};

/**
 * Top bar - Project name, BPM, settings, cloud status
 */
class MainWindow::MainComponent::TopBar : public juce::Component,
                                           public juce::Button::Listener
{
public:
    TopBar(AudioEngine& engine);
    void paint(juce::Graphics& g) override;
    void resized() override;
    void buttonClicked(juce::Button* button) override;

private:
    AudioEngine& audioEngine;
    
    juce::Label projectNameLabel;
    juce::TextButton settingsButton;
    juce::TextButton playButton;
    juce::Label bpmLabel;
    juce::TextButton cloudButton;
    juce::TextButton aiButton;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(TopBar)
};

/**
 * Track view - Unified timeline for audio, video, and automation
 *
 * EXTENDED: Now supports audio + video + automation in unified view
 */
class MainWindow::MainComponent::TrackView : public juce::Component,
                                              public juce::ScrollBar::Listener
{
public:
    //==========================================================================
    // Unified Track Types
    //==========================================================================

    enum class TrackType { Audio, Video, Automation };

    struct UnifiedTrack
    {
        TrackType type;
        juce::String name;

        // For audio tracks
        std::shared_ptr<juce::AudioBuffer<float>> audioBuffer;
        juce::Colour waveformColor = juce::Colour(0xff00e5ff);  // Cyan

        // For video tracks (uses VideoWeaver.Clip)
        VideoWeaver::Clip videoClip;
        bool bioReactive = false;
        juce::String bioParameter;  // "coherence", "hrv", "stress"

        // For automation tracks (uses ParameterAutomationUI.ParameterLane)
        ParameterAutomationUI::ParameterLane automationLane;

        float height = 80.0f;
        bool visible = true;
        bool muted = false;
        bool solo = false;
        juce::Colour trackColor;

        UnifiedTrack() = default;
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    TrackView(AudioEngine& engine);
    ~TrackView() override;

    //==========================================================================
    // Track Management
    //==========================================================================

    /** Add audio track */
    void addAudioTrack(const juce::String& name, juce::Colour color = juce::Colour(0xff00e5ff));

    /** Add video track */
    void addVideoTrack(const juce::String& name, const VideoWeaver::Clip& clip);

    /** Add automation track */
    void addAutomationTrack(const juce::String& parameter, const ParameterAutomationUI::ParameterLane& lane);

    /** Get track count */
    int getNumTracks() const { return static_cast<int>(unifiedTracks.size()); }

    /** Get track */
    UnifiedTrack& getTrack(int index);
    const UnifiedTrack& getTrack(int index) const;

    /** Remove track */
    void removeTrack(int index);

    /** Clear all tracks */
    void clearTracks();

    //==========================================================================
    // Component Methods
    //==========================================================================

    void paint(juce::Graphics& g) override;
    void resized() override;
    void scrollBarMoved(juce::ScrollBar* scrollBar, double newRangeStart) override;

    void updateTracks();  // Refresh from engine

    //==========================================================================
    // Integration Points
    //==========================================================================

    /** Set video weaver for rendering video clips */
    void setVideoWeaver(VideoWeaver* weaver) { videoWeaver = weaver; }

    /** Set automation UI for rendering automation lanes */
    void setAutomationUI(ParameterAutomationUI* ui) { automationUI = ui; }

private:
    AudioEngine& audioEngine;

    // Scrolling
    std::unique_ptr<juce::ScrollBar> horizontalScrollBar;
    std::unique_ptr<juce::ScrollBar> verticalScrollBar;

    // Zoom
    double pixelsPerSecond = 100.0;  // Horizontal zoom
    double trackHeight = 80.0;        // Track height in pixels

    // Playhead
    int64_t currentPlayheadPosition = 0;

    //==========================================================================
    // Unified Track List
    //==========================================================================

    std::vector<UnifiedTrack> unifiedTracks;

    // Integration with existing components
    VideoWeaver* videoWeaver = nullptr;
    ParameterAutomationUI* automationUI = nullptr;

    //==========================================================================
    // Drawing Methods
    //==========================================================================

    void drawTimeline(juce::Graphics& g, juce::Rectangle<int> bounds);
    void drawPlayhead(juce::Graphics& g, juce::Rectangle<int> bounds);
    void drawTracks(juce::Graphics& g, juce::Rectangle<int> bounds);

    // Extended drawing methods for different track types
    void drawAudioWaveform(juce::Graphics& g, juce::Rectangle<int> bounds, const UnifiedTrack& track);
    void drawVideoClip(juce::Graphics& g, juce::Rectangle<int> bounds, const UnifiedTrack& track);
    void drawAutomationLane(juce::Graphics& g, juce::Rectangle<int> bounds, const UnifiedTrack& track);

    // Helper methods
    float beatToX(double beat) const;
    double xToBeat(float x) const;
    float valueToY(float value, juce::Rectangle<int> bounds) const;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(TrackView)
};

/**
 * Transport bar - Play, stop, record, position, save, export
 */
class MainWindow::MainComponent::TransportBar : public juce::Component,
                                                 public juce::Button::Listener
{
public:
    TransportBar(AudioEngine& engine);

    void paint(juce::Graphics& g) override;
    void resized() override;
    void buttonClicked(juce::Button* button) override;

    void updatePosition(int64_t positionInSamples, double sampleRate);

private:
    AudioEngine& audioEngine;

    // Transport buttons
    juce::TextButton previousButton;
    juce::TextButton playButton;
    juce::TextButton nextButton;
    juce::TextButton stopButton;
    juce::TextButton recordButton;

    // Position display
    juce::Label positionLabel;

    // Master meter (simple version for now)
    float currentLevel = 0.0f;

    // File operations
    juce::TextButton saveButton;
    juce::TextButton exportButton;

    void onPlayClicked();
    void onStopClicked();
    void onRecordClicked();

    void drawMasterMeter(juce::Graphics& g, juce::Rectangle<int> bounds);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(TransportBar)
};
