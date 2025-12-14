#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>
#include <memory>
#include <atomic>
#include <cmath>

#if defined(__ARM_NEON__)
#include <arm_neon.h>
#define ULTRA_SAMPLER_NEON 1
#elif defined(__SSE2__)
#include <emmintrin.h>
#define ULTRA_SAMPLER_SSE2 1
#endif

/**
 * UltraSampler - Kontakt/Omnisphere-Class Sample Engine
 *
 * Professional multi-sampler with industry-standard features:
 *
 * == SAMPLE ARCHITECTURE ==
 * - Multi-sample instruments with key/velocity zones
 * - Up to 128 sample zones per instrument
 * - 16 velocity layers per zone with crossfade
 * - Round-robin cycling (up to 16 variations)
 * - Release triggers for natural decay simulation
 *
 * == INTERPOLATION ==
 * - Sinc interpolation (8-point, 64-point options)
 * - Hermite cubic interpolation (fast mode)
 * - Linear interpolation (ultra-low CPU)
 * - Automatic quality scaling based on pitch ratio
 *
 * == TIME-STRETCHING ==
 * - Phase-vocoder granular engine
 * - Formant-preserving pitch shift
 * - Real-time tempo sync (0.25x to 4.0x)
 * - Transient preservation algorithm
 *
 * == MODULATION ==
 * - 8-slot modulation matrix
 * - 4 multi-stage envelopes (DAHDSR)
 * - 4 LFOs with tempo sync
 * - Step sequencer modulator
 * - Macro controls (8 assignable)
 *
 * == FILTERS ==
 * - Zero-delay feedback (ZDF) topology
 * - 12 filter types (LP/HP/BP/Notch/Comb/Formant)
 * - Dual filters with serial/parallel routing
 * - Filter FM from oscillator
 *
 * == EFFECTS ==
 * - Per-voice saturation/drive
 * - Global insert effects chain
 * - Convolution reverb (IR loading)
 *
 * == BIO-REACTIVE ==
 * - HRV → modulation depth mapping
 * - Coherence → filter resonance
 * - Heart rate → tempo sync
 *
 * Inspired by: Native Instruments Kontakt, Spectrasonics Omnisphere,
 *              UVI Falcon, Steinberg HALion, Apple Alchemy
 */
class UltraSampler
{
public:
    //==========================================================================
    // Constants
    //==========================================================================

    static constexpr int kMaxZones = 128;
    static constexpr int kMaxVelocityLayers = 16;
    static constexpr int kMaxRoundRobin = 16;
    static constexpr int kMaxVoices = 64;
    static constexpr int kMaxModSlots = 8;
    static constexpr int kSincTaps = 64;
    static constexpr int kGrainPoolSize = 128;

    //==========================================================================
    // Interpolation Quality
    //==========================================================================

    enum class InterpolationMode
    {
        Linear,         // Fastest, lowest quality
        Hermite,        // Fast, good quality
        Sinc8,          // 8-point sinc, high quality
        Sinc64,         // 64-point sinc, best quality (CPU intensive)
        Auto            // Automatic based on pitch ratio
    };

    //==========================================================================
    // Filter Types
    //==========================================================================

    enum class FilterType
    {
        Off,
        LowPass12,      // 12dB/oct
        LowPass24,      // 24dB/oct (Moog-style ladder)
        LowPass36,      // 36dB/oct
        HighPass12,
        HighPass24,
        BandPass,
        BandReject,     // Notch
        Comb,
        Formant,        // Vowel filter
        Phaser,
        StateVariable   // Morphable LP-BP-HP
    };

    //==========================================================================
    // Modulation Sources
    //==========================================================================

    enum class ModSource
    {
        None,
        Envelope1, Envelope2, Envelope3, Envelope4,
        LFO1, LFO2, LFO3, LFO4,
        Velocity,
        KeyTrack,
        ModWheel,
        PitchBend,
        Aftertouch,
        PolyAftertouch,
        StepSeq,
        Random,
        Macro1, Macro2, Macro3, Macro4,
        Macro5, Macro6, Macro7, Macro8,
        BioHRV,
        BioCoherence,
        BioHeartRate
    };

    //==========================================================================
    // Modulation Destinations
    //==========================================================================

    enum class ModDest
    {
        None,
        Volume,
        Pan,
        Pitch,
        PitchFine,
        SampleStart,
        LoopStart,
        LoopLength,
        Filter1Cutoff,
        Filter1Resonance,
        Filter2Cutoff,
        Filter2Resonance,
        FilterMix,
        Env1Attack, Env1Decay, Env1Sustain, Env1Release,
        LFO1Rate, LFO1Depth,
        LFO2Rate, LFO2Depth,
        GrainSize,
        GrainDensity,
        GrainPosition,
        GrainSpread,
        Drive
    };

    //==========================================================================
    // Sample Zone
    //==========================================================================

    struct SampleData
    {
        std::vector<float> left;
        std::vector<float> right;
        double sourceSampleRate = 48000.0;
        int rootNote = 60;
        int loopStart = 0;
        int loopEnd = 0;
        int loopCrossfade = 0;
        bool loopEnabled = false;
        juce::String name;
        juce::String filePath;
    };

    struct VelocityLayer
    {
        std::shared_ptr<SampleData> sample;
        int velocityLow = 0;
        int velocityHigh = 127;
        float gain = 1.0f;
        int roundRobinGroup = 0;
    };

    struct Zone
    {
        bool enabled = false;
        juce::String name;

        // Key mapping
        int keyLow = 0;
        int keyHigh = 127;
        int rootKey = 60;

        // Velocity layers
        std::array<VelocityLayer, kMaxVelocityLayers> velocityLayers;
        int numVelocityLayers = 0;
        float velocityCrossfade = 0.0f;  // 0-1 crossfade range

        // Round-robin state
        std::array<int, kMaxRoundRobin> roundRobinIndices;
        int numRoundRobin = 0;
        std::atomic<int> currentRoundRobin{0};

        // Playback
        float volume = 1.0f;
        float pan = 0.5f;
        float pitchOffset = 0.0f;       // Semitones
        float fineTune = 0.0f;          // Cents

        // Sample start/end
        float sampleStart = 0.0f;
        float sampleEnd = 1.0f;

        // Loop
        enum class LoopMode { Off, Forward, Backward, PingPong, Release };
        LoopMode loopMode = LoopMode::Off;

        // Release trigger
        bool releaseTriggered = false;
        std::shared_ptr<SampleData> releaseSample;

        Zone() { roundRobinIndices.fill(-1); }
    };

    //==========================================================================
    // Envelope (DAHDSR)
    //==========================================================================

    struct Envelope
    {
        float delay = 0.0f;         // ms
        float attack = 5.0f;        // ms
        float hold = 0.0f;          // ms
        float decay = 100.0f;       // ms
        float sustain = 0.7f;       // 0-1
        float release = 200.0f;     // ms

        // Curves (-1 to +1, 0 = linear)
        float attackCurve = 0.0f;
        float decayCurve = 0.0f;
        float releaseCurve = 0.0f;

        // Velocity sensitivity
        float velocityToAttack = 0.0f;
        float velocityToLevel = 1.0f;
    };

    //==========================================================================
    // LFO
    //==========================================================================

    struct LFO
    {
        enum class Shape { Sine, Triangle, Saw, Square, SampleHold, Random };
        Shape shape = Shape::Sine;

        float rate = 1.0f;          // Hz (or beat division if synced)
        float depth = 1.0f;         // 0-1
        float phase = 0.0f;         // 0-1 initial phase
        float fade = 0.0f;          // Fade-in time (ms)

        bool tempoSync = false;
        float beatDivision = 0.25f; // 1/4 note

        bool keySync = true;        // Reset on note
        bool unipolar = false;      // 0-1 instead of -1 to +1
    };

    //==========================================================================
    // Modulation Slot
    //==========================================================================

    struct ModSlot
    {
        ModSource source = ModSource::None;
        ModDest destination = ModDest::None;
        float amount = 0.0f;        // -1 to +1
        bool bipolar = true;
    };

    //==========================================================================
    // Granular Engine Parameters
    //==========================================================================

    struct GranularParams
    {
        bool enabled = false;
        float grainSize = 50.0f;        // ms (10-500)
        float grainDensity = 10.0f;     // grains per second (1-100)
        float grainPosition = 0.0f;     // 0-1 (position in sample)
        float grainPositionRand = 0.0f; // 0-1 (randomization)
        float grainPitchRand = 0.0f;    // Semitones random
        float grainPanSpread = 0.0f;    // 0-1 (stereo spread)

        enum class Window { Hann, Triangle, Rectangle, Tukey };
        Window windowType = Window::Hann;
    };

    //==========================================================================
    // Time-Stretch Engine
    //==========================================================================

    struct TimeStretchParams
    {
        bool enabled = false;
        float stretchRatio = 1.0f;      // 0.25 to 4.0
        float pitchShift = 0.0f;        // Semitones
        bool formantPreserve = true;
        bool transientPreserve = true;

        // Phase vocoder settings
        int fftSize = 2048;
        int hopSize = 512;
        float overlap = 4.0f;
    };

    //==========================================================================
    // ZDF Filter State
    //==========================================================================

    struct ZDFFilterState
    {
        float ic1eq = 0.0f;
        float ic2eq = 0.0f;
        float ic3eq = 0.0f;
        float ic4eq = 0.0f;
    };

    //==========================================================================
    // Voice Structure
    //==========================================================================

    struct Voice
    {
        bool active = false;
        int noteNumber = 0;
        float velocity = 0.0f;
        int zoneIndex = -1;
        int layerIndex = -1;

        // Playback state
        double playbackPos = 0.0;
        double playbackSpeed = 1.0;
        bool loopingForward = true;
        bool releasing = false;

        // Envelope states
        struct EnvState
        {
            enum class Stage { Delay, Attack, Hold, Decay, Sustain, Release, Off };
            Stage stage = Stage::Off;
            float level = 0.0f;
            float stageTime = 0.0f;
        };
        std::array<EnvState, 4> envStates;

        // LFO states
        std::array<float, 4> lfoPhases = {0.0f, 0.0f, 0.0f, 0.0f};
        std::array<float, 4> lfoFadeLevel = {0.0f, 0.0f, 0.0f, 0.0f};

        // Filter states (dual)
        ZDFFilterState filter1L, filter1R;
        ZDFFilterState filter2L, filter2R;

        // Granular state
        struct Grain
        {
            bool active = false;
            double position = 0.0;
            double speed = 1.0;
            float windowPos = 0.0f;
            float pan = 0.5f;
            float gain = 1.0f;
        };
        std::array<Grain, 32> grains;
        float grainSpawnAccum = 0.0f;

        // Pitch bend / modulation
        float pitchBend = 0.0f;
        float modWheel = 0.0f;
        float aftertouch = 0.0f;

        // Sample history for interpolation
        std::array<float, kSincTaps> historyL;
        std::array<float, kSincTaps> historyR;
        int historyIndex = 0;

        Voice() {
            historyL.fill(0.0f);
            historyR.fill(0.0f);
            for (auto& g : grains) g.active = false;
        }
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    UltraSampler();
    ~UltraSampler() = default;

    //==========================================================================
    // Initialization
    //==========================================================================

    void prepare(double sampleRate, int maxBlockSize);
    void reset();

    //==========================================================================
    // Sample Management
    //==========================================================================

    /** Load sample file into zone */
    bool loadSample(int zoneIndex, const juce::File& file);

    /** Load sample buffer into zone */
    bool loadSample(int zoneIndex, const juce::AudioBuffer<float>& buffer,
                   double sampleRate, int rootNote = 60);

    /** Add velocity layer to zone */
    bool addVelocityLayer(int zoneIndex, const juce::File& file,
                         int velocityLow, int velocityHigh);

    /** Set zone key range */
    void setZoneKeyRange(int zoneIndex, int keyLow, int keyHigh, int rootKey);

    /** Clear zone */
    void clearZone(int zoneIndex);

    /** Clear all zones */
    void clearAll();

    /** Get zone reference */
    Zone& getZone(int index) { return zones[index]; }
    const Zone& getZone(int index) const { return zones[index]; }

    //==========================================================================
    // Playback Control
    //==========================================================================

    void noteOn(int noteNumber, float velocity, int channel = 0);
    void noteOff(int noteNumber, float velocity, int channel = 0);
    void allNotesOff();

    void setPitchBend(float semitones);
    void setModWheel(float value);
    void setAftertouch(float value);

    //==========================================================================
    // Parameters
    //==========================================================================

    // Global
    void setMasterVolume(float volume);
    void setMasterTune(float cents);
    void setPolyphony(int voices);
    void setGlideTime(float ms);
    void setHostTempo(float bpm) { hostTempo = bpm > 0.0f ? bpm : 120.0f; }

    // Interpolation
    void setInterpolationMode(InterpolationMode mode);

    // Filters
    void setFilter1Type(FilterType type);
    void setFilter1Cutoff(float hz);
    void setFilter1Resonance(float q);
    void setFilter1KeyTrack(float amount);

    void setFilter2Type(FilterType type);
    void setFilter2Cutoff(float hz);
    void setFilter2Resonance(float q);

    void setFilterRouting(float mix);  // 0 = series, 1 = parallel

    // Envelopes
    void setEnvelope(int envIndex, const Envelope& env);
    Envelope& getEnvelope(int index) { return envelopes[index]; }

    // LFOs
    void setLFO(int lfoIndex, const LFO& lfo);
    LFO& getLFO(int index) { return lfos[index]; }

    // Modulation
    void setModSlot(int slot, ModSource source, ModDest dest, float amount);
    ModSlot& getModSlot(int index) { return modSlots[index]; }

    // Macros
    void setMacro(int index, float value);
    float getMacro(int index) const { return macros[index]; }

    // Granular
    void setGranularParams(const GranularParams& params);
    GranularParams& getGranularParams() { return granularParams; }

    // Time-stretch
    void setTimeStretchParams(const TimeStretchParams& params);
    TimeStretchParams& getTimeStretchParams() { return timeStretchParams; }

    //==========================================================================
    // Bio-Reactive
    //==========================================================================

    void setBioData(float hrv, float coherence, float heartRate);
    void setBioReactiveEnabled(bool enabled);

    //==========================================================================
    // Processing
    //==========================================================================

    void processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midiMessages);

    //==========================================================================
    // Presets
    //==========================================================================

    enum class Preset
    {
        Init,
        AcousticPiano,
        ElectricPiano,
        Strings,
        OrchestralBrass,
        Choir,
        PadSweep,
        TextureEvolving,
        DrumKit,
        LoFiKeys,
        GranularAtmosphere,
        BioReactivePad
    };

    void loadPreset(Preset preset);

    //==========================================================================
    // Analysis / Visualization
    //==========================================================================

    /** Get current voice count */
    int getActiveVoiceCount() const;

    /** Get playback position for zone (0-1) */
    float getZonePlaybackPosition(int zoneIndex) const;

    /** Get envelope level for display */
    float getEnvelopeLevel(int envIndex) const;

    /** Get LFO value for display */
    float getLFOValue(int lfoIndex) const;

private:
    //==========================================================================
    // Internal State
    //==========================================================================

    double sampleRate = 48000.0;
    int blockSize = 512;

    // Zones
    std::array<Zone, kMaxZones> zones;

    // Voice pool
    std::array<Voice, kMaxVoices> voices;
    int maxPolyphony = 32;

    // Parameters
    float masterVolume = 1.0f;
    float masterTune = 0.0f;
    float glideTime = 0.0f;
    InterpolationMode interpMode = InterpolationMode::Auto;

    // Filters
    FilterType filter1Type = FilterType::LowPass24;
    float filter1Cutoff = 8000.0f;
    float filter1Resonance = 0.3f;
    float filter1KeyTrack = 0.0f;

    FilterType filter2Type = FilterType::Off;
    float filter2Cutoff = 4000.0f;
    float filter2Resonance = 0.3f;
    float filterMix = 0.0f;

    // Envelopes
    std::array<Envelope, 4> envelopes;

    // LFOs
    std::array<LFO, 4> lfos;

    // Round-robin and tempo tracking
    static constexpr int MAX_ROUND_ROBIN_GROUPS = 16;
    std::array<int, MAX_ROUND_ROBIN_GROUPS> roundRobinCounters{};
    float hostTempo = 120.0f;

    // Sample & Hold LFO state
    std::array<float, 4> lastSampleHoldPhase{};
    std::array<float, 4> sampleHoldValues{};

    // Modulation
    std::array<ModSlot, kMaxModSlots> modSlots;

    // Macros
    std::array<float, 8> macros = {0.5f, 0.5f, 0.5f, 0.5f, 0.5f, 0.5f, 0.5f, 0.5f};

    // Granular
    GranularParams granularParams;

    // Time-stretch
    TimeStretchParams timeStretchParams;

    // Bio-reactive
    float bioHRV = 0.5f;
    float bioCoherence = 0.5f;
    float bioHeartRate = 70.0f;
    bool bioReactiveEnabled = false;

    // Pitch bend state
    float globalPitchBend = 0.0f;
    float globalModWheel = 0.0f;

    // Sinc table (precomputed)
    std::array<std::array<float, kSincTaps>, 256> sincTable;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    // Voice management
    Voice* allocateVoice(int noteNumber);
    void freeVoice(Voice& voice);
    int findZoneForNote(int noteNumber, float velocity);
    int selectVelocityLayer(const Zone& zone, float velocity);

    // Processing
    void processVoice(Voice& voice, float* leftOut, float* rightOut, int numSamples);
    void processGranularVoice(Voice& voice, float* leftOut, float* rightOut, int numSamples);

    // Sample reading with interpolation
    float readSampleLinear(const SampleData& sample, double pos, int channel);
    float readSampleHermite(const SampleData& sample, double pos, int channel);
    float readSampleSinc(const SampleData& sample, double pos, int channel, Voice& voice);
    float readSample(const SampleData& sample, double pos, int channel, Voice& voice);

    // Envelope processing
    float processEnvelope(Voice& voice, int envIndex);
    float calculateEnvelopeCurve(float t, float curve);

    // LFO processing
    float processLFO(Voice& voice, int lfoIndex);

    // Filter processing (ZDF)
    float processFilter(float input, FilterType type, float cutoff, float resonance,
                       ZDFFilterState& state, bool isLeft);
    float processLadderFilter(float input, float cutoff, float resonance,
                             ZDFFilterState& state);

    // Modulation
    float getModulationValue(Voice& voice, ModSource source);
    float applyModulation(Voice& voice, ModDest dest, float baseValue);

    // Granular
    void spawnGrain(Voice& voice, const Zone& zone);
    float processGrain(Voice::Grain& grain, const SampleData& sample, int channel);
    float grainWindow(float pos, GranularParams::Window type);

    // Utilities
    void buildSincTable();
    float midiToFreq(float note);
    float freqToMidi(float freq);

    // SIMD helpers
    void processSIMD(float* buffer, int numSamples);

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(UltraSampler)
};

//==============================================================================
// Inline Implementations
//==============================================================================

inline float UltraSampler::readSampleLinear(const SampleData& sample, double pos, int channel)
{
    const auto& data = (channel == 0) ? sample.left : sample.right;
    if (data.empty()) return 0.0f;

    int idx0 = static_cast<int>(pos);
    int idx1 = idx0 + 1;
    float frac = static_cast<float>(pos - idx0);

    if (idx1 >= static_cast<int>(data.size())) {
        if (sample.loopEnabled && sample.loopEnd > sample.loopStart) {
            idx1 = sample.loopStart;
        } else {
            return data[idx0];
        }
    }

    return data[idx0] + frac * (data[idx1] - data[idx0]);
}

inline float UltraSampler::readSampleHermite(const SampleData& sample, double pos, int channel)
{
    const auto& data = (channel == 0) ? sample.left : sample.right;
    int size = static_cast<int>(data.size());
    if (size < 4) return readSampleLinear(sample, pos, channel);

    int idx1 = static_cast<int>(pos);
    int idx0 = std::max(0, idx1 - 1);
    int idx2 = std::min(size - 1, idx1 + 1);
    int idx3 = std::min(size - 1, idx1 + 2);

    float frac = static_cast<float>(pos - idx1);

    float y0 = data[idx0];
    float y1 = data[idx1];
    float y2 = data[idx2];
    float y3 = data[idx3];

    // Hermite interpolation coefficients
    float c0 = y1;
    float c1 = 0.5f * (y2 - y0);
    float c2 = y0 - 2.5f * y1 + 2.0f * y2 - 0.5f * y3;
    float c3 = 0.5f * (y3 - y0) + 1.5f * (y1 - y2);

    return ((c3 * frac + c2) * frac + c1) * frac + c0;
}

inline float UltraSampler::calculateEnvelopeCurve(float t, float curve)
{
    if (std::abs(curve) < 0.001f) return t;

    if (curve > 0.0f) {
        // Exponential
        return std::pow(t, 1.0f + curve * 3.0f);
    } else {
        // Logarithmic
        return 1.0f - std::pow(1.0f - t, 1.0f - curve * 3.0f);
    }
}

inline float UltraSampler::grainWindow(float pos, GranularParams::Window type)
{
    if (pos < 0.0f || pos > 1.0f) return 0.0f;

    switch (type) {
        case GranularParams::Window::Hann:
            return 0.5f * (1.0f - std::cos(2.0f * juce::MathConstants<float>::pi * pos));
        case GranularParams::Window::Triangle:
            return 1.0f - std::abs(2.0f * pos - 1.0f);
        case GranularParams::Window::Rectangle:
            return 1.0f;
        case GranularParams::Window::Tukey: {
            float alpha = 0.5f;
            if (pos < alpha / 2.0f)
                return 0.5f * (1.0f + std::cos(juce::MathConstants<float>::pi * (2.0f * pos / alpha - 1.0f)));
            else if (pos > 1.0f - alpha / 2.0f)
                return 0.5f * (1.0f + std::cos(juce::MathConstants<float>::pi * (2.0f * pos / alpha - 2.0f / alpha + 1.0f)));
            else
                return 1.0f;
        }
        default:
            return 1.0f;
    }
}

inline float UltraSampler::midiToFreq(float note)
{
    return 440.0f * std::pow(2.0f, (note - 69.0f) / 12.0f);
}

inline float UltraSampler::freqToMidi(float freq)
{
    return 69.0f + 12.0f * std::log2(freq / 440.0f);
}
