/*
  ==============================================================================

    Echoelmusic Pro - Plugin Editor Interface

  ==============================================================================
*/

#pragma once

#include <juce_audio_processors/juce_audio_processors.h>
#include "PluginProcessor.h"
#include "ModernLookAndFeel.h"
#include "../../Visualization/SpectrumAnalyzer.h"
#include "../../Visualization/BioReactiveVisualizer.h"
#include "../../UI/PresetBrowserUI.h"

//==============================================================================
/**
 * Echoelmusic Pro Editor
 *
 * Professional audio plugin GUI with:
 * - Synthesis controls
 * - DSP processor rack
 * - Preset browser (202 presets)
 * - Bio-reactive visualization
 * - Real-time spectrum analyzer
 */
class EchoelmusicProEditor  : public juce::AudioProcessorEditor,
                               public juce::Timer
{
public:
    EchoelmusicProEditor (EchoelmusicProProcessor&);
    ~EchoelmusicProEditor() override;

    //==============================================================================
    void paint (juce::Graphics&) override;
    void resized() override;
    void timerCallback() override;

private:
    // Reference to the processor
    EchoelmusicProProcessor& audioProcessor;

    // Modern look and feel
    ModernLookAndFeel modernLookAndFeel;

    // Visualization Components
    SpectrumAnalyzer spectrumAnalyzer;
    BioReactiveVisualizer bioVisualizer;

    // UI Components
    PresetBrowserUI presetBrowser;

    // TODO: Add ProcessorRack (AdvancedDSPManagerUI or custom)

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (EchoelmusicProEditor)
};
