#pragma once

#include <JuceHeader.h>
#include <array>

/**
 * PassiveEQ - Pultec EQP-1A Program Equalizer Emulation
 *
 * The legendary passive tube EQ (1951):
 * - Low frequency boost & attenuation (simultaneous!)
 * - High frequency boost
 * - Passive LC network (inductor/capacitor)
 * - Tube makeup gain (12AX7)
 *
 * Famous characteristics:
 * - Musical, smooth curves
 * - Low-end "Pultec trick" (boost + attenuate = tight punch)
 * - Silky high-end
 * - Tube warmth
 *
 * Used on: Mix bus, vocals, kick, bass (Motown, Stax, modern mastering)
 */
class PassiveEQ
{
public:
    PassiveEQ();
    ~PassiveEQ();

    void prepare(double sampleRate, int samplesPerBlock, int numChannels);
    void reset();
    void process(juce::AudioBuffer<float>& buffer);
    float processSample(float sample, int channel);

    //==============================================================================
    // Pultec EQP-1A Controls

    // Low Frequency
    void setLowBoost(float boostDb);              // 0-10dB
    void setLowBoostFrequency(int freqIndex);     // 0=20Hz, 1=30Hz, 2=60Hz, 3=100Hz
    void setLowAttenuation(float attenuationDb);  // 0-10dB
    void setLowAttenuationFrequency(int freqIndex); // 0=20Hz, 1=30Hz, 2=60Hz, 3=100Hz

    // High Frequency
    void setHighBoost(float boostDb);             // 0-18dB
    void setHighBoostFrequency(int freqIndex);    // 0=3kHz, 1=4kHz, 2=5kHz, 3=8kHz, 4=10kHz, 5=12kHz, 6=16kHz
    void setHighAttenuation(float attenuationDb); // 0-10dB (5kHz, 10kHz, 20kHz selectable)

    // Bandwidth
    void setLowBandwidth(float q);                // 0.5-2.0 (sharp to broad)
    void setHighBandwidth(float q);               // 0.5-2.0

    //==============================================================================
    // Tube & Transformer

    void setTubeWarmth(float amount);             // 0.0-1.0
    void setOutputTransformer(float amount);      // 0.0-1.0

    //==============================================================================
    // Metering

    float getInputLevel(int channel) const;
    float getOutputLevel(int channel) const;

    //==============================================================================
    // Presets

    enum class Preset
    {
        Flat,
        PultecTrick,        // Famous "boost + cut" for tight low end
        VocalAir,           // Silky highs
        KickPunch,          // Tight, punchy kick
        MixBusGlue,         // Gentle enhancement
        VintageWarmth,      // Maximum tube color
        ModernBright        // Clean, bright
    };

    void loadPreset(Preset preset);

private:
    double currentSampleRate = 48000.0;

    // Pultec frequencies (fixed on original hardware)
    static constexpr std::array<float, 4> LOW_FREQUENCIES = {20.0f, 30.0f, 60.0f, 100.0f};
    static constexpr std::array<float, 7> HIGH_FREQUENCIES = {3000.0f, 4000.0f, 5000.0f, 8000.0f, 10000.0f, 12000.0f, 16000.0f};

    float lowBoost = 0.0f;
    int lowBoostFreqIndex = 2;  // 60Hz default
    float lowAttenuation = 0.0f;
    int lowAttenuationFreqIndex = 2;
    float highBoost = 0.0f;
    int highBoostFreqIndex = 4;  // 10kHz default
    float highAttenuation = 0.0f;
    float lowQ = 0.7f;
    float highQ = 0.7f;

    float tubeWarmth = 0.6f;
    float outputTransformer = 0.5f;

    // EQ filters (per channel)
    struct EQState
    {
        juce::dsp::IIR::Filter<float> lowBoostFilter;
        juce::dsp::IIR::Filter<float> lowCutFilter;
        juce::dsp::IIR::Filter<float> highBoostFilter;
        juce::dsp::IIR::Filter<float> highCutFilter;
    };
    std::array<EQState, 2> eqState;

    std::array<float, 2> inputLevelSmooth = {0.0f, 0.0f};
    std::array<float, 2> outputLevelSmooth = {0.0f, 0.0f};

    void updateFilters();
    float processTubeStage(float sample);
    float processTransformer(float sample);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(PassiveEQ)
};
