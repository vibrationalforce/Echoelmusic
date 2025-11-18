#pragma once

#include <JuceHeader.h>

/**
 * Biometric Filter - Heart-Responsive Multi-Mode Filter
 *
 * Unique Features:
 * - Heart rate controls cutoff frequency modulation speed
 * - HRV modulates resonance (higher variability = more resonance)
 * - Breathing rate controls filter envelope
 * - Coherence adds harmonic filtering
 * - Auto-wah mode synced to heart rhythm
 *
 * Creates organic, breathing filter sweeps that follow your physiology.
 */
class BiometricFilter
{
public:
    BiometricFilter();
    ~BiometricFilter() = default;

    enum class FilterMode {
        LowPass,
        HighPass,
        BandPass,
        Notch,
        Formant,      // Vowel-like resonances
        AutoWah,      // Auto-wah synced to heart rate
        Comb          // Comb filter for metallic tones
    };

    //==============================================================================
    // Processing
    void prepare(double sampleRate, int samplesPerBlock, int numChannels);
    void process(juce::AudioBuffer<float>& buffer);
    void reset();

    //==============================================================================
    // Filter Parameters
    void setFilterMode(FilterMode mode);
    void setBaseCutoff(float frequency);     // 20 - 20000 Hz
    void setBaseResonance(float resonance);  // 0.0 - 1.0
    void setDrive(float amount);             // Pre-filter drive (0.0 - 10.0)

    //==============================================================================
    // Modulation
    void setModulationDepth(float depth);    // How much biometrics affect filter
    void setModulationRate(float rate);      // LFO speed multiplier
    void setEnvelopeFollower(bool enabled);  // Track input dynamics

    //==============================================================================
    // Biometric Inputs
    void setHeartRate(float bpm);
    void setHeartRateVariability(float hrv);     // 0.0 - 1.0
    void setBreathingRate(float breathsPerMin);  // 6 - 30
    void setCoherence(float coherence);          // 0.0 - 1.0
    void setStressLevel(float stress);           // 0.0 - 1.0

    //==============================================================================
    // Formant Mode
    enum class Vowel { A, E, I, O, U };
    void setVowel(Vowel vowel);

private:
    //==============================================================================
    // State Variable Filter (Chamberlin topology)
    struct SVFilter {
        float lowpass = 0.0f;
        float bandpass = 0.0f;
        float highpass = 0.0f;
        float notch = 0.0f;
        float freq = 0.0f;
        float q = 0.0f;
    };

    SVFilter filterL, filterR;

    //==============================================================================
    // Formant Filter
    struct FormantFilter {
        float frequency;
        float bandwidth;
        float gain;
    };

    std::array<FormantFilter, 5> formants;  // 5 formants per vowel

    //==============================================================================
    // Parameters
    FilterMode mode = FilterMode::LowPass;
    float baseCutoff = 1000.0f;
    float baseResonance = 0.5f;
    float drive = 1.0f;

    float modulationDepth = 0.5f;
    float modulationRate = 1.0f;
    bool envelopeFollowerEnabled = false;

    //==============================================================================
    // Biometric Data
    float heartRate = 70.0f;
    float heartRateVariability = 0.5f;
    float breathingRate = 12.0f;
    float coherence = 0.5f;
    float stressLevel = 0.3f;

    //==============================================================================
    // State
    double sampleRate = 44100.0;
    float heartPhase = 0.0f;
    float breathPhase = 0.0f;
    float envelopeLevel = 0.0f;

    Vowel currentVowel = Vowel::A;

    //==============================================================================
    // Internal Processing
    float processSVF(SVFilter& svf, float input, float cutoff, float resonance);
    float processFormant(float input);
    void updateCutoffFromBiometrics(float& currentCutoff);
    void updateResonanceFromBiometrics(float& currentResonance);
    void setFormantForVowel(Vowel vowel);
};
