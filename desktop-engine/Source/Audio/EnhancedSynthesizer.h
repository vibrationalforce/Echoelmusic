// EnhancedSynthesizer.h
// Enhanced synthesizer with effects chain and FFT analysis
// Integrates: BasicSynthesizer + ReverbEffect + DelayEffect + FilterEffect + FFTAnalyzer

#pragma once
#include <JuceHeader.h>
#include "BasicSynthesizer.h"
#include "ReverbEffect.h"
#include "DelayEffect.h"
#include "FilterEffect.h"
#include "../DSP/FFTAnalyzer.h"

class EnhancedSynthesizer : public juce::AudioSource
{
public:
    EnhancedSynthesizer();
    ~EnhancedSynthesizer() override;

    // AudioSource interface
    void prepareToPlay(int samplesPerBlockExpected, double sampleRate) override;
    void getNextAudioBlock(const juce::AudioSourceChannelInfo& bufferToFill) override;
    void releaseResources() override;

    // Biofeedback parameter setters
    void setHeartRate(float bpm);
    void setHRV(float ms);
    void setBreathRate(float breathsPerMinute);
    void setHRVCoherence(float coherence);
    void setPitch(float frequency, float confidence);

    // Analysis getters
    std::vector<float> getSpectrum() const;
    float getRMS() const;
    float getPeak() const;

private:
    // Core synthesizer
    std::unique_ptr<BasicSynthesizer> basicSynth;

    // Effects chain (order: Synth → Filter → Delay → Reverb)
    std::unique_ptr<FilterEffect> filterEffect;
    std::unique_ptr<DelayEffect> delayEffect;
    std::unique_ptr<ReverbEffect> reverbEffect;

    // Analysis
    std::unique_ptr<FFTAnalyzer> fftAnalyzer;

    // Temporary buffer for processing
    juce::AudioBuffer<float> processingBuffer;

    // Current biofeedback values
    std::atomic<float> currentHeartRate{60.0f};
    std::atomic<float> currentHRV{50.0f};
    std::atomic<float> currentBreathRate{15.0f};
    std::atomic<float> currentCoherence{0.5f};

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(EnhancedSynthesizer)
};
