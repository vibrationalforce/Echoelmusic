#pragma once

#include <JuceHeader.h>
#include <array>

/**
 * ClassicPreamp - Neve 1073 Preamp/EQ Emulation
 *
 * The legendary Neve 1073 microphone preamplifier and equalizer:
 * - Class-A preamp with transformer-coupled input/output
 * - 3-Band EQ with fixed frequencies
 * - High-Pass Filter (18dB/oct)
 * - Harmonic distortion & saturation
 *
 * Famous characteristics:
 * - Rich harmonic content (2nd & 3rd harmonics)
 * - Smooth, musical EQ curves
 * - Transformer "thickness" and warmth
 * - Punchy low-end, silky highs
 *
 * Used on: Beatles, Led Zeppelin, Pink Floyd, countless classics
 * Studios: Abbey Road, Olympic Studios, Electric Lady
 */
class ClassicPreamp
{
public:
    ClassicPreamp();
    ~ClassicPreamp();

    //==============================================================================
    // Processing

    void prepare(double sampleRate, int samplesPerBlock, int numChannels);
    void reset();

    void process(juce::AudioBuffer<float>& buffer);
    float processSample(float sample, int channel);

    //==============================================================================
    // Preamp Section

    void setInputGain(float gainDb);          // -20dB to +80dB (mic preamp range)
    void setInputImpedance(float ohms);       // 300Ω, 1200Ω (typical Neve settings)
    void setPreampDrive(float amount);        // 0.0 to 1.0 (Class-A saturation)

    //==============================================================================
    // High-Pass Filter

    void setHPFFrequency(float frequency);    // 50Hz, 80Hz, 160Hz, 300Hz (Neve steps)
    void setHPFEnabled(bool enabled);

    //==============================================================================
    // 3-Band EQ (Fixed Frequencies - Neve 1073 Style)

    // High Frequency (Shelf)
    void setHighFrequency(int frequencyIndex); // 0=12kHz, 1=16kHz (fixed Neve frequencies)
    void setHighGain(float gainDb);            // -16dB to +16dB
    void setHighEnabled(bool enabled);

    // Mid Frequency (Parametric)
    void setMidFrequency(int frequencyIndex);  // 0=0.36k, 1=0.7k, 2=1.6k, 3=3.2k, 4=4.8k, 5=7.2k
    void setMidGain(float gainDb);             // -18dB to +18dB
    void setMidEnabled(bool enabled);

    // Low Frequency (Shelf)
    void setLowFrequency(int frequencyIndex);  // 0=35Hz, 1=60Hz, 2=110Hz, 3=220Hz
    void setLowGain(float gainDb);             // -16dB to +16dB
    void setLowEnabled(bool enabled);

    //==============================================================================
    // Output Section

    void setOutputGain(float gainDb);          // -20dB to +20dB
    void setPhaseInvert(bool invert);
    void setTransformerColoration(float amount); // 0.0 to 1.0 (output transformer saturation)

    //==============================================================================
    // Metering

    float getInputLevel(int channel) const;
    float getOutputLevel(int channel) const;
    float getHarmonicContent() const;          // Amount of harmonic distortion

    //==============================================================================
    // Presets

    enum class Preset
    {
        Clean,                // Minimal coloration
        VocalWarmth,          // Classic vocal sound
        KickDrum,             // Punchy kick processing
        Snare,                // Snappy snare
        Bass,                 // Thick bass
        AcousticGuitar,       // Natural acoustic
        OverheadCymbal,       // Smooth highs
        VintageMax            // Maximum Neve color
    };

    void loadPreset(Preset preset);

private:
    //==============================================================================
    // DSP State

    double currentSampleRate = 48000.0;
    int currentNumChannels = 2;

    // Preamp
    float inputGain = 0.0f;
    float preampDrive = 0.5f;

    // High-Pass Filter (18dB/oct - 3-pole Butterworth)
    struct HPFState
    {
        std::array<float, 3> z = {0.0f, 0.0f, 0.0f};
        std::array<float, 4> b = {1.0f, 0.0f, 0.0f, 0.0f};
        std::array<float, 3> a = {0.0f, 0.0f, 0.0f};
    };
    std::array<HPFState, 2> hpfState;
    bool hpfEnabled = false;
    int hpfFrequencyIndex = 1;  // 80Hz default
    static constexpr std::array<float, 4> HPF_FREQUENCIES = {50.0f, 80.0f, 160.0f, 300.0f};

    // EQ Bands
    struct EQBand
    {
        juce::dsp::IIR::Filter<float> filter;
        float gain = 0.0f;
        int frequencyIndex = 0;
        bool enabled = false;
    };
    std::array<std::array<EQBand, 3>, 2> eqBands;  // [channel][High/Mid/Low]

    // Neve 1073 fixed frequencies
    static constexpr std::array<float, 2> HIGH_FREQUENCIES = {12000.0f, 16000.0f};
    static constexpr std::array<float, 6> MID_FREQUENCIES = {360.0f, 700.0f, 1600.0f, 3200.0f, 4800.0f, 7200.0f};
    static constexpr std::array<float, 4> LOW_FREQUENCIES = {35.0f, 60.0f, 110.0f, 220.0f};

    // Output
    float outputGain = 0.0f;
    bool phaseInvert = false;
    float transformerColoration = 0.7f;  // Neve has prominent transformer sound

    // Metering
    std::array<float, 2> inputLevelSmooth = {0.0f, 0.0f};
    std::array<float, 2> outputLevelSmooth = {0.0f, 0.0f};
    float harmonicContentSmooth = 0.0f;

    //==============================================================================
    // Internal Helpers

    void updateHPFCoefficients();
    void updateEQCoefficients(int channel, int band);

    float processInputStage(float sample, int channel);
    float processHPF(float sample, int channel);
    float processEQ(float sample, int channel);
    float processOutputStage(float sample, int channel);

    // Neve-specific algorithms
    float classAPreampSaturation(float sample, float drive);
    float inputTransformerSaturation(float sample);
    float outputTransformerSaturation(float sample, float amount);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ClassicPreamp)
};
