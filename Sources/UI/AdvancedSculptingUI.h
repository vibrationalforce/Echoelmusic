#pragma once

#include <JuceHeader.h>
#include "ResponsiveLayout.h"
#include "ModernLookAndFeel.h"
#include "UIComponents.h"
#include "../DSP/SpectralSculptor.h"

//==============================================================================
/**
 * @brief Advanced Sculpting UI - Granular + Spectral Processing
 *
 * Professional interface for:
 * - SpectralSculptor (8 modes)
 * - Granular synthesis control
 * - Real-time spectral visualization
 * - Bio-reactive integration
 *
 * Features:
 * - FFT spectrum analyzer with morphing visualization
 * - Granular parameter control (grain size, density, spray)
 * - Spectral mode selector (Denoise, Gate, Freeze, Morph, etc.)
 * - Bio-reactive status indicators
 * - A/B comparison for spectral states
 * - Freeze/capture spectrum button
 * - Real-time waveform display
 */
class AdvancedSculptingUI : public ResponsiveComponent,
                            private juce::Timer
{
public:
    //==========================================================================
    // Constructor / Destructor

    AdvancedSculptingUI();
    ~AdvancedSculptingUI() override;

    //==========================================================================
    // Spectral Sculptor Connection

    void setSpectralSculptor(SpectralSculptor* sculptor);
    SpectralSculptor* getSpectralSculptor() const { return spectralSculptor; }

    //==========================================================================
    // Component Methods

    void paint(juce::Graphics& g) override;
    void resized() override;

private:
    //==========================================================================
    // Mode Selection Bar

    class ModeSelector : public juce::Component
    {
    public:
        ModeSelector(AdvancedSculptingUI& parent);
        void paint(juce::Graphics& g) override;
        void resized() override;

        void setCurrentMode(SpectralSculptor::ProcessingMode mode);
        SpectralSculptor::ProcessingMode getCurrentMode() const { return currentMode; }

        std::function<void(SpectralSculptor::ProcessingMode)> onModeChanged;

    private:
        AdvancedSculptingUI& owner;
        SpectralSculptor::ProcessingMode currentMode = SpectralSculptor::ProcessingMode::Denoise;

        juce::TextButton denoiseButton;
        juce::TextButton gateButton;
        juce::TextButton enhanceButton;
        juce::TextButton freezeButton;
        juce::TextButton morphButton;
        juce::TextButton restoreButton;

        JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ModeSelector)
    };

    //==========================================================================
    // Spectral Visualizer

    class SpectralVisualizer : public juce::Component,
                                private juce::Timer
    {
    public:
        SpectralVisualizer(AdvancedSculptingUI& parent);
        ~SpectralVisualizer() override;
        void paint(juce::Graphics& g) override;
        void resized() override;

        void updateSpectrum(const std::vector<float>& spectrum);
        void setReferenceSpectrum(const std::vector<float>& spectrum);
        void clearReference();

    private:
        void timerCallback() override;

        AdvancedSculptingUI& owner;

        // Spectrum data (2048 bins typical)
        std::vector<float> currentSpectrum;
        std::vector<float> referenceSpectrum;
        std::vector<float> displaySpectrum;  // Smoothed for display
        bool hasReference = false;

        // Visualization settings
        float smoothingFactor = 0.8f;
        float minDb = -80.0f;
        float maxDb = 0.0f;

        // Mouse interaction
        bool dragging = false;
        juce::Point<int> dragStart;

        JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SpectralVisualizer)
    };

    //==========================================================================
    // Waveform Visualizer

    class WaveformVisualizer : public juce::Component,
                                private juce::Timer
    {
    public:
        WaveformVisualizer(AdvancedSculptingUI& parent);
        ~WaveformVisualizer() override;
        void paint(juce::Graphics& g) override;
        void resized() override;

        void updateWaveform(const juce::AudioBuffer<float>& buffer);

    private:
        void timerCallback() override;

        AdvancedSculptingUI& owner;

        juce::AudioBuffer<float> waveformData;
        int writePosition = 0;

        JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(WaveformVisualizer)
    };

    //==========================================================================
    // Granular Control Panel

    class GranularPanel : public juce::Component
    {
    public:
        GranularPanel(AdvancedSculptingUI& parent);
        void paint(juce::Graphics& g) override;
        void resized() override;

    private:
        AdvancedSculptingUI& owner;

        // Granular parameters
        juce::Slider grainSizeSlider;
        juce::Label grainSizeLabel;

        juce::Slider grainDensitySlider;
        juce::Label grainDensityLabel;

        juce::Slider grainSpraySlider;
        juce::Label grainSprayLabel;

        juce::Slider grainPitchSlider;
        juce::Label grainPitchLabel;

        juce::Slider grainPositionSlider;
        juce::Label grainPositionLabel;

        juce::ComboBox grainEnvelopeCombo;
        juce::Label grainEnvelopeLabel;

        juce::ToggleButton bioReactiveToggle;

        JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(GranularPanel)
    };

    //==========================================================================
    // Spectral Control Panel

    class SpectralPanel : public juce::Component
    {
    public:
        SpectralPanel(AdvancedSculptingUI& parent);
        void paint(juce::Graphics& g) override;
        void resized() override;

        void updateForMode(SpectralSculptor::ProcessingMode mode);

    private:
        AdvancedSculptingUI& owner;

        // Common controls
        juce::Slider mixSlider;
        juce::Label mixLabel;

        // Mode-specific controls
        juce::Slider param1Slider;
        juce::Label param1Label;

        juce::Slider param2Slider;
        juce::Label param2Label;

        juce::Slider param3Slider;
        juce::Label param3Label;

        juce::TextButton captureButton;
        juce::TextButton freezeButton;
        juce::ToggleButton bioReactiveToggle;

        JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SpectralPanel)
    };

    //==========================================================================
    // Bio-Reactive Status Panel

    class BioStatusPanel : public juce::Component,
                            private juce::Timer
    {
    public:
        BioStatusPanel(AdvancedSculptingUI& parent);
        ~BioStatusPanel() override;
        void paint(juce::Graphics& g) override;
        void resized() override;

        void updateBioData(float hrv, float coherence, float stress);

    private:
        void timerCallback() override;

        AdvancedSculptingUI& owner;

        float currentHRV = 0.5f;
        float currentCoherence = 0.5f;
        float currentStress = 0.5f;

        // Animated indicators
        float hrvBarAnimation = 0.0f;
        float coherenceRingAnimation = 0.0f;

        JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(BioStatusPanel)
    };

    //==========================================================================
    // Timer Callback

    void timerCallback() override;

    //==========================================================================
    // Member Variables

    SpectralSculptor* spectralSculptor = nullptr;

    // UI Components
    std::unique_ptr<ModeSelector> modeSelector;
    std::unique_ptr<SpectralVisualizer> spectralVisualizer;
    std::unique_ptr<WaveformVisualizer> waveformVisualizer;
    std::unique_ptr<GranularPanel> granularPanel;
    std::unique_ptr<SpectralPanel> spectralPanel;
    std::unique_ptr<BioStatusPanel> bioStatusPanel;

    // Current state
    SpectralSculptor::ProcessingMode currentMode = SpectralSculptor::ProcessingMode::Denoise;
    bool spectralFrozen = false;

    // Bio-data
    float currentHRV = 0.5f;
    float currentCoherence = 0.5f;
    float currentStress = 0.5f;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(AdvancedSculptingUI)
};
