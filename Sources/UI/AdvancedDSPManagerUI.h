#pragma once

#include <JuceHeader.h>
#include "ResponsiveLayout.h"
#include "ModernLookAndFeel.h"
#include "UIComponents.h"
#include "../DSP/AdvancedDSPManager.h"

//==============================================================================
/**
 * @brief Advanced DSP Manager UI
 *
 * Professional control panel for 4 cutting-edge DSP processors:
 * - Mid/Side Tone Matching
 * - Audio Humanizer
 * - Swarm Reverb
 * - Polyphonic Pitch Editor
 *
 * Features:
 * - Tabbed interface for each processor
 * - Real-time metering and visualization
 * - Bio-reactive status indicators
 * - A/B comparison controls
 * - Undo/Redo buttons
 * - CPU usage monitoring
 * - Preset browser integration
 */
class AdvancedDSPManagerUI : public ResponsiveComponent,
                              private juce::Timer
{
public:
    //==========================================================================
    // Constructor / Destructor

    AdvancedDSPManagerUI();
    ~AdvancedDSPManagerUI() override;

    //==========================================================================
    // DSP Manager Connection

    void setDSPManager(AdvancedDSPManager* manager);
    AdvancedDSPManager* getDSPManager() const { return dspManager; }

    //==========================================================================
    // Component Methods

    void paint(juce::Graphics& g) override;
    void resized() override;

private:
    //==========================================================================
    // Tab Selection

    enum class ProcessorTab
    {
        MidSideToneMatching = 0,
        AudioHumanizer = 1,
        SwarmReverb = 2,
        PolyphonicPitchEditor = 3
    };

    ProcessorTab currentTab = ProcessorTab::MidSideToneMatching;

    //==========================================================================
    // Top Control Bar Components

    class TopControlBar : public juce::Component
    {
    public:
        TopControlBar(AdvancedDSPManagerUI& parent);
        void paint(juce::Graphics& g) override;
        void resized() override;

    private:
        AdvancedDSPManagerUI& owner;

        // A/B Comparison
        juce::TextButton copyToAButton;
        juce::TextButton copyToBButton;
        juce::TextButton toggleABButton;

        // Undo/Redo
        juce::TextButton undoButton;
        juce::TextButton redoButton;

        // Processing Order
        juce::ComboBox processingOrderCombo;

        // CPU Usage
        juce::Label cpuLabel;

        // Bio-Reactive Toggle
        juce::ToggleButton bioReactiveToggle;

        JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(TopControlBar)
    };

    //==========================================================================
    // Tab Buttons

    class TabBar : public juce::Component
    {
    public:
        TabBar(AdvancedDSPManagerUI& parent);
        void paint(juce::Graphics& g) override;
        void resized() override;
        void setCurrentTab(ProcessorTab tab);
        ProcessorTab getCurrentTab() const { return currentTab; }

        std::function<void(ProcessorTab)> onTabChanged;

    private:
        AdvancedDSPManagerUI& owner;
        ProcessorTab currentTab = ProcessorTab::MidSideToneMatching;

        juce::TextButton midSideButton;
        juce::TextButton humanizerButton;
        juce::TextButton swarmButton;
        juce::TextButton pitchEditorButton;

        JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(TabBar)
    };

    //==========================================================================
    // Mid/Side Tone Matching Panel

    class MidSideToneMatchingPanel : public juce::Component
    {
    public:
        MidSideToneMatchingPanel(AdvancedDSPManagerUI& parent);
        void paint(juce::Graphics& g) override;
        void resized() override;
        void updateFromDSP();

    private:
        AdvancedDSPManagerUI& owner;

        // Controls
        juce::Slider matchingStrengthSlider;
        juce::Label matchingStrengthLabel;

        juce::Slider midGainSlider;
        juce::Label midGainLabel;

        juce::Slider sideGainSlider;
        juce::Label sideGainLabel;

        juce::Slider midWidthSlider;
        juce::Label midWidthLabel;

        juce::TextButton learnReferenceButton;
        juce::ToggleButton bioReactiveToggle;

        // Spectrum visualizers
        std::vector<float> currentMidSpectrum;
        std::vector<float> currentSideSpectrum;
        std::vector<float> referenceMidSpectrum;
        std::vector<float> referenceSideSpectrum;

        JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MidSideToneMatchingPanel)
    };

    //==========================================================================
    // Audio Humanizer Panel

    class AudioHumanizerPanel : public juce::Component
    {
    public:
        AudioHumanizerPanel(AdvancedDSPManagerUI& parent);
        void paint(juce::Graphics& g) override;
        void resized() override;
        void updateFromDSP();

    private:
        AdvancedDSPManagerUI& owner;

        // Controls
        juce::Slider humanizationAmountSlider;
        juce::Label humanizationAmountLabel;

        juce::Slider spectralAmountSlider;
        juce::Label spectralAmountLabel;

        juce::Slider transientAmountSlider;
        juce::Label transientAmountLabel;

        juce::Slider colourAmountSlider;
        juce::Label colourAmountLabel;

        juce::Slider noiseAmountSlider;
        juce::Label noiseAmountLabel;

        juce::Slider smoothAmountSlider;
        juce::Label smoothAmountLabel;

        juce::ComboBox timeDivisionCombo;
        juce::Label timeDivisionLabel;

        juce::ToggleButton bioReactiveToggle;

        JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(AudioHumanizerPanel)
    };

    //==========================================================================
    // Swarm Reverb Panel

    class SwarmReverbPanel : public juce::Component,
                             private juce::Timer
    {
    public:
        SwarmReverbPanel(AdvancedDSPManagerUI& parent);
        ~SwarmReverbPanel() override;
        void paint(juce::Graphics& g) override;
        void resized() override;
        void updateFromDSP();

    private:
        void timerCallback() override;

        AdvancedDSPManagerUI& owner;

        // Controls
        juce::Slider particleCountSlider;
        juce::Label particleCountLabel;

        juce::Slider cohesionSlider;
        juce::Label cohesionLabel;

        juce::Slider separationSlider;
        juce::Label separationLabel;

        juce::Slider chaosSlider;
        juce::Label chaosLabel;

        juce::Slider roomSizeSlider;
        juce::Label roomSizeLabel;

        juce::Slider dampingSlider;
        juce::Label dampingLabel;

        juce::Slider mixSlider;
        juce::Label mixLabel;

        juce::ToggleButton bioReactiveToggle;

        // 3D Visualization
        struct ParticleVisual
        {
            float x, y, z;
            float radius;
        };
        std::vector<ParticleVisual> particleVisuals;
        float rotationAngle = 0.0f;

        JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SwarmReverbPanel)
    };

    //==========================================================================
    // Polyphonic Pitch Editor Panel

    class PolyphonicPitchEditorPanel : public juce::Component
    {
    public:
        PolyphonicPitchEditorPanel(AdvancedDSPManagerUI& parent);
        void paint(juce::Graphics& g) override;
        void resized() override;
        void updateFromDSP();

    private:
        AdvancedDSPManagerUI& owner;

        // Controls
        juce::Slider pitchCorrectionStrengthSlider;
        juce::Label pitchCorrectionStrengthLabel;

        juce::Slider formantPreservationSlider;
        juce::Label formantPreservationLabel;

        juce::Slider vibratoCorrectionSlider;
        juce::Label vibratoCorrectionLabel;

        juce::ComboBox scaleTypeCombo;
        juce::Label scaleTypeLabel;

        juce::ComboBox rootNoteCombo;
        juce::Label rootNoteLabel;

        juce::TextButton quantizeButton;
        juce::TextButton analyzeButton;

        juce::ToggleButton bioReactiveToggle;

        // Note display
        struct NoteVisual
        {
            int noteID;
            float startTime;
            float duration;
            float pitch;
            bool enabled;
        };
        std::vector<NoteVisual> detectedNotes;

        JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(PolyphonicPitchEditorPanel)
    };

    //==========================================================================
    // Timer Callback

    void timerCallback() override;

    //==========================================================================
    // Member Variables

    AdvancedDSPManager* dspManager = nullptr;

    // UI Components
    std::unique_ptr<TopControlBar> topControlBar;
    std::unique_ptr<TabBar> tabBar;
    std::unique_ptr<MidSideToneMatchingPanel> midSidePanel;
    std::unique_ptr<AudioHumanizerPanel> humanizerPanel;
    std::unique_ptr<SwarmReverbPanel> swarmPanel;
    std::unique_ptr<PolyphonicPitchEditorPanel> pitchEditorPanel;

    // Metrics
    float currentCPUUsage = 0.0f;
    bool bioReactiveActive = false;
    float currentHRV = 0.0f;
    float currentCoherence = 0.0f;
    float currentStress = 0.0f;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(AdvancedDSPManagerUI)
};
