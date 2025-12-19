#pragma once

#include <JuceHeader.h>
#include "MainWindow.h"
#include "ClipLauncherGrid.h"
#include "../BioData/BioFeedbackSystem.h"

/**
 * UnifiedWorkspaceView
 *
 * Unified interface combining:
 * - Arrangement View (MainWindow.TrackView with audio + video + automation)
 * - Session/Clip View (ClipLauncherGrid)
 *
 * User can toggle between views with a button or keyboard shortcut (Tab).
 *
 * Features:
 * - Seamless view switching
 * - Persistent state across views
 * - Unified bio-data integration
 * - Keyboard shortcuts (Tab = toggle view)
 * - Visual mode indicator
 * - Easy access design
 */
class UnifiedWorkspaceView : public juce::Component,
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

    UnifiedWorkspaceView(AudioEngine& engine);
    ~UnifiedWorkspaceView() override = default;

    //==========================================================================
    // View Mode Management
    //==========================================================================

    /** Set current view mode */
    void setViewMode(ViewMode mode);

    /** Get current view mode */
    ViewMode getViewMode() const { return currentViewMode; }

    /** Toggle between Arrangement ↔ Session */
    void toggleViewMode();

    //==========================================================================
    // Component Access
    //==========================================================================

    /** Get arrangement view (TrackView) */
    MainWindow::MainComponent::TrackView* getArrangementView() { return arrangementView.get(); }

    /** Get session view (ClipLauncherGrid) */
    ClipLauncherGrid* getSessionView() { return sessionView.get(); }

    //==========================================================================
    // Bio-Reactive Integration
    //==========================================================================

    /** Update bio-data (forwarded to both views) */
    void setBioData(float hrv, float coherence, float stress);

    /** Update bio-data from BioFeedbackSystem */
    void updateBioData(const Echoelmusic::BioFeedbackSystem::UnifiedBioData& bioData);

    //==========================================================================
    // Integration Points
    //==========================================================================

    /** Set video weaver for video rendering */
    void setVideoWeaver(VideoWeaver* weaver);

    /** Set automation UI for automation rendering */
    void setAutomationUI(ParameterAutomationUI* ui);

    /** Set BPM (forwarded to both views) */
    void setBPM(double bpm);

    //==========================================================================
    // Component Methods
    //==========================================================================

    void paint(juce::Graphics& g) override;
    void resized() override;

    //==========================================================================
    // Keyboard Shortcuts
    //==========================================================================

    bool keyPressed(const juce::KeyPress& key, Component* originatingComponent) override;
    using Component::keyPressed;  // Expose base class version

private:
    //==========================================================================
    // References
    //==========================================================================

    AudioEngine& audioEngine;

    //==========================================================================
    // View Components
    //==========================================================================

    std::unique_ptr<MainWindow::MainComponent::TrackView> arrangementView;
    std::unique_ptr<ClipLauncherGrid> sessionView;

    ViewMode currentViewMode = ViewMode::Arrangement;

    //==========================================================================
    // UI Controls
    //==========================================================================

    juce::TextButton viewModeButton;
    juce::Label viewModeLabel;
    juce::Label statusLabel;

    // Colors (Vaporwave theme)
    juce::Colour cyanColor = juce::Colour(0xff00e5ff);
    juce::Colour magentaColor = juce::Colour(0xffff00ff);
    juce::Colour purpleColor = juce::Colour(0xff651fff);
    juce::Colour backgroundColor = juce::Colour(0xff1a1a2e);

    //==========================================================================
    // State
    //==========================================================================

    float currentHRV = 0.5f;
    float currentCoherence = 0.5f;
    float currentStress = 0.5f;
    double currentBPM = 120.0;

    //==========================================================================
    // Helper Methods
    //==========================================================================

    void updateViewVisibility();
    void updateButtonText();
    void updateStatusBar();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(UnifiedWorkspaceView)
};
