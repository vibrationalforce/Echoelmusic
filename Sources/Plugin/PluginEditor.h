#pragma once

#include <JuceHeader.h>
#include "PluginProcessor.h"
#include "../UI/SimpleMainUI.h"
// #include "../Visualization/BioReactiveVisualizer.h"  // TODO: Enable in Phase 2
// #include "../Visualization/SpectrumAnalyzer.h"  // TODO: Enable in Phase 2

/**
 * Eoel Plugin Editor
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
class EoelAudioProcessorEditor  : public juce::AudioProcessorEditor,
                                          private juce::Timer
{
public:
    EoelAudioProcessorEditor (EoelAudioProcessor&);
    ~EoelAudioProcessorEditor() override;

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
    EoelAudioProcessor& audioProcessor;

    //==============================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (EoelAudioProcessorEditor)
};
