#pragma once

#include <JuceHeader.h>
#include <atomic>

/**
 * Compressor - Professional dynamics processor
 *
 * Features:
 * - Threshold, ratio, attack, release
 * - Knee control (hard/soft)
 * - Auto-gain (makeup)
 * - Side-chain support (later)
 * - Multiple modes (transparent, vintage, aggressive)
 */
class Compressor
{
public:
    enum class Mode
    {
        Transparent,    // Clean, surgical
        Vintage,        // Warm, musical
        Aggressive      // Punchy, limiting
    };

    Compressor();
    ~Compressor();

    void prepare(double sampleRate, int maximumBlockSize);
    void reset();

    void process(juce::AudioBuffer<float>& buffer);

    // Parameters
    void setThreshold(float dB);       // -60 to 0 dB
    void setRatio(float ratio);        // 1:1 to 20:1
    void setAttack(float ms);          // 0.1 to 100 ms
    void setRelease(float ms);         // 10 to 1000 ms
    void setKnee(float dB);            // 0 (hard) to 12 dB (soft)
    void setMakeupGain(float dB);      // 0 to 24 dB
    void setMode(Mode mode);

    // Metering
    float getGainReduction() const;

private:
    double currentSampleRate = 48000.0;
    Mode currentMode = Mode::Transparent;

    // Parameters
    float threshold = -20.0f;
    float ratio = 4.0f;
    float attack = 5.0f;
    float release = 100.0f;
    float knee = 3.0f;
    float makeupGain = 0.0f;

    // State
    float envelopeL = 0.0f;
    float envelopeR = 0.0f;

    // OPTIMIZATION: Atomic for thread-safe UI metering access
    std::atomic<float> gainReduction { 0.0f };

    // Coefficients (calculated from attack/release)
    float attackCoeff = 0.0f;
    float releaseCoeff = 0.0f;

    void updateCoefficients();
    float computeGain(float input);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(Compressor)
};
