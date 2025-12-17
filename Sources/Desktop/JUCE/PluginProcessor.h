/*
  ==============================================================================

    Echoelmusic Pro - JUCE Plugin Processor
    Professional Audio Plugin with 96 DSP Processors

    License: JUCE Commercial ($900/year) or GPL v3
    Copyright (c) 2025 Echoelmusic

  ==============================================================================
*/

#pragma once

#include <juce_audio_processors/juce_audio_processors.h>
#include <juce_dsp/juce_dsp.h>
#include "../../DSP/AdvancedDSPManager.h"

//==============================================================================
/**
 * Echoelmusic Pro Audio Processor
 *
 * Features:
 * - 11 Synthesis Methods (Subtractive, FM, Wavetable, Granular, Physical Modeling,
 *   Additive, Vector, Modal, Sample, Drum, Hybrid)
 * - 96 Professional DSP Processors
 * - 202 Factory Presets
 * - Bio-Reactive Audio (HRV, Coherence, Stress)
 * - ML-Based Tone Matching
 * - Advanced Spectral Processing
 * - SIMD Optimizations (AVX2/NEON)
 */
class EchoelmusicProProcessor : public juce::AudioProcessor
{
public:
    //==============================================================================
    EchoelmusicProProcessor();
    ~EchoelmusicProProcessor() override;

    //==============================================================================
    void prepareToPlay (double sampleRate, int samplesPerBlock) override;
    void releaseResources() override;

   #ifndef JucePlugin_PreferredChannelConfigurations
    bool isBusesLayoutSupported (const BusesLayout& layouts) const override;
   #endif

    void processBlock (juce::AudioBuffer<float>&, juce::MidiBuffer&) override;

    //==============================================================================
    juce::AudioProcessorEditor* createEditor() override;
    bool hasEditor() const override;

    //==============================================================================
    const juce::String getName() const override;

    bool acceptsMidi() const override;
    bool producesMidi() const override;
    bool isMidiEffect() const override;
    double getTailLengthSeconds() const override;

    //==============================================================================
    int getNumPrograms() override;
    int getCurrentProgram() override;
    void setCurrentProgram (int index) override;
    const juce::String getProgramName (int index) override;
    void changeProgramName (int index, const juce::String& newName) override;

    //==============================================================================
    void getStateInformation (juce::MemoryBlock& destData) override;
    void setStateInformation (const void* data, int sizeInBytes) override;

    //==============================================================================
    // Advanced DSP Manager Access
    AdvancedDSPManager& getAdvancedDSPManager() { return advancedDSPManager; }

private:
    //==============================================================================
    // Audio Processing State
    double currentSampleRate = 44100.0;
    int currentBlockSize = 512;

    // SIMD Processing
    juce::dsp::ProcessorDuplicator<juce::dsp::IIR::Filter<float>,
                                     juce::dsp::IIR::Coefficients<float>> lowPassFilter;

    // Advanced DSP Manager (96 processors + presets)
    AdvancedDSPManager advancedDSPManager;

    // Synthesis Engine (will be connected to actual synthesis modules)
    struct SynthVoice {
        float frequency = 440.0f;
        float phase = 0.0f;
        float amplitude = 0.0f;
        bool active = false;
    };

    std::array<SynthVoice, 16> voices; // 16-voice polyphony

    //==============================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (EchoelmusicProProcessor)
};
