#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>

/**
 * ResonanceHealer - Adaptive Resonance Suppressor
 *
 * Professional dynamic resonance remover inspired by Oeksound soothe, Gullfoss:
 * - Real-time FFT spectral analysis (2048/4096/8192 bins)
 * - Adaptive resonance detection
 * - Dynamic frequency-specific reduction
 * - Sibilance control (4-10kHz)
 * - Harshness removal (2-6kHz)
 * - Mudiness cleanup (200-600Hz)
 * - Soft/Hard knee compression per band
 * - Delta monitoring (hear what's being removed)
 *
 * Used by: Mixing engineers, mastering, vocal processing, harsh synths
 */
class ResonanceHealer
{
public:
    ResonanceHealer();
    ~ResonanceHealer();

    //==============================================================================
    // DSP Lifecycle
    void prepare(double sampleRate, int maximumBlockSize);
    void reset();
    void process(juce::AudioBuffer<float>& buffer);

    //==============================================================================
    // Parameters

    /** Set depth (0-1): amount of resonance reduction */
    void setDepth(float depth);

    /** Set attack (1-100 ms): how fast reduction kicks in */
    void setAttack(float ms);

    /** Set release (10-1000 ms): how fast reduction releases */
    void setRelease(float ms);

    /** Set frequency range (20-20000 Hz) */
    void setFrequencyRange(float lowHz, float highHz);

    /** Set sensitivity (0-1): threshold for resonance detection */
    void setSensitivity(float sensitivity);

    /** Set sharpness (0-1): bandwidth of reduction (0=wide, 1=narrow) */
    void setSharpness(float sharpness);

    /** Enable delta mode (hear what's being removed) */
    void setDeltaMode(bool enabled);

    /** Enable sibilance mode (focus on 4-10kHz) */
    void setSibilanceMode(bool enabled);

    /** Set mix (0-1): dry/wet blend */
    void setMix(float mix);

private:
    //==============================================================================
    // FFT Analysis

    static constexpr int FFT_ORDER = 12;        // 4096 samples
    static constexpr int FFT_SIZE = 1 << FFT_ORDER;
    static constexpr int HOP_SIZE = FFT_SIZE / 4;

    juce::dsp::FFT fft;
    juce::dsp::WindowingFunction<float> window;

    // FFT buffers
    std::array<float, FFT_SIZE * 2> fftData;
    std::array<float, FFT_SIZE / 2> magnitudeSpectrum;
    std::array<float, FFT_SIZE / 2> phaseSpectrum;

    // Input/output FIFOs
    juce::AudioBuffer<float> inputFifo;
    juce::AudioBuffer<float> outputFifo;
    int inputFifoWritePos = 0;
    int outputFifoReadPos = 0;

    //==============================================================================
    // Resonance Detection

    struct ResonanceBand
    {
        float frequency;        // Center frequency
        float magnitude;        // Current magnitude
        float threshold;        // Detection threshold
        float reduction;        // Current reduction amount (0-1)
        float envelope;         // Envelope follower
    };

    static constexpr int NUM_BANDS = 128;
    std::array<ResonanceBand, NUM_BANDS> resonanceBands;

    //==============================================================================
    // Dynamic Processing

    struct BandCompressor
    {
        float attack = 0.01f;   // Attack time
        float release = 0.1f;   // Release time
        float threshold = 0.5f; // Threshold
        float ratio = 4.0f;     // Compression ratio
        float envelope = 0.0f;  // Current envelope

        float process(float input, float sampleRate)
        {
            float level = std::abs(input);

            // Envelope follower
            if (level > envelope)
                envelope += (1.0f - attack) * (level - envelope);
            else
                envelope += (1.0f - release) * (level - envelope);

            // Compression
            if (envelope > threshold)
            {
                float excess = envelope - threshold;
                float gain = 1.0f - (excess * (1.0f - 1.0f / ratio));
                return input * gain;
            }

            return input;
        }
    };

    std::array<BandCompressor, NUM_BANDS> bandCompressors;

    //==============================================================================
    // Resonance Detection Algorithm

    /** Detect resonances in spectrum */
    void detectResonances();

    /** Calculate spectral centroid for adaptive processing */
    float calculateSpectralCentroid();

    /** Get bin index for frequency */
    int getFrequencyBin(float frequency);

    /** Get frequency for bin index */
    float getBinFrequency(int bin);

    /** Apply adaptive reduction to spectrum */
    void applyReduction();

    //==============================================================================
    // Parameters
    float currentDepth = 0.7f;
    float currentAttack = 10.0f;        // ms
    float currentRelease = 100.0f;      // ms
    float lowFreq = 200.0f;             // Hz
    float highFreq = 10000.0f;          // Hz
    float currentSensitivity = 0.5f;
    float currentSharpness = 0.5f;
    bool deltaMode = false;
    bool sibilanceMode = false;
    float currentMix = 1.0f;

    double sampleRate = 44100.0;
    int blockSize = 512;

    //==============================================================================
    // Pre-allocated Work Buffers (avoid per-frame allocations)
    juce::AudioBuffer<float> dryBuffer;

    // Pre-computed smoothed spectrum buffer
    std::array<float, FFT_SIZE / 2> smoothedSpectrum;

    // Cached attack/release coefficients (updated when params change)
    float cachedAttackCoeff = 0.1f;
    float cachedReleaseCoeff = 0.01f;

    // Update coefficients when attack/release changes
    void updateCoefficients();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (ResonanceHealer)
};
