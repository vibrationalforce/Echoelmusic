#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>

/**
 * WaveForge - Advanced Wavetable Synthesizer
 *
 * Modern wavetable synthesis with:
 * - 64+ built-in wavetables (Serum/Vital/Pigments-style)
 * - Wavetable position modulation
 * - Multi-dimensional wavetable morphing
 * - Spectral filters and effects
 * - Unison and stereo width
 * - Advanced modulation matrix
 *
 * Inspired by: Xfer Serum, Vital, Arturia Pigments
 */
class WaveForge : public juce::Synthesiser
{
public:
    WaveForge();
    ~WaveForge() override;

    //==============================================================================
    // Processing

    void prepare(double sampleRate, int samplesPerBlock, int numChannels);
    void processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midiMessages);

    //==============================================================================
    // Wavetable Selection

    enum class WavetableType
    {
        Basic,           // Sine, saw, square, triangle
        Analog,          // Analog waveform emulations
        Digital,         // Digital/FM waveforms
        Vocal,           // Vocal formants
        Modern,          // EDM/modern sounds
        Organic,         // Natural/acoustic textures
        Metallic,        // Bells, metal resonance
        Evolving,        // Animated/evolving textures
        Custom           // User wavetable
    };

    void setWavetable(WavetableType type, int index);  // Select from built-in wavetables
    void loadCustomWavetable(const float* data, int numSamples);  // Load custom wavetable

    //==============================================================================
    // Wavetable Position & Morphing

    void setWavetablePosition(int osc, float position);    // 0.0 to 1.0 (scan through frames)
    void setWavetableMorph(float amount);                  // 0.0 to 1.0 (blend between wavetables)
    void setWavetableBend(int osc, float amount);          // -1.0 to +1.0 (spectral warping)

    //==============================================================================
    // Dual Oscillators (NEW: Added 2nd oscillator)

    void setOscEnabled(int osc, bool enabled);    // osc = 0 or 1
    void setOscWavetable(int osc, WavetableType type, int index);
    void setOscPitch(int osc, float semitones);   // -24 to +24 semitones
    void setOscFine(int osc, float cents);        // -100 to +100 cents
    void setOscPhase(int osc, float phase);       // 0.0 to 1.0
    void setOscLevel(int osc, float level);       // 0.0 to 1.0
    void setOscPan(int osc, float pan);           // 0.0 (L) to 1.0 (R)

    //==============================================================================
    // Wavetable Import (NEW: Load Serum-compatible .wav files)

    bool loadWavetableFromFile(const juce::File& wavFile, int slot);
    bool loadWavetableFromMemory(const float* data, int numFrames, int samplesPerFrame, int slot);
    int getNumLoadedWavetables() const;

    //==============================================================================
    // Filter

    enum class FilterType
    {
        LowPass, HighPass, BandPass, Notch,
        Comb, Formant, Phaser
    };

    void setFilterType(FilterType type);
    void setFilterCutoff(float frequency);        // 20Hz to 20kHz
    void setFilterResonance(float resonance);     // 0.0 to 1.0
    void setFilterDrive(float drive);             // 0.0 to 1.0 (pre-filter saturation)
    void setFilterEnvAmount(float amount);        // -1.0 to +1.0

    //==============================================================================
    // Envelopes

    void setAmpAttack(float timeMs);
    void setAmpDecay(float timeMs);
    void setAmpSustain(float level);
    void setAmpRelease(float timeMs);

    void setModAttack(float timeMs);
    void setModDecay(float timeMs);
    void setModSustain(float level);
    void setModRelease(float timeMs);

    //==============================================================================
    // LFO

    void setLFORate(float hz);                    // 0.01Hz to 20Hz
    void setLFOShape(float shape);                // 0.0 to 1.0 (morphs between waveforms)
    void setLFOToWavetable(float amount);         // 0.0 to 1.0
    void setLFOToFilter(float amount);            // 0.0 to 1.0
    void setLFOToPitch(float amount);             // 0.0 to 1.0

    //==============================================================================
    // Effects

    void setUnisonVoices(int voices);             // 1 to 16
    void setUnisonDetune(float cents);            // 0.0 to 100.0
    void setUnisonSpread(float amount);           // 0.0 to 1.0 (stereo width)
    void setUnisonBlend(float amount);            // 0.0 to 1.0 (stack/blend)

    void setDistortion(float amount);             // 0.0 to 1.0
    void setDistortionType(int type);             // 0-5 (soft, hard, fold, etc.)

    //==============================================================================
    // Master

    void setMasterVolume(float volume);
    void setPolyphony(int voices);

    //==============================================================================
    // MPE (MIDI Polyphonic Expression) Support

    void setMPEEnabled(bool enabled);
    void setMPEPitchBendRange(int semitones);
    void setMPEPressureToWavetable(float amount);  // Pressure → wavetable position
    void setMPESlideToFilter(float amount);        // Slide → filter cutoff

    //==============================================================================
    // Presets

    enum class Preset
    {
        Init,
        EDMPluck,
        Supersaw,
        ReeseBass,
        VocalPad,
        BellLead,
        EvolvingPad,
        AggressiveLead,
        SubBass,
        OrganicTexture
    };

    void loadPreset(Preset preset);

private:
    //==============================================================================
    // Voice Class

    class WaveForgeVoice : public juce::SynthesiserVoice
    {
    public:
        WaveForgeVoice(WaveForge& parent);

        bool canPlaySound(juce::SynthesiserSound*) override;
        void startNote(int midiNoteNumber, float velocity,
                      juce::SynthesiserSound*, int currentPitchWheelPosition) override;
        void stopNote(float velocity, bool allowTailOff) override;
        void pitchWheelMoved(int newPitchWheelValue) override;
        void controllerMoved(int controllerNumber, int newControllerValue) override;
        void renderNextBlock(juce::AudioBuffer<float>& outputBuffer,
                           int startSample, int numSamples) override;

    private:
        WaveForge& synthRef;

        int currentMidiNote = 0;
        float currentVelocity = 0.0f;
        float currentFrequency = 440.0f;

        // Wavetable playback
        float phase = 0.0f;
        int currentFrame = 0;

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
        EnvelopeState modEnv;

        float readWavetable(float position, int frame);
        float processFilter(float sample);
        void updateEnvelope(EnvelopeState& env, float attack, float decay, float sustain, float release);
    };

    //==============================================================================
    // Sound Class

    class WaveForgeSound : public juce::SynthesiserSound
    {
    public:
        bool appliesToNote(int) override { return true; }
        bool appliesToChannel(int) override { return true; }
    };

    //==============================================================================
    // Wavetable Storage

    static constexpr int WAVETABLE_SIZE = 2048;
    static constexpr int WAVETABLE_FRAMES = 256;

    struct Wavetable
    {
        std::vector<std::array<float, WAVETABLE_SIZE>> frames;  // Multiple frames for morphing
        std::string name;
    };

    std::vector<Wavetable> wavetables;
    int currentWavetableIndex = 0;

    void initializeWavetables();
    void generateBasicWavetables();
    void generateAnalogWavetables();
    void generateDigitalWavetables();

    //==============================================================================
    // Synth Parameters

    double currentSampleRate = 48000.0;
    int currentNumChannels = 2;

    // Dual Oscillator Configuration (NEW)
    struct OscillatorConfig
    {
        bool enabled = true;
        int wavetableIndex = 0;
        float wavetablePosition = 0.5f;
        float wavetableBend = 0.0f;
        float pitch = 0.0f;
        float fine = 0.0f;
        float phase = 0.0f;
        float level = 1.0f;
        float pan = 0.5f;
    };
    std::array<OscillatorConfig, 2> oscillators;

    // Wavetable morphing
    float wavetableMorph = 0.0f;

    // MPE
    bool mpeEnabled = false;
    int mpePitchBendRange = 48;
    float mpePressureToWavetable = 0.5f;
    float mpeSlideToFilter = 0.5f;

    // Filter
    FilterType filterType = FilterType::LowPass;
    float filterCutoff = 5000.0f;
    float filterResonance = 0.3f;
    float filterDrive = 0.0f;
    float filterEnvAmount = 0.5f;

    // Amp Envelope
    float ampAttack = 5.0f;
    float ampDecay = 100.0f;
    float ampSustain = 0.7f;
    float ampRelease = 200.0f;

    // Mod Envelope
    float modAttack = 5.0f;
    float modDecay = 300.0f;
    float modSustain = 0.3f;
    float modRelease = 500.0f;

    // LFO
    float lfoRate = 5.0f;
    float lfoShape = 0.0f;
    float lfoToWavetable = 0.0f;
    float lfoToFilter = 0.0f;
    float lfoToPitch = 0.0f;
    float lfoPhase = 0.0f;

    // Effects
    int unisonVoices = 1;
    float unisonDetune = 10.0f;
    float unisonSpread = 0.5f;
    float unisonBlend = 0.5f;
    float distortion = 0.0f;
    int distortionType = 0;

    // Master
    float masterVolume = 0.7f;

    //==============================================================================
    // Internal Helpers

    float getLFOValue();
    float applyDistortion(float sample);

    friend class WaveForgeVoice;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(WaveForge)
};
