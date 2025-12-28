#pragma once

#include <JuceHeader.h>
#include <vector>
#include <array>

/**
 * Advanced Modulation Suite
 *
 * Professional modulation effects inspired by Eventide H3000, TC Electronic,
 * Strymon, and modern software like Valhalla and FabFilter.
 *
 * Effects Included:
 * - Chorus (vintage and modern algorithms)
 * - Flanger (tape, jet, through-zero)
 * - Phaser (2-12 pole, vintage/modern)
 * - Tremolo (amplitude and harmonic)
 * - Vibrato (pitch modulation)
 * - Ring Modulator
 * - Frequency Shifter (Bode-style)
 *
 * Features:
 * - Multiple LFO shapes (sine, triangle, saw, square, random)
 * - Tempo sync
 * - Stereo width control
 * - Feedback control
 * - Dry/wet mix
 * - Low-latency processing
 */
class ModulationSuite
{
public:
    //==========================================================================
    // Effect Types
    //==========================================================================

    enum class EffectType
    {
        Chorus,
        Flanger,
        Phaser,
        Tremolo,
        Vibrato,
        RingModulator,
        FrequencyShifter
    };

    //==========================================================================
    // LFO Shapes
    //==========================================================================

    enum class LFOShape
    {
        Sine,
        Triangle,
        Saw,
        ReverseSaw,
        Square,
        RandomSmooth,
        RandomStep
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    ModulationSuite();
    ~ModulationSuite() = default;

    //==========================================================================
    // Effect Selection
    //==========================================================================

    /** Set active effect type */
    void setEffectType(EffectType type);

    /** Get current effect type */
    EffectType getEffectType() const { return currentEffect; }

    //==========================================================================
    // Parameters
    //==========================================================================

    /** Set LFO rate in Hz (0.01 to 20 Hz) */
    void setRate(float rateHz);

    /** Set LFO depth (0.0 to 1.0) */
    void setDepth(float depth);

    /** Set feedback amount (-1.0 to 1.0) */
    void setFeedback(float fb);

    /** Set stereo width (0.0 = mono, 1.0 = full stereo) */
    void setStereoWidth(float width);

    /** Set dry/wet mix (0.0 to 1.0) */
    void setMix(float mixAmount);

    /** Set LFO shape */
    void setLFOShape(LFOShape shape);

    /** Set tempo sync (true = sync to BPM, false = free-running Hz) */
    void setTempoSync(bool enabled);

    /** Set tempo in BPM (for tempo sync) */
    void setTempo(double bpm);

    //==========================================================================
    // Effect-Specific Parameters
    //==========================================================================

    /** Chorus: number of voices (1-8) */
    void setChorusVoices(int voices);

    /** Flanger: manual position (0.0 to 1.0) */
    void setFlangerManual(float position);

    /** Phaser: number of stages (2, 4, 6, 8, 10, 12) */
    void setPhaserStages(int stages);

    /** Ring Modulator: carrier frequency (20 to 5000 Hz) */
    void setRingModCarrier(float freq);

    /** Frequency Shifter: shift amount in Hz (-2000 to +2000) */
    void setFrequencyShift(float shiftHz);

    //==========================================================================
    // Processing
    //==========================================================================

    /** Prepare for processing */
    void prepare(double sampleRate, int maxBlockSize);

    /** Reset effect state */
    void reset();

    /** Process audio buffer */
    void process(juce::AudioBuffer<float>& buffer);

    //==========================================================================
    // Visualization
    //==========================================================================

    /** Get current LFO value (0.0 to 1.0) for visualization */
    float getLFOValue() const { return currentLFOValue; }

private:
    //==========================================================================
    // Parameters
    //==========================================================================

    EffectType currentEffect = EffectType::Chorus;
    LFOShape lfoShape = LFOShape::Sine;

    float rate = 1.0f;              // Hz
    float depth = 0.5f;             // 0-1
    float feedback = 0.0f;          // -1 to 1
    float stereoWidth = 1.0f;       // 0-1
    float mix = 0.5f;               // 0-1

    bool tempoSync = false;
    double tempo = 120.0;

    // Effect-specific
    int chorusVoices = 3;
    float flangerManual = 0.5f;
    int phaserStages = 4;
    float ringModCarrier = 440.0f;
    float frequencyShift = 0.0f;

    double currentSampleRate = 48000.0;

    //==========================================================================
    // LFO State
    //==========================================================================

    float lfoPhase = 0.0f;
    float lfoIncrement = 0.0f;
    float currentLFOValue = 0.0f;
    float randomTarget = 0.0f;      // For random LFO
    float randomCurrent = 0.0f;
    juce::Random rng;               // Fast RNG for random LFO shapes

    //==========================================================================
    // Delay Lines (for Chorus/Flanger/Vibrato)
    //==========================================================================

    static constexpr int maxDelayInSamples = 192000;  // 4 seconds at 48kHz
    std::array<std::vector<float>, 2> delayBuffers;
    std::array<int, 2> writePositions;

    //==========================================================================
    // Allpass Filters (for Phaser)
    //==========================================================================

    struct AllpassState
    {
        float x1 = 0.0f, y1 = 0.0f;
    };

    static constexpr int maxPhaserStages = 12;
    std::array<std::array<AllpassState, maxPhaserStages>, 2> allpassStates;  // [channel][stage]

    //==========================================================================
    // Ring Modulator State
    //==========================================================================

    float ringModPhase = 0.0f;

    //==========================================================================
    // Frequency Shifter State (Hilbert Transform)
    //==========================================================================

    struct HilbertState
    {
        std::array<float, 4> x;
        std::array<float, 4> y;
        HilbertState() { x.fill(0.0f); y.fill(0.0f); }
    };

    std::array<HilbertState, 2> hilbertStates;
    float shifterPhase = 0.0f;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    void updateLFO();
    float getLFOSample();

    void processChorus(juce::AudioBuffer<float>& buffer);
    void processFlanger(juce::AudioBuffer<float>& buffer);
    void processPhaser(juce::AudioBuffer<float>& buffer);
    void processTremolo(juce::AudioBuffer<float>& buffer);
    void processVibrato(juce::AudioBuffer<float>& buffer);
    void processRingMod(juce::AudioBuffer<float>& buffer);
    void processFrequencyShifter(juce::AudioBuffer<float>& buffer);

    float readDelayInterpolated(int channel, float delayInSamples);
    void writeDelay(int channel, float sample);

    float applyAllpass(float input, AllpassState& state, float coefficient);

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (ModulationSuite)
};
