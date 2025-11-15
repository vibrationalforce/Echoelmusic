// BasicSynthesizer.h
// Simple synthesizer that responds to biofeedback data
// Heart Rate → Frequency, HRV → Reverb

#pragma once
#include <JuceHeader.h>

class BasicSynthesizer : public juce::AudioSource
{
public:
    BasicSynthesizer();
    ~BasicSynthesizer() override;

    // AudioSource Implementation
    void prepareToPlay(int samplesPerBlockExpected, double sampleRate) override;
    void releaseResources() override;
    void getNextAudioBlock(const juce::AudioSourceChannelInfo& bufferToFill) override;

    // Biofeedback Control
    void setHeartRate(float bpm);
    void setHRV(float ms);
    void setHRVCoherence(float coherence);  // 0-1
    void setPitch(float frequency, float confidence);

    // Parameter Mapping
    void setParameterMappingEnabled(bool enabled);

private:
    // Oscillator
    double currentAngle = 0.0;
    double angleDelta = 0.0;
    double frequency = 220.0;  // Default A3
    double sampleRate = 44100.0;

    // Biofeedback State
    std::atomic<float> currentHeartRate{60.0f};
    std::atomic<float> currentHRV{50.0f};
    std::atomic<float> currentCoherence{0.5f};
    std::atomic<float> currentPitchFreq{0.0f};

    // Mapping
    bool mappingEnabled = true;

    // Smoothing (exponential moving average)
    float smoothedFrequency = 220.0f;
    const float smoothingAlpha = 0.1f;

    // Amplitude envelope
    float amplitude = 0.3f;

    // Parameter mapping functions
    float mapHeartRateToFrequency(float bpm);
    float mapHRVToAmplitude(float hrv);
    float mapCoherenceToWaveform(float coherence);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(BasicSynthesizer)
};
