#pragma once

#include <JuceHeader.h>
#include <array>
#include <atomic>

/**
 * FETCompressor - UREI 1176 Peak Limiter Emulation
 *
 * The legendary FET (Field-Effect Transistor) compressor (1967):
 * - Ultra-fast attack (20-800μs)
 * - Class-A FET gain reduction
 * - All-buttons-in "British" mode
 * - Fixed ratios (4:1, 8:1, 12:1, 20:1)
 *
 * Famous characteristics:
 * - Aggressive, punchy compression
 * - Harmonic distortion (FET coloration)
 * - Can add aggression or smooth out
 * - "All buttons" secret mode = explosive drums
 *
 * Used on: Drums, bass, vocals (Led Zeppelin, Aerosmith, modern rock/pop)
 */
class FETCompressor
{
public:
    FETCompressor();
    ~FETCompressor();

    void prepare(double sampleRate, int samplesPerBlock, int numChannels);
    void reset();
    void process(juce::AudioBuffer<float>& buffer);
    float processSample(float sample, int channel);

    //==============================================================================
    // 1176 Controls

    void setInputGain(float gainDb);           // -20dB to +40dB
    void setOutputGain(float gainDb);          // -20dB to +20dB
    void setAttack(float attackUs);            // 20-800μs (microseconds!)
    void setRelease(float releaseMs);          // 50-1100ms
    void setRatio(int ratio);                  // 4, 8, 12, 20 (fixed 1176 ratios)
    void setAllButtonsMode(bool enabled);      // Secret "all buttons" mode

    //==============================================================================
    // Advanced

    void setFETColoration(float amount);       // 0.0-1.0 (FET harmonic distortion)
    void setStereoLink(bool linked);

    //==============================================================================
    // Metering

    float getGainReduction() const;
    float getInputLevel(int channel) const;
    float getOutputLevel(int channel) const;

    //==============================================================================
    // Presets

    enum class Preset
    {
        Vintage,
        VocalSmash,
        DrumCrush,
        BassSlam,
        AllButtons,
        GentleGlue,
        FastPeak
    };

    void loadPreset(Preset preset);

private:
    double currentSampleRate = 48000.0;
    int currentNumChannels = 2;

    float inputGain = 0.0f;
    float outputGain = 0.0f;
    float attackUs = 250.0f;
    float releaseMs = 400.0f;
    int ratio = 4;
    bool allButtonsMode = false;
    float fetColoration = 0.7f;
    bool stereoLink = true;

    // Cached linear gain values (avoid per-sample dB conversion)
    float inputGainLinear = 1.0f;
    float outputGainLinear = 1.0f;

    struct CompressorState
    {
        float envelope = 0.0f;
        float attackCoeff = 0.0f;
        float releaseCoeff = 0.0f;
    };
    std::array<CompressorState, 2> compState;

    std::array<float, 2> inputLevelSmooth = {0.0f, 0.0f};
    std::array<float, 2> outputLevelSmooth = {0.0f, 0.0f};
    // OPTIMIZATION: Atomic for thread-safe UI metering access
    std::atomic<float> gainReductionSmooth { 0.0f };

    void updateCoefficients();
    float processFETCompression(float sample, int channel, float linkedSidechain = 0.0f);
    float fetSaturation(float sample, float amount);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(FETCompressor)
};
