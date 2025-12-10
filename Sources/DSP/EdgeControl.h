#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>

/**
 * EdgeControl
 *
 * Professional clipper and soft limiter for loudness maximization.
 * Inspired by Kazrog K-Clip, StandardCLIP, GClip, with evolved features.
 *
 * Features:
 * - Multiple clipping algorithms (soft, hard, tube, diode, transformer)
 * - Variable knee (0-12dB)
 * - Oversampling (up to 8x)
 * - True peak limiting
 * - Multiband clipping (3 bands)
 * - Auto-makeup gain
 * - Parallel processing
 * - Real-time waveform/spectrum display
 * - Zero-latency mode
 */
class EdgeControl
{
public:
    //==========================================================================
    // Clipping Type
    //==========================================================================

    enum class ClipType
    {
        SoftClip,        // Smooth soft clipping (tanh)
        HardClip,        // Hard digital clipping
        TubeClip,        // Tube-style asymmetric clipping
        DiodeClip,       // Diode clipping simulation
        TransformerClip, // Transformer saturation
        AnalogClip       // Analog tape-style clipping
    };

    //==========================================================================
    // Processing Mode
    //==========================================================================

    enum class ProcessingMode
    {
        Stereo,          // Standard stereo processing
        MidSide,         // Mid/Side processing
        Multiband        // 3-band multiband clipping
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    EdgeControl();
    ~EdgeControl() = default;

    //==========================================================================
    // Clipping Parameters
    //==========================================================================

    /** Set clipping type */
    void setClipType(ClipType type);
    ClipType getClipType() const { return clipType; }

    /** Set threshold in dB (-20 to 0) */
    void setThreshold(float thresholdDb);
    float getThreshold() const { return thresholdDb; }

    /** Set knee in dB (0 to 12) */
    void setKnee(float kneeDb);
    float getKnee() const { return kneeDb; }

    /** Set ceiling in dB (-1 to 0) */
    void setCeiling(float ceilingDb);
    float getCeiling() const { return ceilingDb; }

    //==========================================================================
    // Processing Mode
    //==========================================================================

    void setProcessingMode(ProcessingMode mode);
    ProcessingMode getProcessingMode() const { return processingMode; }

    //==========================================================================
    // Multiband Parameters (when mode = Multiband)
    //==========================================================================

    /** Set crossover frequencies (Hz) */
    void setCrossoverLow(float freq);    // Low/Mid crossover
    void setCrossoverHigh(float freq);   // Mid/High crossover

    /** Set per-band threshold offset (dB) */
    void setBandThreshold(int band, float offsetDb);  // band: 0=Low, 1=Mid, 2=High

    //==========================================================================
    // Global Parameters
    //==========================================================================

    /** Set input gain in dB (-20 to +20) */
    void setInputGain(float gainDb);

    /** Set output gain in dB (-20 to +20) */
    void setOutputGain(float gainDb);

    /** Enable/disable auto-makeup gain */
    void setAutoMakeup(bool enabled);

    /** Set dry/wet mix (0.0 to 1.0) */
    void setMix(float mixAmount);

    /** Set oversampling factor (1, 2, 4, 8) */
    void setOversampling(int factor);

    /** Enable/disable true peak detection */
    void setTruePeakMode(bool enabled);

    //==========================================================================
    // Processing
    //==========================================================================

    /** Prepare for processing */
    void prepare(double sampleRate, int maxBlockSize);

    /** Reset all states */
    void reset();

    /** Process audio buffer */
    void process(juce::AudioBuffer<float>& buffer);

    //==========================================================================
    // Metering
    //==========================================================================

    /** Get input level in dB */
    float getInputLevel() const;

    /** Get output level in dB */
    float getOutputLevel() const;

    /** Get gain reduction in dB */
    float getGainReduction() const;

    /** Get clipping amount (0.0 to 1.0) */
    float getClippingAmount() const;

private:
    //==========================================================================
    // Parameters
    //==========================================================================

    ClipType clipType = ClipType::SoftClip;
    ProcessingMode processingMode = ProcessingMode::Stereo;

    float thresholdDb = -6.0f;
    float kneeDb = 3.0f;
    float ceilingDb = -0.3f;

    float inputGainDb = 0.0f;
    float outputGainDb = 0.0f;
    bool autoMakeup = true;
    float mix = 1.0f;

    int oversamplingFactor = 2;
    bool truePeakMode = true;

    // Multiband
    float crossoverLow = 250.0f;
    float crossoverHigh = 3000.0f;
    std::array<float, 3> bandThresholdOffsets {{0.0f, 0.0f, 0.0f}};

    double currentSampleRate = 48000.0;
    int maxBlockSize = 512;

    // ✅ OPTIMIZATION: Pre-allocated buffers to avoid audio thread allocation
    juce::AudioBuffer<float> dryBuffer;
    juce::AudioBuffer<float> oversampledBuffer;

    //==========================================================================
    // Metering
    //==========================================================================

    std::atomic<float> inputLevel {0.0f};
    std::atomic<float> outputLevel {0.0f};
    std::atomic<float> gainReduction {0.0f};
    std::atomic<float> clippingAmount {0.0f};

    //==========================================================================
    // Oversampling
    //==========================================================================

    std::unique_ptr<juce::dsp::Oversampling<float>> oversampling;

    //==========================================================================
    // Multiband State
    //==========================================================================

    struct MultibandState
    {
        std::array<float, 8> filterState {{0.0f}};  // Crossover filter state
    };

    std::array<MultibandState, 2> multibandStates;  // Per channel

    //==========================================================================
    // Internal Methods
    //==========================================================================

    void processStereo(juce::AudioBuffer<float>& buffer);
    void processMidSide(juce::AudioBuffer<float>& buffer);
    void processMultiband(juce::AudioBuffer<float>& buffer);

    float applyClipping(float input, ClipType type, float threshold, float knee);
    float softClip(float input, float threshold, float knee);
    float hardClip(float input, float threshold);
    float tubeClip(float input, float threshold, float knee);
    float diodeClip(float input, float threshold);
    float transformerClip(float input, float threshold, float knee);
    float analogClip(float input, float threshold, float knee);

    void updateMeters(const juce::AudioBuffer<float>& buffer, bool isInput);
    float calculateMakeupGain() const;

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (EdgeControl)
};
