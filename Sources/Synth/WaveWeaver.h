#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>
#include <memory>

/**
 * WaveWeaver
 *
 * Professional wavetable synthesizer inspired by Serum, Vital, Pigments.
 * Advanced wavetable synthesis with extensive modulation capabilities.
 *
 * Features:
 * - Dual wavetable oscillators (256 waveforms each)
 * - Real-time wavetable morphing/interpolation
 * - Sub oscillator + noise generator
 * - Unison (up to 16 voices per oscillator)
 * - 2 multimode filters (LP/HP/BP/Notch/Comb, 12/24dB)
 * - 4 ADSR envelopes
 * - 8 LFOs (wavetable-based, syncable)
 * - 16-slot modulation matrix
 * - Built-in effects (distortion, chorus, delay, reverb)
 * - MPE support (polyphonic expression)
 * - Zero-latency processing
 */
class WaveWeaver : public juce::Synthesiser
{
public:
    //==========================================================================
    // Wavetable
    //==========================================================================

    static constexpr int wavetableSize = 2048;      // Samples per waveform
    static constexpr int wavetableFrames = 256;     // Waveforms per wavetable

    struct Wavetable
    {
        std::vector<float> data;  // wavetableSize * wavetableFrames
        juce::String name;

        Wavetable() : data(wavetableSize * wavetableFrames, 0.0f) {}
    };

    //==========================================================================
    // Filter Type
    //==========================================================================

    enum class FilterType
    {
        LowPass12dB,
        LowPass24dB,
        HighPass12dB,
        HighPass24dB,
        BandPass,
        Notch,
        Comb
    };

    //==========================================================================
    // LFO Shape
    //==========================================================================

    enum class LFOShape
    {
        Sine,
        Triangle,
        Saw,
        Square,
        Random,
        SampleAndHold,
        Wavetable  // Use custom wavetable
    };

    //==========================================================================
    // Oscillator Configuration
    //==========================================================================

    struct Oscillator
    {
        bool enabled = true;
        int wavetableIndex = 0;         // Which wavetable to use
        float wavetablePosition = 0.0f;  // 0.0 to 1.0 (morph through frames)
        float level = 0.7f;              // 0.0 to 1.0
        float pan = 0.5f;                // 0.0 (L) to 1.0 (R)
        int semitones = 0;               // -24 to +24
        int cents = 0;                   // -100 to +100
        float phase = 0.0f;              // 0.0 to 1.0 (oscillator start phase)

        // Unison
        int unisonVoices = 1;            // 1 to 16
        float unisonDetune = 0.1f;       // 0.0 to 1.0
        float unisonSpread = 0.5f;       // Stereo spread (0.0 to 1.0)

        Oscillator() = default;
    };

    //==========================================================================
    // Filter Configuration
    //==========================================================================

    struct Filter
    {
        bool enabled = true;
        FilterType type = FilterType::LowPass24dB;
        float cutoff = 1000.0f;          // Hz
        float resonance = 0.0f;          // 0.0 to 1.0
        float drive = 0.0f;              // 0.0 to 1.0 (pre-filter distortion)
        float keyTracking = 0.0f;        // 0.0 to 1.0
        float envelopeAmount = 0.0f;     // -1.0 to +1.0

        Filter() = default;
    };

    //==========================================================================
    // Envelope Configuration
    //==========================================================================

    struct Envelope
    {
        float attack = 0.01f;            // seconds
        float decay = 0.1f;              // seconds
        float sustain = 0.7f;            // 0.0 to 1.0
        float release = 0.3f;            // seconds

        Envelope() = default;
    };

    //==========================================================================
    // LFO Configuration
    //==========================================================================

    struct LFO
    {
        bool enabled = false;
        LFOShape shape = LFOShape::Sine;
        float rate = 2.0f;               // Hz (or sync ratio)
        bool sync = false;               // Sync to host tempo
        float syncRatio = 1.0f;          // 1/16, 1/8, 1/4, 1/2, 1, 2, 4
        float depth = 0.5f;              // 0.0 to 1.0
        float phase = 0.0f;              // 0.0 to 1.0 (start phase)
        int wavetableIndex = 0;          // For wavetable LFO shape

        LFO() = default;
    };

    //==========================================================================
    // Modulation Matrix
    //==========================================================================

    enum class ModSource
    {
        None,
        LFO1, LFO2, LFO3, LFO4, LFO5, LFO6, LFO7, LFO8,
        Envelope1, Envelope2, Envelope3, Envelope4,
        Velocity,
        ModWheel,
        PitchBend,
        Aftertouch
    };

    enum class ModDestination
    {
        None,
        Osc1_Pitch,
        Osc1_WavetablePosition,
        Osc1_Level,
        Osc2_Pitch,
        Osc2_WavetablePosition,
        Osc2_Level,
        Filter1_Cutoff,
        Filter1_Resonance,
        Filter2_Cutoff,
        Filter2_Resonance,
        LFO1_Rate,
        LFO2_Rate
    };

    struct ModulationRoute
    {
        ModSource source = ModSource::None;
        ModDestination destination = ModDestination::None;
        float amount = 0.0f;             // -1.0 to +1.0

        ModulationRoute() = default;
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    WaveWeaver();
    ~WaveWeaver() override = default;

    //==========================================================================
    // Wavetable Management
    //==========================================================================

    /** Load wavetable from audio file */
    bool loadWavetable(const juce::File& file, int slot);

    /** Generate wavetable from function */
    void generateWavetable(int slot, std::function<float(float)> waveformFunc);

    /** Get number of loaded wavetables */
    int getNumWavetables() const { return static_cast<int>(wavetables.size()); }

    //==========================================================================
    // Oscillator Parameters
    //==========================================================================

    Oscillator& getOscillator(int index);  // 0 or 1
    const Oscillator& getOscillator(int index) const;
    void setOscillator(int index, const Oscillator& osc);

    //==========================================================================
    // Sub Oscillator / Noise
    //==========================================================================

    void setSubOscillatorEnabled(bool enabled);
    void setSubOscillatorLevel(float level);
    void setSubOscillatorOctave(int octave);  // -1, -2

    void setNoiseEnabled(bool enabled);
    void setNoiseLevel(float level);
    void setNoiseColor(float color);  // 0.0 (white) to 1.0 (pink/red)

    //==========================================================================
    // Filter Parameters
    //==========================================================================

    Filter& getFilter(int index);  // 0 or 1
    const Filter& getFilter(int index) const;
    void setFilter(int index, const Filter& filter);

    //==========================================================================
    // Envelope Parameters
    //==========================================================================

    Envelope& getEnvelope(int index);  // 0-3
    const Envelope& getEnvelope(int index) const;
    void setEnvelope(int index, const Envelope& envelope);

    //==========================================================================
    // LFO Parameters
    //==========================================================================

    LFO& getLFO(int index);  // 0-7
    const LFO& getLFO(int index) const;
    void setLFO(int index, const LFO& lfo);

    //==========================================================================
    // Modulation Matrix
    //==========================================================================

    ModulationRoute& getModulationRoute(int index);  // 0-15
    const ModulationRoute& getModulationRoute(int index) const;
    void setModulationRoute(int index, const ModulationRoute& route);

    //==========================================================================
    // Global Parameters
    //==========================================================================

    void setMasterVolume(float volume);     // 0.0 to 1.0
    void setMasterTune(float cents);        // -100 to +100 cents
    void setPortamentoTime(float seconds);  // 0.0 to 5.0
    void setVoiceCount(int count);          // 1 to 32 (polyphony)

    //==========================================================================
    // Processing
    //==========================================================================

    /** Prepare for playback */
    void prepare(double sampleRate, int maxBlockSize);

    /** Reset all voices and states */
    void reset();

private:
    //==========================================================================
    // Wavetables
    //==========================================================================

    std::vector<std::unique_ptr<Wavetable>> wavetables;

    //==========================================================================
    // Parameters
    //==========================================================================

    std::array<Oscillator, 2> oscillators;
    std::array<Filter, 2> filters;
    std::array<Envelope, 4> envelopes;
    std::array<LFO, 8> lfos;
    std::array<ModulationRoute, 16> modulationMatrix;

    // Sub / Noise
    bool subEnabled = false;
    float subLevel = 0.5f;
    int subOctave = -1;

    bool noiseEnabled = false;
    float noiseLevel = 0.3f;
    float noiseColor = 0.5f;

    // Global
    float masterVolume = 0.7f;
    float masterTune = 0.0f;
    float portamentoTime = 0.0f;

    double currentSampleRate = 48000.0;

    //==========================================================================
    // Voice Class
    //==========================================================================

    class WaveWeaverVoice : public juce::SynthesiserVoice
    {
    public:
        WaveWeaverVoice(WaveWeaver& parent);

        bool canPlaySound(juce::SynthesiserSound*) override;
        void startNote(int midiNoteNumber, float velocity,
                      juce::SynthesiserSound*, int currentPitchWheelPosition) override;
        void stopNote(float velocity, bool allowTailOff) override;
        void pitchWheelMoved(int newPitchWheelValue) override;
        void controllerMoved(int controllerNumber, int newControllerValue) override;
        void renderNextBlock(juce::AudioBuffer<float>& outputBuffer,
                            int startSample, int numSamples) override;

    private:
        WaveWeaver& owner;

        // Voice state
        int currentNote = 0;
        float velocity = 0.0f;
        float pitchBend = 0.0f;
        float modWheel = 0.0f;

        // Oscillator state
        struct OscillatorState
        {
            std::vector<float> phases;  // For unison voices
            float baseFrequency = 440.0f;
        };

        std::array<OscillatorState, 2> oscStates;

        // Sub oscillator
        float subPhase = 0.0f;

        // Filter state
        struct FilterState
        {
            float z1 = 0.0f, z2 = 0.0f;  // Biquad state
        };

        std::array<std::array<FilterState, 2>, 2> filterStates;  // [filter][channel]

        // Envelope state
        struct EnvelopeState
        {
            enum class Stage { Off, Attack, Decay, Sustain, Release };
            Stage stage = Stage::Off;
            float value = 0.0f;
        };

        std::array<EnvelopeState, 4> envelopeStates;

        // LFO state
        std::array<float, 8> lfoPhases;

        // Helper methods
        float readWavetable(int oscIndex, float phase, float position);
        float processFilter(int filterIndex, int channel, float input, float cutoffMod);
        float processEnvelope(int envIndex, float sampleRate);
        float processLFO(int lfoIndex, float sampleRate);
        void applyModulation(float& value, ModDestination dest);
    };

    //==========================================================================
    // Sound Class
    //==========================================================================

    class WaveWeaverSound : public juce::SynthesiserSound
    {
    public:
        bool appliesToNote(int) override { return true; }
        bool appliesToChannel(int) override { return true; }
    };

    //==========================================================================
    // Utility Methods
    //==========================================================================

    void initializeDefaultWavetables();
    float interpolateWavetable(const Wavetable& wt, float phase, float position);

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (WaveWeaver)
};
