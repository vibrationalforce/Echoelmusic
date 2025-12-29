#pragma once

#include <JuceHeader.h>
#include <array>
#include <atomic>
#include <cmath>

/**
 * EchoConsole - SSL G-Series Channel Strip Emulation
 *
 * Professional channel strip featuring:
 * - High-Pass Filter (16Hz-350Hz)
 * - 4-Band EQ (HF, HMF, LMF, LF)
 * - Gate/Expander
 * - VCA Compressor (SSL-style)
 * - Output Gain & Fader
 *
 * Authentic SSL characteristics:
 * - Fast attack times (VCA topology)
 * - Smooth, musical compression
 * - Transparent EQ with subtle saturation
 * - Famous "SSL Punch"
 *
 * Used by: Abbey Road, Electric Lady Studios, countless hit records
 */
class EchoConsole
{
public:
    EchoConsole();
    ~EchoConsole();

    //==============================================================================
    // Processing

    void prepare(double sampleRate, int samplesPerBlock, int numChannels);
    void reset();

    void process(juce::AudioBuffer<float>& buffer);
    float processSample(float sample, int channel);

    //==============================================================================
    // High-Pass Filter

    void setHPFFrequency(float frequency);    // 16Hz - 350Hz
    void setHPFEnabled(bool enabled);

    //==============================================================================
    // 4-Band EQ

    enum class EQBand
    {
        HF,     // High Frequency (shelving)
        HMF,    // High-Mid Frequency (parametric)
        LMF,    // Low-Mid Frequency (parametric)
        LF      // Low Frequency (shelving)
    };

    void setEQGain(EQBand band, float gainDb);       // -15dB to +15dB
    void setEQFrequency(EQBand band, float frequency);
    void setEQQ(EQBand band, float q);               // 0.5 - 4.0
    void setEQEnabled(EQBand band, bool enabled);
    void setEQBellMode(bool bellMode);               // HF/LF: Bell or Shelf

    //==============================================================================
    // Gate/Expander

    void setGateThreshold(float thresholdDb);        // -80dB to 0dB
    void setGateRange(float rangeDb);                // 0dB to -80dB (amount of attenuation)
    void setGateAttack(float attackMs);              // 0.1ms - 100ms
    void setGateRelease(float releaseMs);            // 10ms - 4000ms
    void setGateRatio(float ratio);                  // 1:1 to 10:1 (expander ratio)
    void setGateEnabled(bool enabled);

    //==============================================================================
    // VCA Compressor (SSL-Style)

    void setCompThreshold(float thresholdDb);        // -40dB to +20dB
    void setCompRatio(float ratio);                  // 1:1 to 20:1 (with "British Mode" at 10:1+)
    void setCompAttack(float attackMs);              // 0.1ms - 30ms (fast SSL attack)
    void setCompRelease(float releaseMs);            // 0.1s - 4s (with Auto mode)
    void setCompAutoRelease(bool autoRelease);       // Program-dependent release
    void setCompMakeupGain(float gainDb);            // 0dB to +20dB
    void setCompEnabled(bool enabled);

    //==============================================================================
    // Output Section

    void setOutputGain(float gainDb);                // -20dB to +20dB
    void setPhaseInvert(bool invert);
    void setAnalogSaturation(float amount);          // 0.0 to 1.0 (subtle SSL transformer saturation)

    //==============================================================================
    // Metering

    float getInputLevel(int channel) const;
    float getOutputLevel(int channel) const;
    float getGainReduction() const;                  // Gate + Compressor combined

    //==============================================================================
    // Presets

    enum class Preset
    {
        Neutral,            // Flat, transparent
        VocalCompression,   // SSL-style vocal compression
        DrumBus,           // Punchy drum bus compression
        MixBus,            // Gentle mix bus glue
        AggressiveMix,     // Heavy compression & EQ
        VintageWarmth,     // Analog saturation emphasis
        Transparent,       // Clean, modern
        BritishPunch       // Classic SSL punch
    };

    void loadPreset(Preset preset);

private:
    //==============================================================================
    // DSP State

    double currentSampleRate = 48000.0;
    int currentNumChannels = 2;

    // High-Pass Filter (12dB/oct Butterworth)
    struct HPFState
    {
        float z1 = 0.0f, z2 = 0.0f;
        float b0 = 1.0f, b1 = 0.0f, b2 = 0.0f;
        float a1 = 0.0f, a2 = 0.0f;
    };
    std::array<HPFState, 2> hpfState;
    bool hpfEnabled = false;
    float hpfFrequency = 80.0f;

    // 4-Band EQ
    struct EQState
    {
        juce::dsp::IIR::Filter<float> filter;
        float gain = 0.0f;
        float frequency = 1000.0f;
        float q = 0.7f;
        bool enabled = false;
    };
    std::array<std::array<EQState, 4>, 2> eqState;  // [channel][band]
    bool eqBellMode = false;  // true = bell for HF/LF, false = shelf

    // Gate/Expander
    struct GateState
    {
        float envelope = 0.0f;
        float attackCoeff = 0.0f;
        float releaseCoeff = 0.0f;
    };
    std::array<GateState, 2> gateState;
    bool gateEnabled = false;
    float gateThreshold = -40.0f;
    float gateRange = -80.0f;
    float gateRatio = 2.0f;

    // VCA Compressor
    struct CompressorState
    {
        float envelope = 0.0f;
        float attackCoeff = 0.0f;
        float releaseCoeff = 0.0f;
        float autoReleaseTime = 0.4f;  // Program-dependent
    };
    std::array<CompressorState, 2> compState;
    bool compEnabled = false;
    float compThreshold = -10.0f;
    float compRatio = 4.0f;
    float compMakeupGain = 0.0f;
    bool compAutoRelease = true;
    float compReleaseMs = 400.0f;

    // Output
    float outputGain = 0.0f;
    bool phaseInvert = false;
    float analogSaturation = 0.3f;  // Subtle by default

    // Metering
    std::array<float, 2> inputLevelSmooth = {0.0f, 0.0f};
    std::array<float, 2> outputLevelSmooth = {0.0f, 0.0f};
    // OPTIMIZATION: Atomic for thread-safe UI metering access
    std::atomic<float> gainReductionSmooth { 0.0f };

    //==============================================================================
    // Internal Helpers

    void updateHPFCoefficients();
    void updateEQCoefficients(int channel, EQBand band);
    void updateGateCoefficients();
    void updateCompressorCoefficients();

    float processHPF(float sample, int channel);
    float processEQ(float sample, int channel);
    float processGate(float sample, int channel);
    float processCompressor(float sample, int channel);
    float processSaturation(float sample);

    // SSL-style VCA compression curve
    float sslCompressorCurve(float inputDb, float threshold, float ratio);

    // Analog saturation (subtle transformer coloration)
    float transformerSaturation(float sample, float amount);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(EchoConsole)
};
