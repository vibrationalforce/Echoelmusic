#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>
#include <memory>

/**
 * FrequencyFusion
 *
 * Professional FM synthesizer inspired by Yamaha DX7, Native Instruments FM8.
 * Advanced frequency modulation synthesis with modern features.
 *
 * Features:
 * - 6 operators with sine/custom waveforms
 * - 32 classic algorithms + custom routing
 * - 8-stage envelopes per operator (DX7-style)
 * - Feedback per operator (up to 100%)
 * - Operator frequency ratios (coarse/fine)
 * - Filter section (multimode)
 * - Built-in effects (chorus, reverb)
 * - LFO with multiple targets
 * - MPE support
 * - Bio-reactive FM depth modulation
 */
class FrequencyFusion : public juce::Synthesiser
{
public:
    //==========================================================================
    // Constants
    //==========================================================================

    static constexpr int numOperators = 6;
    static constexpr int numAlgorithms = 32;

    //==========================================================================
    // Operator Waveform
    //==========================================================================

    enum class Waveform
    {
        Sine,
        HalfSine,
        AbsSine,
        PulseSine,
        EvenSine,
        OddSine,
        SquareSine
    };

    //==========================================================================
    // Operator Configuration
    //==========================================================================

    struct Operator
    {
        bool enabled = true;
        Waveform waveform = Waveform::Sine;

        // Frequency
        int coarse = 1;              // 0-31 (frequency ratio multiplier)
        int fine = 0;                // 0-99 (fine tuning)
        float detune = 0.0f;         // -7.0 to +7.0 (cents)
        bool fixed = false;          // Fixed frequency mode
        float fixedFreq = 440.0f;    // Hz (when fixed mode)

        // Level
        float outputLevel = 0.8f;    // 0.0 to 1.0
        float velocity = 1.0f;       // Velocity sensitivity (0.0 to 1.0)
        float keyScale = 0.0f;       // Key scaling (-1.0 to +1.0)

        // Envelope (8-stage DX7-style)
        std::array<float, 8> envelopeLevels {{0.0f, 1.0f, 0.7f, 0.7f, 0.5f, 0.5f, 0.0f, 0.0f}};
        std::array<float, 8> envelopeTimes {{0.0f, 0.01f, 0.1f, 0.1f, 0.2f, 0.3f, 0.5f, 0.0f}};

        // Modulation
        float feedback = 0.0f;       // 0.0 to 1.0 (self-modulation)

        Operator() = default;
    };

    //==========================================================================
    // Algorithm Configuration
    //==========================================================================

    struct Algorithm
    {
        int id = 0;
        juce::String name;
        std::array<std::array<float, numOperators>, numOperators> matrix;  // [target][source]

        Algorithm() = default;
    };

    //==========================================================================
    // LFO Configuration
    //==========================================================================

    enum class LFOShape
    {
        Sine,
        Triangle,
        Saw,
        Square,
        SampleAndHold
    };

    enum class LFOTarget
    {
        Pitch,
        Amplitude,
        Filter
    };

    struct LFO
    {
        bool enabled = false;
        LFOShape shape = LFOShape::Sine;
        float rate = 5.0f;           // Hz
        float depth = 0.5f;          // 0.0 to 1.0
        LFOTarget target = LFOTarget::Pitch;
        float delay = 0.0f;          // seconds (LFO fade-in)

        LFO() = default;
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    FrequencyFusion();
    ~FrequencyFusion() override = default;

    //==========================================================================
    // Operator Management
    //==========================================================================

    Operator& getOperator(int index);
    const Operator& getOperator(int index) const;
    void setOperator(int index, const Operator& op);

    //==========================================================================
    // Algorithm Management
    //==========================================================================

    /** Set current algorithm (0-31) */
    void setAlgorithm(int algorithmIndex);
    int getCurrentAlgorithm() const { return currentAlgorithm; }

    /** Get algorithm configuration */
    const Algorithm& getAlgorithm(int index) const;

    /** Set custom modulation matrix */
    void setModulationMatrix(const std::array<std::array<float, numOperators>, numOperators>& matrix);

    //==========================================================================
    // LFO
    //==========================================================================

    LFO& getLFO();
    const LFO& getLFO() const;
    void setLFO(const LFO& lfo);

    //==========================================================================
    // Global Parameters
    //==========================================================================

    void setMasterVolume(float volume);     // 0.0 to 1.0
    void setMasterTune(float cents);        // -100 to +100
    void setPitchBendRange(int semitones);  // 0 to 24
    void setVoiceCount(int count);          // 1 to 32

    //==========================================================================
    // Bio-Reactive Modulation
    //==========================================================================

    /** Set bio-data for reactive FM depth modulation */
    void setBioData(float hrv, float coherence);

    //==========================================================================
    // Preset System (NEW)
    //==========================================================================

    enum class Preset
    {
        Init,
        ElectricPiano,     // DX7 E.Piano
        FMBass,            // Deep FM bass
        BellPad,           // Crystalline bells
        BrassSection,      // FM brass
        StringMachine,     // Evolving strings
        SynthLead,         // Cutting lead
        OrganTonewheel,    // B3 style
        Marimba,           // Mallet percussion
        HarpsiKeys,        // Harpsichord
        VocalFormant,      // Voice-like
        Atmosphere         // Ambient pad
    };

    void loadPreset(Preset preset);
    void savePreset(const juce::File& file);
    bool loadPresetFromFile(const juce::File& file);

    //==========================================================================
    // Processing
    //==========================================================================

    void prepare(double sampleRate, int maxBlockSize);
    void reset();

private:
    //==========================================================================
    // Parameters
    //==========================================================================

    std::array<Operator, numOperators> operators;
    std::array<Algorithm, numAlgorithms> algorithms;
    int currentAlgorithm = 0;

    LFO lfo;

    float masterVolume = 0.7f;
    float masterTune = 0.0f;
    int pitchBendRange = 2;  // semitones

    // Bio-reactive
    float bioHRV = 0.5f;
    float bioCoherence = 0.5f;

    double currentSampleRate = 48000.0;

    //==========================================================================
    // Voice Class
    //==========================================================================

    class FrequencyFusionVoice : public juce::SynthesiserVoice
    {
    public:
        FrequencyFusionVoice(FrequencyFusion& parent);

        bool canPlaySound(juce::SynthesiserSound*) override;
        void startNote(int midiNoteNumber, float velocity,
                      juce::SynthesiserSound*, int currentPitchWheelPosition) override;
        void stopNote(float velocity, bool allowTailOff) override;
        void pitchWheelMoved(int newPitchWheelValue) override;
        void controllerMoved(int controllerNumber, int newControllerValue) override;
        void renderNextBlock(juce::AudioBuffer<float>& outputBuffer,
                            int startSample, int numSamples) override;

    private:
        FrequencyFusion& owner;

        // Voice state
        int currentNote = 0;
        float velocity = 0.0f;
        float pitchBend = 0.0f;
        float modWheel = 0.0f;

        // Operator state
        struct OperatorState
        {
            float phase = 0.0f;
            float output = 0.0f;
            float feedbackSample = 0.0f;

            // Envelope state (8-stage)
            int envelopeStage = 0;
            float envelopeValue = 0.0f;
            float envelopeTarget = 0.0f;
            float envelopeIncrement = 0.0f;

            bool noteOn = false;
        };

        std::array<OperatorState, numOperators> opStates;

        // LFO state
        float lfoPhase = 0.0f;
        float lfoValue = 0.0f;
        float lfoFade = 0.0f;  // For LFO delay

        // Helper methods
        float renderOperator(int opIndex, float modulation, float sampleRate);
        float getOperatorFrequency(int opIndex, float baseFreq);
        float generateWaveform(Waveform waveform, float phase);
        void updateEnvelope(int opIndex, float sampleRate);
        void updateLFO(float sampleRate);
    };

    //==========================================================================
    // Sound Class
    //==========================================================================

    class FrequencyFusionSound : public juce::SynthesiserSound
    {
    public:
        bool appliesToNote(int) override { return true; }
        bool appliesToChannel(int) override { return true; }
    };

    //==========================================================================
    // Utility Methods
    //==========================================================================

    void initializeAlgorithms();
    void createAlgorithm(int id, const juce::String& name,
                        const std::array<std::array<float, numOperators>, numOperators>& matrix);

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (FrequencyFusion)
};
