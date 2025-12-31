#pragma once

#include <JuceHeader.h>
#include <array>

/**
 * Vintage Effects Suite
 *
 * Classic oldschool effects for authentic vintage character:
 * - Envelope Filter (Auto-Wah) - Mutron III, Mu-Tron style
 * - Tape Saturation - Ampex, Studer character
 * - VHS/Lo-Fi - Degradation, noise, wow/flutter
 * - Tube Distortion - Valve/röhren warmth and harmonics
 * - BitCrusher - Digital lo-fi, vintage samplers
 * - Vinyl Simulator - Crackle, dust, wow/flutter
 *
 * Inspired by: Ableton Live, FL Studio, vintage hardware
 */
class VintageEffects
{
public:
    //==========================================================================
    // Effect Types
    //==========================================================================

    enum class EffectType
    {
        EnvelopeFilter,    // Auto-wah, envelope-controlled filter
        TapeSaturation,    // Analog tape warmth and compression
        VHSLoFi,           // VHS degradation, bandwidth limiting
        TubeDistortion,    // Valve/röhren harmonics and warmth
        BitCrusher,        // Sample rate/bit depth reduction
        VinylSimulator     // Turntable character (crackle, dust, wow)
    };

    //==========================================================================
    // Envelope Filter Modes
    //==========================================================================

    enum class EnvelopeMode
    {
        LowPass,     // Classic auto-wah (up-sweep)
        BandPass,    // Vocal/talking effect
        HighPass     // Reverse sweep
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    VintageEffects();
    ~VintageEffects() = default;

    //==========================================================================
    // Effect Selection
    //==========================================================================

    /** Set active effect type */
    void setEffectType(EffectType type);

    /** Get current effect type */
    EffectType getEffectType() const { return currentEffect; }

    //==========================================================================
    // Common Parameters
    //==========================================================================

    /** Set dry/wet mix (0.0 to 1.0) */
    void setMix(float mixAmount);

    /** Set drive/intensity (0.0 to 1.0) */
    void setDrive(float driveAmount);

    //==========================================================================
    // Envelope Filter Parameters
    //==========================================================================

    /** Set envelope filter mode */
    void setEnvelopeMode(EnvelopeMode mode);

    /** Set envelope sensitivity (0.0 to 1.0) */
    void setSensitivity(float sens);

    /** Set resonance/Q (0.1 to 10.0) */
    void setResonance(float q);

    /** Set envelope attack time (1 to 100 ms) */
    void setAttack(float attackMs);

    /** Set envelope release time (10 to 1000 ms) */
    void setRelease(float releaseMs);

    //==========================================================================
    // Tape Saturation Parameters
    //==========================================================================

    /** Set tape saturation type (0 = soft, 1 = hard) */
    void setTapeType(float type);

    /** Set tape hiss amount (0.0 to 1.0) */
    void setHiss(float amount);

    //==========================================================================
    // VHS/Lo-Fi Parameters
    //==========================================================================

    /** Set bandwidth (20 to 20000 Hz) */
    void setBandwidth(float hz);

    /** Set noise amount (0.0 to 1.0) */
    void setNoise(float amount);

    /** Set dropout probability (0.0 to 1.0) */
    void setDropout(float prob);

    //==========================================================================
    // Tube Distortion Parameters
    //==========================================================================

    /** Set tube bias (0.0 to 1.0) - affects harmonic content */
    void setBias(float biasAmount);

    /** Set output level (0.0 to 2.0) */
    void setOutputLevel(float level);

    //==========================================================================
    // BitCrusher Parameters
    //==========================================================================

    /** Set sample rate reduction (100 to 48000 Hz) */
    void setSampleRateReduction(float sampleRate);

    /** Set bit depth (1 to 16 bits) */
    void setBitDepth(int bits);

    //==========================================================================
    // Vinyl Parameters
    //==========================================================================

    /** Set crackle amount (0.0 to 1.0) */
    void setCrackle(float amount);

    /** Set dust/scratches amount (0.0 to 1.0) */
    void setDust(float amount);

    /** Set RPM wobble (0.0 to 1.0) */
    void setWobble(float amount);

    //==========================================================================
    // Processing
    //==========================================================================

    /** Prepare for processing */
    void prepare(double sampleRate, int maxBlockSize);

    /** Reset effect state */
    void reset();

    /** Process audio buffer */
    void process(juce::AudioBuffer<float>& buffer);

private:
    //==========================================================================
    // Parameters
    //==========================================================================

    EffectType currentEffect = EffectType::EnvelopeFilter;
    EnvelopeMode envelopeMode = EnvelopeMode::LowPass;

    float mix = 0.5f;
    float drive = 0.5f;

    // Envelope filter
    float sensitivity = 0.7f;
    float resonance = 2.0f;
    float attack = 10.0f;
    float release = 100.0f;

    // Tape
    float tapeType = 0.5f;
    float hiss = 0.3f;

    // VHS
    float bandwidth = 5000.0f;
    float noise = 0.3f;
    float dropout = 0.1f;

    // Tube
    float bias = 0.5f;
    float outputLevel = 1.0f;

    // BitCrusher
    float sampleRateReduction = 8000.0f;
    int bitDepth = 8;
    float cachedBitMax = 255.0f;  // Cached pow(2, bitDepth) - 1

    // Vinyl
    float crackle = 0.3f;
    float dust = 0.2f;
    float wobble = 0.2f;

    double currentSampleRate = 48000.0;

    //==========================================================================
    // Envelope Follower State
    //==========================================================================

    struct EnvelopeState
    {
        float envelope = 0.0f;
        float attackCoeff = 0.0f;
        float releaseCoeff = 0.0f;
    };

    std::array<EnvelopeState, 2> envelopeStates;

    //==========================================================================
    // Filter State (for envelope filter)
    //==========================================================================

    struct FilterState
    {
        float x1 = 0.0f, x2 = 0.0f;
        float y1 = 0.0f, y2 = 0.0f;
    };

    std::array<FilterState, 2> filterStates;

    //==========================================================================
    // BitCrusher State
    //==========================================================================

    struct BitCrusherState
    {
        float phase = 0.0f;
        float lastSample = 0.0f;
    };

    std::array<BitCrusherState, 2> bitCrusherStates;

    //==========================================================================
    // Vinyl State
    //==========================================================================

    float vinylPhase = 0.0f;
    int crackleTimer = 0;
    juce::Random rng;  // Fast RNG for noise generation

    //==========================================================================
    // Effect Processing
    //==========================================================================

    void processEnvelopeFilter(juce::AudioBuffer<float>& buffer);
    void processTapeSaturation(juce::AudioBuffer<float>& buffer);
    void processVHSLoFi(juce::AudioBuffer<float>& buffer);
    void processTubeDistortion(juce::AudioBuffer<float>& buffer);
    void processBitCrusher(juce::AudioBuffer<float>& buffer);
    void processVinylSimulator(juce::AudioBuffer<float>& buffer);

    //==========================================================================
    // Utility Functions
    //==========================================================================

    float applyBiquadFilter(float input, FilterState& state, float cutoff, float q, EnvelopeMode mode);
    float tapeSaturate(float input, float driveAmount, float type);
    float tubeDistort(float input, float driveAmount, float biasAmount);
    float quantize(float sample, int bits);
    float generateNoise();
    float generateCrackle();

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (VintageEffects)
};
