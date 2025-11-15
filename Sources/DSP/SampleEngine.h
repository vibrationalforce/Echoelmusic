#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>
#include <memory>

/**
 * SampleEngine - Advanced Sampler with Time-Stretching
 *
 * Professional sampler with:
 * - Multi-sample support with velocity/key zones
 * - Time-stretching (tempo-independent playback)
 * - Pitch-shifting (formant-preserving)
 * - Loop points (forward, backward, ping-pong)
 * - Sample start/end modulation
 * - Filter and amp envelopes
 * - LFO modulation
 *
 * Inspired by: Kontakt, HALion, EXS24
 */
class SampleEngine : public juce::Synthesiser
{
public:
    SampleEngine();
    ~SampleEngine() override;

    //==============================================================================
    // Processing

    void prepare(double sampleRate, int samplesPerBlock, int numChannels);
    void processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midiMessages);

    //==============================================================================
    // Sample Management

    struct Sample
    {
        juce::AudioBuffer<float> audioData;
        double sourceSampleRate = 44100.0;
        std::string name;

        // Key/velocity mapping
        int rootNote = 60;             // C4
        int keyRangeLow = 0;
        int keyRangeHigh = 127;
        int velocityRangeLow = 0;
        int velocityRangeHigh = 127;

        // Loop points
        int loopStart = 0;
        int loopEnd = 0;
        bool loopEnabled = false;
    };

    void loadSample(const juce::File& audioFile, int rootNote = 60);
    void loadSample(const juce::AudioBuffer<float>& buffer, double sourceSampleRate, int rootNote = 60);
    void clearSamples();
    int getNumSamples() const;

    //==============================================================================
    // Playback Controls

    void setSampleStart(float position);      // 0.0 to 1.0 (offset into sample)
    void setSampleEnd(float position);        // 0.0 to 1.0
    void setLoopEnabled(bool enabled);
    void setLoopStart(float position);        // 0.0 to 1.0
    void setLoopEnd(float position);          // 0.0 to 1.0

    enum class LoopMode
    {
        Off,
        Forward,
        Backward,
        PingPong
    };

    void setLoopMode(LoopMode mode);

    //==============================================================================
    // Time-Stretching & Pitch

    void setPitchShift(float semitones);      // -24 to +24 semitones
    void setTimeStretch(float ratio);         // 0.5 to 2.0 (tempo change without pitch change)
    void setFormantPreserve(bool preserve);   // Preserve formants when pitch-shifting

    //==============================================================================
    // Filter

    enum class FilterType
    {
        LowPass, HighPass, BandPass, Notch
    };

    void setFilterType(FilterType type);
    void setFilterCutoff(float frequency);
    void setFilterResonance(float resonance);
    void setFilterEnvAmount(float amount);

    //==============================================================================
    // Envelopes

    void setAmpAttack(float timeMs);
    void setAmpDecay(float timeMs);
    void setAmpSustain(float level);
    void setAmpRelease(float timeMs);

    void setFilterAttack(float timeMs);
    void setFilterDecay(float timeMs);
    void setFilterSustain(float level);
    void setFilterRelease(float timeMs);

    //==============================================================================
    // LFO

    void setLFORate(float hz);
    void setLFOToPitch(float amount);
    void setLFOToFilter(float amount);
    void setLFOToSampleStart(float amount);

    //==============================================================================
    // Master

    void setMasterVolume(float volume);
    void setPolyphony(int voices);

    //==============================================================================
    // Presets

    enum class Preset
    {
        Init,
        Piano,
        Strings,
        Choir,
        Drums,
        LoFiTexture,
        GranularPad
    };

    void loadPreset(Preset preset);

private:
    //==============================================================================
    // Voice Class

    class SampleEngineVoice : public juce::SynthesiserVoice
    {
    public:
        SampleEngineVoice(SampleEngine& parent);

        bool canPlaySound(juce::SynthesiserSound*) override;
        void startNote(int midiNoteNumber, float velocity,
                      juce::SynthesiserSound*, int currentPitchWheelPosition) override;
        void stopNote(float velocity, bool allowTailOff) override;
        void pitchWheelMoved(int newPitchWheelValue) override;
        void controllerMoved(int controllerNumber, int newControllerValue) override;
        void renderNextBlock(juce::AudioBuffer<float>& outputBuffer,
                           int startSample, int numSamples) override;

    private:
        SampleEngine& synthRef;

        int currentMidiNote = 0;
        float currentVelocity = 0.0f;
        int currentSampleIndex = -1;

        // Playback state
        double playbackPosition = 0.0;
        double playbackSpeed = 1.0;
        bool loopingForward = true;

        // Filter state
        std::array<float, 4> filterState = {0.0f, 0.0f, 0.0f, 0.0f};

        // Envelope state
        struct EnvelopeState
        {
            enum class Stage { Idle, Attack, Decay, Sustain, Release };
            Stage stage = Stage::Idle;
            float level = 0.0f;
        };
        EnvelopeState ampEnv;
        EnvelopeState filterEnv;

        float readSample(const Sample& sample, double position);
        float processFilter(float sample);
        void updateEnvelope(EnvelopeState& env, float attack, float decay, float sustain, float release);
    };

    //==============================================================================
    // Sound Class

    class SampleEngineSound : public juce::SynthesiserSound
    {
    public:
        bool appliesToNote(int) override { return true; }
        bool appliesToChannel(int) override { return true; }
    };

    //==============================================================================
    // Sample Storage

    std::vector<Sample> samples;

    // Find best sample for note/velocity
    int findSampleForNote(int midiNote, int velocity) const;

    //==============================================================================
    // Synth Parameters

    double currentSampleRate = 48000.0;
    int currentNumChannels = 2;

    // Playback
    float sampleStart = 0.0f;
    float sampleEnd = 1.0f;
    bool loopEnabled = false;
    float loopStart = 0.0f;
    float loopEnd = 1.0f;
    LoopMode loopMode = LoopMode::Forward;

    // Pitch/Time
    float pitchShift = 0.0f;
    float timeStretch = 1.0f;
    bool formantPreserve = false;

    // Filter
    FilterType filterType = FilterType::LowPass;
    float filterCutoff = 5000.0f;
    float filterResonance = 0.3f;
    float filterEnvAmount = 0.5f;

    // Amp Envelope
    float ampAttack = 5.0f;
    float ampDecay = 100.0f;
    float ampSustain = 0.7f;
    float ampRelease = 200.0f;

    // Filter Envelope
    float filterAttack = 5.0f;
    float filterDecay = 300.0f;
    float filterSustain = 0.3f;
    float filterRelease = 500.0f;

    // LFO
    float lfoRate = 5.0f;
    float lfoToPitch = 0.0f;
    float lfoToFilter = 0.0f;
    float lfoToSampleStart = 0.0f;
    float lfoPhase = 0.0f;

    // Master
    float masterVolume = 0.7f;

    //==============================================================================
    // Internal Helpers

    float getLFOValue();

    friend class SampleEngineVoice;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SampleEngine)
};
