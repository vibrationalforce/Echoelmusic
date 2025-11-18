#pragma once

#include <JuceHeader.h>
#include <vector>

/**
 * Quantum Reverb - Biometric-Responsive Algorithmic Reverb
 *
 * Features:
 * - Adaptive space based on heart rate (faster = smaller room)
 * - Coherence modulates early reflections
 * - HRV controls diffusion and decay
 * - Multiple algorithms: Hall, Chamber, Plate, Spring, Shimmer
 * - High-quality Feedback Delay Network (FDN) topology
 */
class QuantumReverb
{
public:
    QuantumReverb();
    ~QuantumReverb() = default;

    enum class Algorithm {
        Hall,           // Large concert hall
        Chamber,        // Medium room
        Plate,          // Classic plate reverb
        Spring,         // Vintage spring
        Shimmer,        // Octave up shimmer (Brian Eno style)
        Quantum         // Biometric-modulated space
    };

    //==============================================================================
    // Processing
    void prepare(double sampleRate, int samplesPerBlock, int numChannels);
    void process(juce::AudioBuffer<float>& buffer);
    void reset();

    //==============================================================================
    // Parameters
    void setAlgorithm(Algorithm algo);
    void setSize(float size);           // 0.0 - 1.0 (room size)
    void setDecay(float time);          // 0.1 - 20.0 seconds
    void setDamping(float amount);      // 0.0 - 1.0 (high frequency absorption)
    void setDiffusion(float amount);    // 0.0 - 1.0 (density of reflections)
    void setPreDelay(float timeMs);     // 0 - 500ms
    void setMix(float mix);             // 0.0 - 1.0 (dry/wet)
    void setModulation(float depth, float rate);  // Chorus-like modulation

    //==============================================================================
    // Biometric Modulation
    void setHeartRate(float bpm);
    void setHeartRateVariability(float hrv);  // 0.0 - 1.0
    void setCoherence(float coherence);       // 0.0 - 1.0
    void enableBiometricModulation(bool enable);

private:
    //==============================================================================
    // FDN (Feedback Delay Network) - 8 delay lines
    static constexpr int NUM_DELAYS = 8;
    std::vector<float> delayLines[NUM_DELAYS];
    int delayLengths[NUM_DELAYS];
    int delayReadPos[NUM_DELAYS];
    int delayWritePos[NUM_DELAYS];

    //==============================================================================
    // Parameters
    Algorithm currentAlgorithm = Algorithm::Hall;
    float size = 0.7f;
    float decayTime = 2.0f;
    float damping = 0.5f;
    float diffusion = 0.7f;
    float preDelayTime = 0.0f;
    float mix = 0.3f;
    float modDepth = 0.0f;
    float modRate = 0.5f;

    //==============================================================================
    // Biometric
    bool biometricEnabled = false;
    float heartRate = 70.0f;
    float heartRateVariability = 0.5f;
    float coherence = 0.5f;

    //==============================================================================
    // State
    double sampleRate = 44100.0;
    float modPhase = 0.0f;

    // Pre-delay
    std::vector<float> preDelayBuffer;
    int preDelayWritePos = 0;

    // Damping filters
    juce::dsp::IIR::Filter<float> dampingFilters[NUM_DELAYS];

    // Feedback matrix (Householder)
    float feedbackMatrix[NUM_DELAYS][NUM_DELAYS];

    //==============================================================================
    // Internal
    void updateDelayLengths();
    void buildFeedbackMatrix();
    void processFDN(float input, float& left, float& right);
};
