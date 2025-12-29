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
        Comb,
        // NEW: Advanced filter types inspired by Vectra/Circle2
        MoogLadder,          // Classic Moog 4-pole ladder
        StateVariable,       // Multimode state-variable filter
        Formant,             // Vowel formant filter
        Phaser,              // Phaser/allpass filter
        DiodeLadder,         // MS-20 style diode ladder
        OberheimSEM,         // Oberheim SEM 12dB multimode
        AcidTB303            // Roland TB-303 style resonance
    };

    //==========================================================================
    // Vector Synthesis Mode (NEW - Vectra-style)
    //==========================================================================

    struct VectorPad
    {
        float x = 0.5f;              // X position (0.0 to 1.0)
        float y = 0.5f;              // Y position (0.0 to 1.0)
        bool enabled = false;

        // 4 wavetable sources at corners
        std::array<int, 4> wavetableSlots {{0, 1, 2, 3}};  // A, B, C, D
        std::array<float, 4> wavetablePositions {{0.0f, 0.0f, 0.0f, 0.0f}};

        // LFO modulation of X/Y
        float lfoToX = 0.0f;
        float lfoToY = 0.0f;
        int lfoIndexX = 0;
        int lfoIndexY = 1;

        VectorPad() = default;
    };

    //==========================================================================
    // Macro Controls (NEW - 8 macros like Circle2)
    //==========================================================================

    static constexpr int numMacros = 8;

    struct MacroTarget
    {
        ModDestination destination = ModDestination::None;
        float amount = 0.0f;         // -1.0 to +1.0

        MacroTarget() = default;
    };

    struct Macro
    {
        float value = 0.0f;          // Current macro value (0.0 to 1.0)
        juce::String name;
        std::array<MacroTarget, 8> targets;  // Up to 8 targets per macro
        int numTargets = 0;

        Macro() : name("Macro") {}
    };

    //==========================================================================
    // Arpeggiator (NEW)
    //==========================================================================

    enum class ArpMode
    {
        Off,
        Up,
        Down,
        UpDown,
        DownUp,
        Random,
        Order,               // As played
        Chord                // Play all notes together
    };

    enum class ArpOctaveMode
    {
        Single,              // Stay in played octave
        OctaveUp,            // +1 octave
        OctaveDown,          // -1 octave
        OctaveUpDown,        // Ping-pong octaves
        TwoOctavesUp,        // +2 octaves
        ThreeOctavesUp       // +3 octaves
    };

    struct Arpeggiator
    {
        ArpMode mode = ArpMode::Off;
        ArpOctaveMode octaveMode = ArpOctaveMode::Single;
        float rate = 120.0f;         // BPM
        float gate = 0.5f;           // Note length (0.1 to 1.0)
        int swing = 0;               // Swing amount (-50 to +50)
        bool sync = true;            // Sync to host tempo
        float division = 0.25f;      // Note division (1/16 = 0.25, 1/8 = 0.5, etc.)

        Arpeggiator() = default;
    };

    //==========================================================================
    // Effects Chain (NEW - built-in effects)
    //==========================================================================

    struct ChorusEffect
    {
        bool enabled = false;
        float rate = 0.5f;           // LFO rate (0.1 to 5.0 Hz)
        float depth = 0.5f;          // Modulation depth (0.0 to 1.0)
        float mix = 0.5f;            // Wet/dry mix (0.0 to 1.0)
        int voices = 2;              // 2 or 4 voice chorus
        float feedback = 0.0f;       // Feedback amount
        float stereoSpread = 0.5f;   // Stereo width

        ChorusEffect() = default;
    };

    struct DelayEffect
    {
        bool enabled = false;
        float timeL = 0.25f;         // Left delay time (seconds)
        float timeR = 0.375f;        // Right delay time (seconds)
        bool sync = true;            // Sync to tempo
        float syncDivL = 0.25f;      // Sync division left (1/16, 1/8, etc.)
        float syncDivR = 0.375f;     // Sync division right
        float feedback = 0.4f;       // Feedback amount (0.0 to 0.95)
        float crossfeed = 0.2f;      // Ping-pong crossfeed
        float mix = 0.3f;            // Wet/dry mix
        float filter = 0.5f;         // Highcut filter (0=dark, 1=bright)

        DelayEffect() = default;
    };

    struct ReverbEffect
    {
        bool enabled = false;
        float size = 0.7f;           // Room size (0.0 to 1.0)
        float decay = 0.5f;          // Decay time (0.0 to 1.0)
        float damping = 0.5f;        // High frequency damping
        float predelay = 0.02f;      // Pre-delay in seconds
        float mix = 0.3f;            // Wet/dry mix
        float modulation = 0.2f;     // Modulation amount
        float width = 1.0f;          // Stereo width

        ReverbEffect() = default;
    };

    struct DistortionEffect
    {
        bool enabled = false;

        enum class Type { Soft, Hard, Fold, Asymmetric, Tube, Digital, Bitcrush };
        Type type = Type::Soft;

        float drive = 0.3f;          // Drive amount (0.0 to 1.0)
        float mix = 1.0f;            // Wet/dry mix
        float tone = 0.5f;           // Post-distortion tone
        float bias = 0.0f;           // DC bias for asymmetric distortion

        DistortionEffect() = default;
    };

    struct EffectsChain
    {
        DistortionEffect distortion;
        ChorusEffect chorus;
        DelayEffect delay;
        ReverbEffect reverb;

        // Effects order (can be reordered)
        std::array<int, 4> order {{0, 1, 2, 3}};  // 0=dist, 1=chorus, 2=delay, 3=reverb

        EffectsChain() = default;
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
        Wavetable,         // Use custom wavetable
        // NEW: Additional shapes like Circle2
        SawUp,
        SawDown,
        ExpRise,           // Exponential rise
        ExpFall,           // Exponential fall
        Pulse25,           // 25% duty cycle
        Pulse75,           // 75% duty cycle
        Staircase4,        // 4-step staircase
        Staircase8,        // 8-step staircase
        Smooth,            // Smoothed random
        Chaos              // Lorenz attractor
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
        Aftertouch,
        // NEW: Additional modulation sources
        KeyTrack,            // Note number (C0 = 0, C5 = 1)
        Random,              // Random value per note
        Constant,            // Fixed value (use amount as value)
        Macro1, Macro2, Macro3, Macro4, Macro5, Macro6, Macro7, Macro8,
        VectorX, VectorY,    // Vector pad position
        AmpEnvelope,         // Dedicated amp envelope
        FilterEnvelope,      // Dedicated filter envelope
        PolyAftertouch,      // Per-note aftertouch (MPE)
        Slide,               // MPE slide (CC74)
        Expression,          // Expression pedal (CC11)
        BreathController,    // Breath controller (CC2)
        NoteGate,            // Gate signal (0 or 1)
        Legato               // Legato detection
    };

    enum class ModDestination
    {
        None,
        // Oscillator 1
        Osc1_Pitch,
        Osc1_WavetablePosition,
        Osc1_Level,
        Osc1_Pan,
        Osc1_UnisonDetune,
        Osc1_UnisonSpread,
        Osc1_Phase,
        // Oscillator 2
        Osc2_Pitch,
        Osc2_WavetablePosition,
        Osc2_Level,
        Osc2_Pan,
        Osc2_UnisonDetune,
        Osc2_UnisonSpread,
        Osc2_Phase,
        // Filter 1
        Filter1_Cutoff,
        Filter1_Resonance,
        Filter1_Drive,
        Filter1_KeyTrack,
        // Filter 2
        Filter2_Cutoff,
        Filter2_Resonance,
        Filter2_Drive,
        Filter2_KeyTrack,
        // LFOs
        LFO1_Rate, LFO1_Depth, LFO1_Phase,
        LFO2_Rate, LFO2_Depth, LFO2_Phase,
        LFO3_Rate, LFO3_Depth,
        LFO4_Rate, LFO4_Depth,
        // Envelopes
        Env1_Attack, Env1_Decay, Env1_Sustain, Env1_Release,
        Env2_Attack, Env2_Decay, Env2_Sustain, Env2_Release,
        // Vector
        VectorX, VectorY,
        // Sub/Noise
        SubLevel, NoiseLevel, NoiseColor,
        // Effects
        ChorusDepth, ChorusMix,
        DelayTime, DelayFeedback, DelayMix,
        ReverbSize, ReverbDecay, ReverbMix,
        DistortionDrive, DistortionMix,
        // Master
        MasterVolume, MasterPan
    };

    static constexpr int numModDestinations = 54;  // Total destinations

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
    // Vector Synthesis (NEW)
    //==========================================================================

    /** Get/set vector pad configuration */
    VectorPad& getVectorPad() { return vectorPad; }
    const VectorPad& getVectorPad() const { return vectorPad; }
    void setVectorPad(const VectorPad& pad);

    /** Quick vector position control */
    void setVectorPosition(float x, float y);
    void setVectorWavetable(int corner, int wavetableIndex, float position);

    //==========================================================================
    // Macro Controls (NEW)
    //==========================================================================

    /** Get/set macro configuration */
    Macro& getMacro(int index);
    const Macro& getMacro(int index) const;
    void setMacro(int index, const Macro& macro);

    /** Quick macro value set (MIDI CC compatible) */
    void setMacroValue(int index, float value);
    float getMacroValue(int index) const;

    /** Add modulation target to macro */
    void addMacroTarget(int macroIndex, ModDestination dest, float amount);
    void clearMacroTargets(int macroIndex);

    //==========================================================================
    // Arpeggiator (NEW)
    //==========================================================================

    Arpeggiator& getArpeggiator() { return arpeggiator; }
    const Arpeggiator& getArpeggiator() const { return arpeggiator; }
    void setArpeggiator(const Arpeggiator& arp);

    void setArpMode(ArpMode mode);
    void setArpRate(float bpm);
    void setArpGate(float gate);
    void setArpOctaveMode(ArpOctaveMode mode);

    //==========================================================================
    // Effects Chain (NEW)
    //==========================================================================

    EffectsChain& getEffectsChain() { return effectsChain; }
    const EffectsChain& getEffectsChain() const { return effectsChain; }
    void setEffectsChain(const EffectsChain& chain);

    /** Chorus control */
    void setChorusEnabled(bool enabled);
    void setChorusRate(float hz);
    void setChorusDepth(float depth);
    void setChorusMix(float mix);

    /** Delay control */
    void setDelayEnabled(bool enabled);
    void setDelayTime(float timeL, float timeR);
    void setDelayFeedback(float feedback);
    void setDelayMix(float mix);
    void setDelaySync(bool sync);

    /** Reverb control */
    void setReverbEnabled(bool enabled);
    void setReverbSize(float size);
    void setReverbDecay(float decay);
    void setReverbMix(float mix);

    /** Distortion control */
    void setDistortionEnabled(bool enabled);
    void setDistortionType(DistortionEffect::Type type);
    void setDistortionDrive(float drive);
    void setDistortionMix(float mix);

    /** Effects order */
    void setEffectsOrder(const std::array<int, 4>& order);

    //==========================================================================
    // Preset System (NEW)
    //==========================================================================

    enum class Preset
    {
        Init,
        Supersaw,          // Classic EDM supersaw
        VocalChoir,        // Human choir-like
        EvolvingPad,       // Slow morphing texture
        BassReese,         // Reese bass
        PluckLead,         // Plucked lead
        Ambient,           // Atmospheric soundscape
        Aggressive,        // Hard-hitting lead
        Ethereal,          // Dreamy pad
        Wobble,            // Dubstep wobble
        Arp,               // Arpeggiated sequence
        Keys               // Electric piano-like
    };

    void loadPreset(Preset preset);
    void savePreset(const juce::File& file);
    bool loadPresetFromFile(const juce::File& file);

    //==========================================================================
    // Bio-Reactive Modulation (NEW)
    //==========================================================================

    void setBioReactiveEnabled(bool enabled);
    void setBioData(float hrv, float coherence, float breathPhase);
    void setBioToWavetable(float amount);     // Bio → wavetable position
    void setBioToFilter(float amount);        // Bio → filter cutoff
    void setBioToLFORate(float amount);       // Bio → LFO speed

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

    // Bio-Reactive (NEW)
    bool bioReactiveEnabled = false;
    float bioHRV = 0.5f;
    float bioCoherence = 0.5f;
    float bioBreathPhase = 0.0f;
    float bioToWavetable = 0.3f;
    float bioToFilter = 0.3f;
    float bioToLFORate = 0.2f;

    // Vector Synthesis (NEW)
    VectorPad vectorPad;

    // Macro Controls (NEW)
    std::array<Macro, numMacros> macros;

    // Arpeggiator (NEW)
    Arpeggiator arpeggiator;
    std::vector<int> arpNotes;           // Currently held notes for arp
    int arpCurrentStep = 0;
    int arpCurrentOctave = 0;
    double arpAccumulator = 0.0;         // Sample accumulator for timing
    bool arpDirection = true;            // true = up, false = down

    // Effects Chain (NEW)
    EffectsChain effectsChain;

    // Effects state (for processing)
    struct ChorusState
    {
        std::array<std::vector<float>, 4> delayLines;  // 4 voices
        std::array<int, 4> writePos {{0, 0, 0, 0}};
        std::array<float, 4> lfoPhases {{0.0f, 0.25f, 0.5f, 0.75f}};

        ChorusState() = default;
    } chorusState;

    struct DelayState
    {
        std::array<std::vector<float>, 2> delayLines;  // L/R
        std::array<int, 2> writePos {{0, 0}};
        std::array<float, 2> filterState {{0.0f, 0.0f}};  // Lowpass for feedback

        DelayState() = default;
    } delayState;

    struct ReverbState
    {
        // Simple Schroeder reverb with 4 comb + 2 allpass
        std::array<std::vector<float>, 4> combL, combR;
        std::array<int, 4> combPosL {{0,0,0,0}}, combPosR {{0,0,0,0}};
        std::array<float, 4> combFilterL {{0,0,0,0}}, combFilterR {{0,0,0,0}};
        std::array<std::vector<float>, 2> allpassL, allpassR;
        std::array<int, 2> allpassPosL {{0,0}}, allpassPosR {{0,0}};
        std::vector<float> predelayL, predelayR;
        int predelayPos = 0;
        float modPhase = 0.0f;

        ReverbState() = default;
    } reverbState;

    // Modulation values cache (computed per-block for efficiency)
    struct ModulationCache
    {
        std::array<float, numModDestinations> values;  // Current modulation per destination
        std::array<float, 8> lfoValues;                // Current LFO values
        std::array<float, 4> envValues;                // Current envelope values
        std::array<float, numMacros> macroValues;      // Current macro values

        ModulationCache() {
            values.fill(0.0f);
            lfoValues.fill(0.0f);
            envValues.fill(0.0f);
            macroValues.fill(0.0f);
        }
    } modCache;

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

        // OPTIMIZATION: Cached reciprocals for division-free per-sample processing
        float invSampleRate = 1.0f / 48000.0f;  // Updated in prepare()

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
        std::array<float, 8> lfoPhases {{0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f}};

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
    // Modulation Processing (NEW - replaces stub)
    //==========================================================================

    /** Compute all modulation values for current block */
    void computeModulation();

    /** Get modulation value for specific destination */
    float getModulationValue(ModDestination dest) const;

    /** Get modulation source value */
    float getModSourceValue(ModSource source, float velocity, int noteNumber,
                            float pitchBend, float modWheel, float aftertouch) const;

    /** Apply all macro targets */
    void applyMacroModulation();

    //==========================================================================
    // Vector Synthesis (NEW)
    //==========================================================================

    /** Compute vector mixing weights for 4 corners */
    std::array<float, 4> computeVectorWeights(float x, float y) const;

    /** Read interpolated sample from vector sources */
    float readVectorSample(float phase, const std::array<float, 4>& weights) const;

    //==========================================================================
    // Effects Processing (NEW)
    //==========================================================================

    /** Initialize effects buffers */
    void initializeEffects();

    /** Process stereo through effects chain */
    void processEffects(float& left, float& right);

    /** Individual effect processors */
    void processChorus(float& left, float& right);
    void processDelay(float& left, float& right);
    void processReverb(float& left, float& right);
    void processDistortion(float& sample);

    //==========================================================================
    // Arpeggiator (NEW)
    //==========================================================================

    /** Process arpeggiator, returns note to play or -1 */
    int processArpeggiator(double sampleRate);

    /** Sort arp notes based on mode */
    void sortArpNotes();

    /** Get next arp note index */
    int getNextArpNote();

    //==========================================================================
    // Advanced Filter Processing (NEW)
    //==========================================================================

    /** Moog ladder filter (4-pole) */
    float processMoogLadder(float input, float cutoff, float resonance,
                            std::array<float, 4>& state) const;

    /** State-variable filter */
    float processStateVariable(float input, float cutoff, float resonance,
                               FilterType subType, std::array<float, 2>& state) const;

    /** Formant filter (vowel sounds) */
    float processFormant(float input, float morph, std::array<float, 10>& state) const;

    /** TB-303 style acid filter */
    float processAcidFilter(float input, float cutoff, float resonance,
                            float accent, std::array<float, 4>& state) const;

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (WaveWeaver)
};
