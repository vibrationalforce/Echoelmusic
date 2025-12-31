#pragma once

#include <JuceHeader.h>
#include <array>
#include <atomic>

/**
 * OptoCompressor - Teletronix LA-2A Optical Compressor Emulation
 *
 * The legendary tube/optical compressor (1965):
 * - T4 electro-luminescent panel + photoresistor
 * - Tube makeup gain stage (12AX7)
 * - Output transformer
 * - Program-dependent attack/release (no user controls)
 *
 * Famous characteristics:
 * - Smooth, musical compression (impossible to sound bad)
 * - Slow attack (10ms), medium release (60ms-several seconds)
 * - Gentle peak reduction
 * - Tube warmth & saturation
 * - "Glow" on transients
 *
 * Used on: Vocals, bass, mix bus (Motown, Stax, countless hits)
 * Artists: Frank Sinatra, The Beatles, Marvin Gaye, Amy Winehouse
 */
class OptoCompressor
{
public:
    OptoCompressor();
    ~OptoCompressor();

    //==============================================================================
    // Processing

    void prepare(double sampleRate, int samplesPerBlock, int numChannels);
    void reset();

    void process(juce::AudioBuffer<float>& buffer);
    float processSample(float sample, int channel);

    //==============================================================================
    // Controls (LA-2A Style - Simple!)

    void setPeakReduction(float amount);      // 0.0 to 1.0 (replaces threshold - LA-2A "Gain" knob)
    void setMakeupGain(float gainDb);         // 0dB to +40dB (LA-2A "Peak Reduction" knob)
    void setCompressLimitMode(bool limit);    // false = Compress, true = Limit (LA-2A switch)

    //==============================================================================
    // Optical Cell Characteristics

    void setAttackTime(float timeMs);         // 10ms default (optical cell response)
    void setReleaseTime(float timeMs);        // 60ms-5s (program-dependent)
    void setOpticalCharacter(float amount);   // 0.0 to 1.0 (T4 cell non-linearity)

    //==============================================================================
    // Tube Stage

    void setTubeWarmth(float amount);         // 0.0 to 1.0 (12AX7 saturation)
    void setOutputTransformer(float amount);  // 0.0 to 1.0 (iron core coloration)

    //==============================================================================
    // Advanced (not on original LA-2A)

    void setSidechainHPF(float frequency);    // 0Hz = off, 20-500Hz
    void setStereoLink(float amount);         // 0.0 = dual mono, 1.0 = linked

    //==============================================================================
    // Metering

    float getGainReduction() const;           // Current GR in dB
    float getInputLevel(int channel) const;
    float getOutputLevel(int channel) const;
    float getOpticalCellState() const;        // 0.0 to 1.0 (light level in T4 cell)

    //==============================================================================
    // Presets

    enum class Preset
    {
        Vintage,           // Classic LA-2A settings
        VocalSmooth,       // Gentle vocal compression
        VocalAggressive,   // Heavy vocal leveling
        Bass,              // Bass guitar/synth
        MixBus,            // Subtle mix glue
        DrumRoom,          // Room mic compression
        Limiting,          // Peak limiting mode
        AllButtons         // "All buttons in" (LA-2A secret mode)
    };

    void loadPreset(Preset preset);

private:
    //==============================================================================
    // DSP State

    double currentSampleRate = 48000.0;
    int currentNumChannels = 2;

    // LA-2A Controls
    float peakReduction = 0.5f;   // 0.0 to 1.0
    float makeupGain = 0.0f;      // dB
    bool limitMode = false;       // Compress vs Limit

    // Optical Cell (T4 Electro-Luminescent Panel)
    struct OpticalCellState
    {
        float lightLevel = 0.0f;         // Brightness of EL panel
        float resistance = 1.0f;         // Photoresistor resistance
        float attackCoeff = 0.0f;
        float releaseCoeff = 0.0f;
    };
    std::array<OpticalCellState, 2> opticalCell;
    float opticalCharacter = 0.7f;
    float attackTimeMs = 10.0f;
    float releaseTimeMs = 60.0f;

    // Tube Stage (12AX7 Makeup Gain)
    float tubeWarmth = 0.6f;

    // Output Transformer
    float outputTransformer = 0.7f;

    // Advanced
    float sidechainHPF = 0.0f;
    float stereoLink = 1.0f;

    // Sidechain HPF
    struct HPFState
    {
        float z1 = 0.0f, z2 = 0.0f;
        float b0 = 1.0f, b1 = 0.0f, b2 = 0.0f;
        float a1 = 0.0f, a2 = 0.0f;
    };
    std::array<HPFState, 2> hpfState;

    // Metering
    std::array<float, 2> inputLevelSmooth = {0.0f, 0.0f};
    std::array<float, 2> outputLevelSmooth = {0.0f, 0.0f};
    // OPTIMIZATION: Atomic for thread-safe UI metering access
    std::atomic<float> gainReductionSmooth { 0.0f };
    std::atomic<float> opticalCellStateSmooth { 0.0f };

    //==============================================================================
    // Internal Helpers

    void updateOpticalCellCoefficients();
    void updateSidechainHPFCoefficients();

    float processSidechainHPF(float sample, int channel);
    float processOpticalCompression(float sample, int channel, float sidechainSignal);
    float processTubeStage(float sample);
    float processOutputTransformer(float sample);

    // LA-2A specific algorithms
    float opticalCellResponse(float inputLevel, float& lightLevel, float& resistance, int channel);
    float tubeSaturation(float sample, float warmth);
    float transformerColoration(float sample, float amount);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(OptoCompressor)
};
