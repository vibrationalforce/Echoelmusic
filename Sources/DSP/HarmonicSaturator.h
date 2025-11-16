#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>

/**
 * HarmonicSaturator
 *
 * Professional analog-modeled saturation and distortion inspired by Soundtoys Decapitator.
 * Adds warmth, character, and harmonics to any audio source.
 *
 * Features:
 * - 10+ saturation models (tube, tape, transistor, transformer, etc.)
 * - Harmonic enhancement and generation
 * - Punish mode for extreme distortion
 * - Mix control for parallel processing
 * - High/low cut filters
 * - Auto-gain compensation
 * - Oversampling (up to 8x) for alias-free processing
 * - Stereo width control
 * - Tone shaping
 * - Real-time harmonic analysis display
 */
class HarmonicSaturator
{
public:
    //==========================================================================
    // Saturation Models
    //==========================================================================

    enum class SaturationModel
    {
        Clean,              // Transparent soft clipping
        Warm,               // Gentle tube-style warmth
        Tube,               // Classic tube amplifier
        Tape,               // Analog tape saturation
        Transistor,         // Solid-state transistor
        Transformer,        // Iron transformer
        FET,                // Field-effect transistor
        OpAmp,              // Operational amplifier clipping
        Diode,              // Diode clipper
        Foldback,           // Wave folder
        Punish,             // Extreme aggressive distortion
        Custom              // User-defined transfer curve
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    HarmonicSaturator();
    ~HarmonicSaturator() = default;

    //==========================================================================
    // Parameters
    //==========================================================================

    /** Set saturation model */
    void setSaturationModel(SaturationModel model);
    SaturationModel getSaturationModel() const { return currentModel; }

    /** Set drive (0.0 to 1.0, mapped to dB range) */
    void setDrive(float drive);
    float getDrive() const { return driveAmount; }

    /** Set output level (-24 to +24 dB) */
    void setOutputLevel(float dB);
    float getOutputLevel() const { return outputLevelDb; }

    /** Set dry/wet mix (0.0 to 1.0) */
    void setMix(float mix);
    float getMix() const { return wetMix; }

    /** Set tone (-1.0 = dark, 0.0 = neutral, +1.0 = bright) */
    void setTone(float tone);
    float getTone() const { return toneControl; }

    /** Set high-pass cutoff (20 to 500 Hz, 0 = off) */
    void setHighPassCutoff(float freq);
    float getHighPassCutoff() const { return highPassFreq; }

    /** Set low-pass cutoff (1k to 20k Hz, 20k = off) */
    void setLowPassCutoff(float freq);
    float getLowPassCutoff() const { return lowPassFreq; }

    /** Set punish amount (0.0 to 1.0) - extreme distortion */
    void setPunish(float amount);
    float getPunish() const { return punishAmount; }

    /** Set stereo width (0.0 = mono, 1.0 = normal, 2.0 = wide) */
    void setStereoWidth(float width);
    float getStereoWidth() const { return stereoWidth; }

    /** Enable/disable auto-gain compensation */
    void setAutoGain(bool enabled);
    bool isAutoGainEnabled() const { return autoGain; }

    /** Set oversampling factor (1, 2, 4, 8) */
    void setOversamplingFactor(int factor);
    int getOversamplingFactor() const { return oversamplingFactor; }

    //==========================================================================
    // Advanced Parameters
    //==========================================================================

    /** Set bias (DC offset for asymmetric distortion, -1.0 to +1.0) */
    void setBias(float bias);
    float getBias() const { return biasAmount; }

    /** Set even/odd harmonic balance (-1.0 = even, +1.0 = odd) */
    void setHarmonicBalance(float balance);
    float getHarmonicBalance() const { return harmonicBalance; }

    /** Set saturation curve shape (0.0 = soft, 1.0 = hard) */
    void setCurveShape(float shape);
    float getCurveShape() const { return curveShape; }

    //==========================================================================
    // Processing
    //==========================================================================

    void prepare(double sampleRate, int maxBlockSize);
    void reset();
    void process(juce::AudioBuffer<float>& buffer);

    //==========================================================================
    // Analysis & Visualization
    //==========================================================================

    /** Get harmonic content analysis (fundamental + harmonics 2-10) */
    struct HarmonicAnalysis
    {
        float fundamental = 0.0f;
        std::array<float, 10> harmonics = {0};  // 2nd through 11th harmonic
        float THD = 0.0f;                        // Total harmonic distortion %
        float crestFactor = 0.0f;
    };

    HarmonicAnalysis getHarmonicAnalysis() const { return harmonicAnalysis; }

    /** Get transfer curve for visualization (256 points, -1.0 to +1.0) */
    std::vector<float> getTransferCurve() const;

    /** Get input/output levels (dB) */
    float getInputLevel() const { return inputLevelDb; }
    float getOutputMeterLevel() const { return outputMeterLevelDb; }

    /** Get gain reduction/addition (dB) */
    float getGainChange() const { return gainChangeDb; }

    //==========================================================================
    // Presets
    //==========================================================================

    /** Load preset by name */
    void loadPreset(const juce::String& presetName);

    /** Get available preset names */
    std::vector<juce::String> getPresetNames() const;

private:
    //==========================================================================
    // Parameters
    //==========================================================================

    SaturationModel currentModel = SaturationModel::Warm;
    float driveAmount = 0.5f;
    float outputLevelDb = 0.0f;
    float wetMix = 1.0f;
    float toneControl = 0.0f;
    float highPassFreq = 0.0f;       // 0 = off
    float lowPassFreq = 20000.0f;    // 20k = off
    float punishAmount = 0.0f;
    float stereoWidth = 1.0f;
    bool autoGain = true;
    int oversamplingFactor = 2;

    // Advanced
    float biasAmount = 0.0f;
    float harmonicBalance = 0.0f;
    float curveShape = 0.5f;

    double currentSampleRate = 48000.0;

    //==========================================================================
    // Processing State
    //==========================================================================

    // Filters
    juce::dsp::IIR::Filter<float> highPassL, highPassR;
    juce::dsp::IIR::Filter<float> lowPassL, lowPassR;
    juce::dsp::IIR::Filter<float> toneFilterL, toneFilterR;

    // Oversampling
    std::unique_ptr<juce::dsp::Oversampling<float>> oversampling;

    // DC blocker (remove DC offset after saturation)
    juce::dsp::IIR::Filter<float> dcBlockerL, dcBlockerR;

    //==========================================================================
    // Metering & Analysis
    //==========================================================================

    float inputLevelDb = -96.0f;
    float outputMeterLevelDb = -96.0f;
    float gainChangeDb = 0.0f;
    HarmonicAnalysis harmonicAnalysis;

    // Analysis
    static constexpr int analysisFFTOrder = 12;
    static constexpr int analysisFFTSize = 1 << analysisFFTOrder;
    juce::dsp::FFT analysisFFT {analysisFFTOrder};
    std::array<float, analysisFFTSize * 2> fftData;
    int fftDataIndex = 0;

    //==========================================================================
    // Internal Buffers
    //==========================================================================

    juce::AudioBuffer<float> dryBuffer;
    juce::AudioBuffer<float> oversampledBuffer;

    //==========================================================================
    // Saturation Functions (Transfer Curves)
    //==========================================================================

    float applySaturation(float input, SaturationModel model);

    // Specific saturation algorithms
    float saturateClean(float x);
    float saturateWarm(float x);
    float saturateTube(float x);
    float saturateTape(float x);
    float saturateTransistor(float x);
    float saturateTransformer(float x);
    float saturateFET(float x);
    float saturateOpAmp(float x);
    float saturateDiode(float x);
    float saturateFoldback(float x);
    float saturatePunish(float x);

    //==========================================================================
    // Harmonic Shaping
    //==========================================================================

    void applyHarmonicShaping(float& sample);
    void applyBias(float& sample);

    //==========================================================================
    // Utilities
    //==========================================================================

    void updateFilters();
    void updateOversampling();
    void analyzeHarmonics(const juce::AudioBuffer<float>& buffer);
    float calculateRMS(const juce::AudioBuffer<float>& buffer);
    float calculatePeak(const juce::AudioBuffer<float>& buffer);
    float calculateAutoGainCompensation(SaturationModel model, float drive);

    //==========================================================================
    // Presets
    //==========================================================================

    struct Preset
    {
        juce::String name;
        SaturationModel model;
        float drive;
        float tone;
        float mix;
        float punish;
    };

    void initializePresets();
    std::vector<Preset> presets;

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (HarmonicSaturator)
};
