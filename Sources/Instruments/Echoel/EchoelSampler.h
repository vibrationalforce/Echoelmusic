#pragma once

#include <JuceHeader.h>
#include <vector>
#include <map>
#include <memory>

/**
 * EchoelSampler - Professional Multi-Layer Sampler
 *
 * Kontakt/Omnisphere competitor with advanced features:
 * - Multi-layer sample mapping with velocity/key switching
 * - Round-robin alternation for realistic performances
 * - Granular synthesis engine for textural soundscapes
 * - Time-stretching with transient preservation
 * - Advanced modulation matrix
 * - Convolution reverb with custom IRs
 * - Import from Kontakt (.nki), SoundFont (.sf2), EXS24 (.exs)
 *
 * Perfect for orchestral libraries, sound design, and complex instruments.
 */
class EchoelSampler : public juce::Synthesiser
{
public:
    //==============================================================================
    EchoelSampler();
    ~EchoelSampler() override = default;

    //==============================================================================
    // Sample Management
    struct SampleZone {
        juce::AudioBuffer<float> audioData;
        std::vector<juce::AudioBuffer<float>> roundRobinSamples;  // Alternate samples

        int rootNote = 60;
        int lowKey = 0;
        int highKey = 127;
        int lowVel = 0;
        int highVel = 127;

        float loopStart = 0.0f;   // Normalized 0-1
        float loopEnd = 1.0f;
        bool loopEnabled = false;

        int roundRobinIndex = 0;

        // Sample playback
        float tuning = 0.0f;      // Cents
        float pan = 0.0f;         // -1 to +1
        float volume = 1.0f;

        // Envelope
        float attack = 0.001f;
        float decay = 0.1f;
        float sustain = 1.0f;
        float release = 0.1f;
    };

    void addSampleZone(const SampleZone& zone);
    void clearAllZones();
    int getNumZones() const { return static_cast<int>(sampleZones.size()); }

    // Sample loading
    bool loadSample(const juce::File& file, int rootNote = 60);
    bool loadMultiSamples(const std::vector<juce::File>& files, int startNote);
    bool loadFromSoundFont(const juce::File& sf2File);

    //==============================================================================
    // Granular Engine
    struct GranularParams {
        bool enabled = false;
        float grainSize = 100.0f;       // ms
        float position = 0.5f;          // Sample position (0-1)
        float spray = 0.1f;             // Random position deviation
        float density = 10.0f;          // Grains per second
        float pitch = 1.0f;             // Pitch shift
        float reverseProb = 0.0f;       // Probability of reversed grain
    };

    void setGranularEnabled(bool enabled);
    void setGranularParams(const GranularParams& params);
    GranularParams getGranularParams() const { return granularParams; }

    //==============================================================================
    // Time Stretching
    struct TimeStretchParams {
        bool enabled = false;
        float stretchFactor = 1.0f;     // 0.5 = half speed, 2.0 = double speed
        bool preserveFormants = true;
        bool preserveTransients = true;
    };

    void setTimeStretchParams(const TimeStretchParams& params);
    TimeStretchParams getTimeStretchParams() const { return timeStretchParams; }

    //==============================================================================
    // Filter Section
    enum class FilterType {
        LowPass24,
        LowPass12,
        HighPass24,
        HighPass12,
        BandPass,
        Notch,
        Formant
    };

    void setFilterType(FilterType type);
    void setFilterCutoff(float frequency);
    void setFilterResonance(float resonance);
    void setFilterEnvAmount(float amount);
    void setFilterKeyTracking(float amount);  // Key follow

    //==============================================================================
    // Modulation Matrix
    enum class ModSource {
        None,
        LFO1,
        LFO2,
        Envelope1,
        Envelope2,
        ModWheel,
        Velocity,
        AfterTouch,
        Random,
        HeartRate,      // Biometric
        HRV,            // Heart rate variability
        Coherence       // HRV coherence
    };

    enum class ModDestination {
        None,
        Pitch,
        FilterCutoff,
        FilterResonance,
        Amplitude,
        Pan,
        GrainPosition,
        GrainSize,
        TimeStretch
    };

    struct ModConnection {
        ModSource source = ModSource::None;
        ModDestination destination = ModDestination::None;
        float amount = 0.0f;
        bool bipolar = false;  // -1 to +1 or 0 to +1
    };

    void addModulation(const ModConnection& connection);
    void clearModulations();
    std::vector<ModConnection> getModulations() const { return modConnections; }

    //==============================================================================
    // Effects Chain
    void setReverbEnabled(bool enabled);
    void setReverbMix(float mix);
    void loadConvolutionIR(const juce::File& irFile);

    void setCompressorEnabled(bool enabled);
    void setCompressorParams(float threshold, float ratio, float attack, float release);

    void setDelayEnabled(bool enabled);
    void setDelayParams(float time, float feedback, float mix);

    //==============================================================================
    // Biometric Integration
    void setHeartRate(float bpm);
    void setHeartRateVariability(float hrv);
    void setCoherence(float coherence);

    //==============================================================================
    // Presets
    void savePreset(const juce::File& file);
    bool loadPreset(const juce::File& file);

    //==============================================================================
    // Audio Processing
    void prepare(double sampleRate, int samplesPerBlock, int numChannels);
    void processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midiMessages);
    void reset();

private:
    //==============================================================================
    // Sample Storage
    std::vector<SampleZone> sampleZones;

    //==============================================================================
    // Granular Engine
    GranularParams granularParams;

    struct Grain {
        float position = 0.0f;
        float phase = 0.0f;
        float duration = 0.0f;
        float amplitude = 0.0f;
        bool active = false;
        bool reverse = false;
        const SampleZone* zone = nullptr;
    };

    std::vector<Grain> grainPool;
    static constexpr int MAX_GRAINS = 128;

    void processGranular(juce::AudioBuffer<float>& buffer);
    void spawnGrain();
    float processGrain(Grain& grain);

    //==============================================================================
    // Time Stretching
    TimeStretchParams timeStretchParams;

    struct PhaseVocoder {
        juce::dsp::FFT fft{12};  // 4096 point FFT
        std::vector<float> fftData;
        std::vector<float> windowedData;
        std::vector<float> previousPhase;
        std::vector<float> synthesisPhase;
    };

    PhaseVocoder phaseVocoder;
    void processTimeStretch(juce::AudioBuffer<float>& buffer);

    //==============================================================================
    // Filter
    FilterType filterType = FilterType::LowPass24;
    float filterCutoff = 20000.0f;
    float filterResonance = 0.0f;
    float filterEnvAmount = 0.0f;
    float filterKeyTracking = 0.0f;

    juce::dsp::StateVariableTPTFilter<float> filter;

    //==============================================================================
    // Modulation
    std::vector<ModConnection> modConnections;

    struct ModState {
        float lfo1 = 0.0f;
        float lfo2 = 0.0f;
        float env1 = 0.0f;
        float env2 = 0.0f;
        float velocity = 0.0f;
        float modWheel = 0.0f;
        float afterTouch = 0.0f;
        float heartRate = 70.0f;
        float hrv = 0.5f;
        float coherence = 0.5f;
    };

    ModState modState;
    void updateModulation();
    float getModSourceValue(ModSource source);
    void applyModulation(ModDestination destination, float value);

    //==============================================================================
    // Effects
    bool reverbEnabled = false;
    float reverbMix = 0.3f;
    juce::dsp::Convolution convolutionReverb;

    bool compressorEnabled = false;
    juce::dsp::Compressor<float> compressor;

    bool delayEnabled = false;
    float delayTime = 0.3f;
    float delayFeedback = 0.4f;
    float delayMix = 0.3f;
    juce::dsp::DelayLine<float> delayLine{48000};

    //==============================================================================
    // State
    double currentSampleRate = 44100.0;
    int currentSamplesPerBlock = 512;
    int currentNumChannels = 2;

    //==============================================================================
    // Voice Class
    class EchoelSamplerVoice : public juce::SynthesiserVoice
    {
    public:
        EchoelSamplerVoice(EchoelSampler& parent);

        bool canPlaySound(juce::SynthesiserSound*) override;
        void startNote(int midiNoteNumber, float velocity,
                      juce::SynthesiserSound*, int currentPitchWheelPosition) override;
        void stopNote(float velocity, bool allowTailOff) override;
        void pitchWheelMoved(int newPitchWheelValue) override;
        void controllerMoved(int controllerNumber, int newControllerValue) override;
        void renderNextBlock(juce::AudioBuffer<float>& outputBuffer,
                            int startSample, int numSamples) override;

    private:
        EchoelSampler& samplerRef;
        const SampleZone* currentZone = nullptr;
        double playbackPosition = 0.0;
        double playbackSpeed = 1.0;
        float currentVelocity = 1.0f;
        int currentNote = 60;

        // ADSR
        float envLevel = 0.0f;
        enum class EnvStage { Attack, Decay, Sustain, Release, Idle };
        EnvStage envStage = EnvStage::Idle;
    };

    class EchoelSamplerSound : public juce::SynthesiserSound
    {
    public:
        bool appliesToNote(int) override { return true; }
        bool appliesToChannel(int) override { return true; }
    };
};
