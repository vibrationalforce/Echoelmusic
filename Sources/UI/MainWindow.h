#pragma once

#include <JuceHeader.h>
#include "../Audio/AudioEngine.h"

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
    class MainComponent;
    std::unique_ptr<MainComponent> mainComponent;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MainWindow)
};

/**
 * Main application component containing all UI sections
 */
class MainWindow::MainComponent : public juce::Component,
                                   public juce::Timer
{
public:
    MainComponent();
    ~MainComponent() override;

    void paint(juce::Graphics& g) override;
    void resized() override;
    void timerCallback() override;

private:
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
    std::unique_ptr<TrackView> trackView;
    std::unique_ptr<TransportBar> transportBar;

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
 * Track view - Waveforms, MIDI notes, timeline
 */
class MainWindow::MainComponent::TrackView : public juce::Component,
                                              public juce::ScrollBar::Listener
{
public:
    TrackView(AudioEngine& engine);
    ~TrackView() override;

    void paint(juce::Graphics& g) override;
    void resized() override;
    void scrollBarMoved(juce::ScrollBar* scrollBar, double newRangeStart) override;

    void updateTracks();  // Refresh from engine

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

    void drawTimeline(juce::Graphics& g, juce::Rectangle<int> bounds);
    void drawPlayhead(juce::Graphics& g, juce::Rectangle<int> bounds);
    void drawTracks(juce::Graphics& g, juce::Rectangle<int> bounds);

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
