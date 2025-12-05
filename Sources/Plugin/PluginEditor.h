#pragma once

#include <JuceHeader.h>
#include "PluginProcessor.h"
#include "../UI/SimpleMainUI.h"
#include "../Visualization/BioReactiveVisualizer.h"
#include "../Visualization/SpectrumAnalyzer.h"

/**
 * Echoelmusic Plugin Editor
 *
 * Beautiful, professional plugin GUI with:
 * - Cross-platform responsive UI (Desktop/Tablet/Phone)
 * - Phase Analyzer (Goniometer + Correlation Meter)
 * - Style-Aware Mastering (Genre-specific LUFS mastering)
 * - EchoSynth (Analog synthesizer)
 * - Real-time bio-data visualization
 * - Modern dark/light themes
 * - Touch-optimized controls
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
    // Main UI Component (Simplified for now)
    std::unique_ptr<SimpleMainUI> mainUI;

    //==============================================================================
    // Reference to processor
    EchoelmusicAudioProcessor& audioProcessor;

    //==============================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (EchoelmusicAudioProcessorEditor)
};
