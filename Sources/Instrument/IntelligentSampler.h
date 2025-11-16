#pragma once

#include <JuceHeader.h>
#include <vector>
#include <array>
#include <map>

/**
 * IntelligentSampler
 *
 * AI-powered multi-layer sampler with advanced time-stretching, pitch-shifting,
 * and automatic sample mapping. Rivals Kontakt 7 and HALion 7.
 *
 * Features:
 * - Multi-layer architecture (128 layers per instrument)
 * - Zone mapping (velocity, key, round-robin, random)
 * - Advanced time-stretching (Elastique 3.0 quality)
 * - Formant-preserving pitch shifting
 * - AI-powered auto-mapping (drop folder → instant instrument)
 * - Sample analysis & intelligent tagging
 * - Automatic loop finding & optimization
 * - Articulation detection (legato, staccato, tremolo, etc.)
 * - Real-time convolution reverb
 * - Bio-reactive sample selection
 * - 8 insert effects per layer
 * - Deep modulation matrix (64 slots)
 */
class IntelligentSampler : public juce::Synthesiser
{
public:
    //==========================================================================
    // Sample Engines
    //==========================================================================

    enum class SampleEngine
    {
        Classic,            // Traditional pitch-shifting via resampling
        Stretch,            // Time-stretch + pitch-shift independent
        Granular,           // Granular resynthesis
        Spectral,           // FFT-based manipulation
        Hybrid              // Best of all modes
    };

    //==========================================================================
    // Layer & Zone Configuration
    //==========================================================================

    struct SampleZone
    {
        std::string samplePath;
        int rootKey = 60;               // Middle C
        int lowKey = 0;
        int highKey = 127;
        int lowVelocity = 0;
        int highVelocity = 127;

        // Loop points (in samples)
        bool loopEnabled = false;
        int loopStart = 0;
        int loopEnd = 0;
        enum class LoopMode { Off, Forward, PingPong, Reverse };
        LoopMode loopMode = LoopMode::Forward;

        // Tuning
        float pitchCents = 0.0f;        // Fine tuning
        float sampleRate = 48000.0f;    // Original sample rate

        // Playback
        int sampleStart = 0;
        int sampleEnd = 0;
        bool reverse = false;

        // Round-robin
        int roundRobinGroup = 0;
        int roundRobinIndex = 0;
    };

    struct Layer
    {
        std::string name;
        std::vector<SampleZone> zones;

        // Engine settings
        SampleEngine engine = SampleEngine::Hybrid;

        // Volume & Pan
        float volume = 1.0f;
        float pan = 0.0f;

        // Tuning
        float pitchSemitones = 0.0f;
        float pitchCents = 0.0f;

        // Filter
        struct FilterParams
        {
            enum class Type { Off, Lowpass12, Lowpass24, Highpass, Bandpass };
            Type type = Type::Off;
            float cutoff = 20000.0f;
            float resonance = 0.0f;
            float keyTrack = 0.0f;      // Filter follows key
            float envelopeAmount = 0.0f;
        };
        FilterParams filter;

        // Envelopes
        struct Envelope
        {
            float attack = 0.01f;
            float decay = 0.1f;
            float sustain = 0.7f;
            float release = 0.3f;
        };
        Envelope ampEnvelope;
        Envelope filterEnvelope;

        // Effects (8 slots per layer)
        std::array<std::string, 8> effectChain;  // Effect IDs

        bool enabled = true;
        bool solo = false;
        bool mute = false;
    };

    //==========================================================================
    // Articulation Detection
    //==========================================================================

    enum class Articulation
    {
        Sustain,
        Staccato,
        Legato,
        Tremolo,
        Trill,
        Glissando,
        Pizzicato,
        Marcato,
        Tenuto,
        Unknown
    };

    struct ArticulationInfo
    {
        Articulation type = Articulation::Unknown;
        float confidence = 0.0f;        // 0.0 to 1.0
        float duration = 0.0f;          // seconds
        float intensity = 0.0f;         // 0.0 to 1.0
    };

    //==========================================================================
    // AI Auto-Mapping
    //==========================================================================

    struct AutoMapResult
    {
        bool success = false;
        int layersCreated = 0;
        int samplesProcessed = 0;
        std::vector<std::string> warnings;
        std::vector<SampleZone> generatedZones;
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    IntelligentSampler();
    ~IntelligentSampler() override = default;

    //==========================================================================
    // Layer Management
    //==========================================================================

    static constexpr int maxLayers = 128;

    /** Add layer */
    int addLayer(const Layer& layer);

    /** Remove layer */
    void removeLayer(int index);

    /** Get layer */
    Layer& getLayer(int index);
    const Layer& getLayer(int index) const;

    /** Get number of layers */
    int getNumLayers() const { return static_cast<int>(layers.size()); }

    //==========================================================================
    // Sample Loading
    //==========================================================================

    /** Load sample into zone */
    bool loadSample(int layerIndex, const juce::File& file);

    /** Load multiple samples */
    bool loadSamples(int layerIndex, const std::vector<juce::File>& files);

    /** Load entire folder (auto-map) */
    AutoMapResult loadFolder(const juce::File& folder, bool autoMap = true);

    //==========================================================================
    // AI Auto-Mapping
    //==========================================================================

    /** Automatically map samples to keyboard */
    AutoMapResult autoMap(const std::vector<juce::File>& samples);

    /** Detect sample pitch using AI */
    int detectPitch(const juce::AudioBuffer<float>& audio);

    /** Find optimal loop points */
    struct LoopPoints
    {
        int start = 0;
        int end = 0;
        float quality = 0.0f;           // 0.0 to 1.0
    };
    LoopPoints findLoopPoints(const juce::AudioBuffer<float>& audio);

    /** Detect articulation */
    ArticulationInfo detectArticulation(const juce::AudioBuffer<float>& audio);

    //==========================================================================
    // Sample Engine
    //==========================================================================

    void setSampleEngine(int layerIndex, SampleEngine engine);
    SampleEngine getSampleEngine(int layerIndex) const;

    //==========================================================================
    // Time-Stretching & Pitch-Shifting
    //==========================================================================

    /** Set time-stretch ratio (0.5 = half speed, 2.0 = double speed) */
    void setTimeStretchRatio(float ratio);

    /** Set pitch-shift semitones */
    void setPitchShift(float semitones);

    /** Enable/disable formant preservation */
    void setFormantPreservation(bool enabled);

    //==========================================================================
    // Modulation Matrix
    //==========================================================================

    static constexpr int maxModulationSlots = 64;

    enum class ModSource
    {
        LFO1, LFO2, LFO3, LFO4,
        Envelope1, Envelope2, Envelope3, Envelope4,
        Velocity, Aftertouch, ModWheel, PitchBend,
        BioHRV, BioCoherence, BioBreath,
        Random
    };

    enum class ModDestination
    {
        Volume, Pan, Pitch,
        FilterCutoff, FilterResonance,
        SampleStart, LoopStart,
        TimeStretch, PitchShift,
        EffectParam1, EffectParam2
    };

    struct ModulationSlot
    {
        ModSource source = ModSource::LFO1;
        ModDestination dest = ModDestination::FilterCutoff;
        float amount = 0.0f;
        int layerIndex = -1;            // -1 = all layers
        bool enabled = false;
    };

    ModulationSlot& getModulationSlot(int index);
    void addModulation(ModSource src, ModDestination dest, float amount);
    void clearAllModulation();

    //==========================================================================
    // Effects
    //==========================================================================

    /** Add effect to layer */
    void addEffect(int layerIndex, int slotIndex, const std::string& effectId);

    /** Remove effect */
    void removeEffect(int layerIndex, int slotIndex);

    //==========================================================================
    // Bio-Reactive Control
    //==========================================================================

    void setBioReactiveEnabled(bool enabled);
    void setBioData(float hrv, float coherence, float breath);

    /** Bio-reactive sample selection (chooses different samples based on HRV) */
    void enableBioReactiveSampleSelection(bool enabled);

    //==========================================================================
    // Convolution Reverb
    //==========================================================================

    /** Load impulse response */
    bool loadImpulseResponse(const juce::File& irFile);

    /** Set reverb mix */
    void setReverbMix(float mix);

    //==========================================================================
    // Processing
    //==========================================================================

    void prepare(double sampleRate, int maxBlockSize);
    void reset();

    //==========================================================================
    // Preset Management
    //==========================================================================

    struct InstrumentPreset
    {
        std::string name;
        std::string category;
        std::vector<Layer> layers;
        std::array<ModulationSlot, maxModulationSlots> modMatrix;
    };

    void savePreset(const juce::File& file);
    bool loadPreset(const juce::File& file);

    std::vector<std::string> getPresetCategories() const;
    std::vector<InstrumentPreset> getPresetsInCategory(const std::string& category) const;

private:
    //==========================================================================
    // Voice Class
    //==========================================================================

    class SamplerVoice : public juce::SynthesiserVoice
    {
    public:
        SamplerVoice(IntelligentSampler& parent);

        bool canPlaySound(juce::SynthesiserSound*) override;
        void startNote(int midiNoteNumber, float velocity,
                      juce::SynthesiserSound*, int currentPitchWheelPosition) override;
        void stopNote(float velocity, bool allowTailOff) override;
        void pitchWheelMoved(int newPitchWheelValue) override;
        void controllerMoved(int controllerNumber, int newControllerValue) override;
        void renderNextBlock(juce::AudioBuffer<float>& outputBuffer,
                            int startSample, int numSamples) override;

    private:
        IntelligentSampler& sampler;
        const SampleZone* currentZone = nullptr;
        juce::AudioBuffer<float> sampleBuffer;

        double samplePosition = 0.0;
        float pitchRatio = 1.0f;
        float envelopeValue = 0.0f;

        // Time-stretching
        std::unique_ptr<juce::TimeSliceThread> stretchThread;
    };

    //==========================================================================
    // State
    //==========================================================================

    std::vector<Layer> layers;
    std::array<ModulationSlot, maxModulationSlots> modulationMatrix;

    bool bioReactiveEnabled = false;
    bool bioReactiveSampleSelection = false;
    float bioHRV = 0.5f, bioCoherence = 0.5f, bioBreath = 0.5f;

    double currentSampleRate = 48000.0;

    // Round-robin state
    std::map<int, int> roundRobinCounters;  // group → current index

    // Sample cache
    std::map<std::string, juce::AudioBuffer<float>> sampleCache;

    // Convolution IR
    juce::AudioBuffer<float> impulseResponse;
    float reverbMix = 0.0f;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    const SampleZone* findZone(int midiNote, int velocity, int layerIndex);
    int getNextRoundRobinIndex(int group);

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (IntelligentSampler)
};
