#pragma once

#include <JuceHeader.h>
#include "PluginProcessor.h"
// #include "../Visualization/BioReactiveVisualizer.h"  // TODO: Enable in Phase 2
// #include "../Visualization/SpectrumAnalyzer.h"  // TODO: Enable in Phase 2

/**
 * Echoelmusic Plugin Editor
 *
 * Beautiful, professional plugin GUI with:
 * - Real-time bio-data visualization
 * - Spectrum analyzer
 * - Bio-reactive waveform display
 * - Professional parameter controls
 * - Cross-platform (Windows/macOS/Linux)
 */
class EchoelmusicAudioProcessorEditor  : public juce::AudioProcessorEditor,
                                          private juce::Timer
{
public:
    EchoelmusicAudioProcessorEditor (EchoelmusicAudioProcessor&);
    ~EchoelmusicAudioProcessorEditor() override;

    //==============================================================================
    void paint (juce::Graphics&) override;
    void resized() override;

private:
    //==============================================================================
    // Timer callback for real-time updates
    void timerCallback() override;

    //==============================================================================
    // Components

    // Bio-Data Display
    class BioDataPanel : public juce::Component
    {
    public:
        void paint(juce::Graphics& g) override;
        void update(float hrv, float coherence, float heartRate);

    private:
        float currentHRV = 0.5f;
        float currentCoherence = 0.5f;
        float currentHeartRate = 70.0f;

        juce::String getCoherenceLevel() const;
        juce::Colour getCoherenceColor() const;
    };

    std::unique_ptr<BioDataPanel> bioDataPanel;

    // Visualizers
    // std::unique_ptr<BioReactiveVisualizer> bioVisualizer;  // TODO: Enable in Phase 2
    // std::unique_ptr<SpectrumAnalyzer> spectrumAnalyzer;  // TODO: Enable in Phase 2

    // Parameter Controls
    class RotarySlider : public juce::Slider
    {
    public:
        RotarySlider();
        void paint(juce::Graphics& g) override;
    };

    std::unique_ptr<RotarySlider> filterCutoffSlider;
    std::unique_ptr<RotarySlider> resonanceSlider;
    std::unique_ptr<RotarySlider> reverbMixSlider;
    std::unique_ptr<RotarySlider> delayTimeSlider;
    std::unique_ptr<RotarySlider> distortionSlider;
    std::unique_ptr<RotarySlider> compressionSlider;

    std::unique_ptr<juce::Label> filterCutoffLabel;
    std::unique_ptr<juce::Label> resonanceLabel;
    std::unique_ptr<juce::Label> reverbMixLabel;
    std::unique_ptr<juce::Label> delayTimeLabel;
    std::unique_ptr<juce::Label> distortionLabel;
    std::unique_ptr<juce::Label> compressionLabel;

    // Parameter Attachments
    using SliderAttachment = juce::AudioProcessorValueTreeState::SliderAttachment;

    std::unique_ptr<SliderAttachment> filterCutoffAttachment;
    std::unique_ptr<SliderAttachment> resonanceAttachment;
    std::unique_ptr<SliderAttachment> reverbMixAttachment;
    std::unique_ptr<SliderAttachment> delayTimeAttachment;
    std::unique_ptr<SliderAttachment> distortionAttachment;
    std::unique_ptr<SliderAttachment> compressionAttachment;

    // Buttons
    std::unique_ptr<juce::TextButton> presetButton;
    std::unique_ptr<juce::TextButton> aboutButton;

    // Logo
    juce::Image logoImage;

    //==============================================================================
    // Reference to processor
    EchoelmusicAudioProcessor& audioProcessor;

    //==============================================================================
    // Colors & Styling
    juce::Colour backgroundColour {0xff1a1a1a};
    juce::Colour panelColour {0xff2a2a2a};
    juce::Colour accentColour {0xff00d4ff};
    juce::Colour textColour {0xffffffff};

    //==============================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (EchoelmusicAudioProcessorEditor)
};
