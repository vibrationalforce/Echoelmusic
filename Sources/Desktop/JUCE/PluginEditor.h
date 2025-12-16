/*
  ==============================================================================

    Echoelmusic Pro - Plugin Editor Interface

  ==============================================================================
*/

#pragma once

#include <juce_audio_processors/juce_audio_processors.h>
#include "PluginProcessor.h"

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
class EchoelmusicProEditor  : public juce::AudioProcessorEditor
{
public:
    EchoelmusicProEditor (EchoelmusicProProcessor&);
    ~EchoelmusicProEditor() override;

    //==============================================================================
    void paint (juce::Graphics&) override;
    void resized() override;

private:
    // Reference to the processor
    EchoelmusicProProcessor& audioProcessor;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (EchoelmusicProEditor)
};
