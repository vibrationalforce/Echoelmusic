#pragma once

#include <JuceHeader.h>
#include "../DSP/SpectralFramework.h"
#include <vector>
#include <array>

/**
 * SpectralGranularSynth
 *
 * Next-generation granular synthesis engine combining FFT spectral analysis
 * with intelligent grain manipulation and ML-assisted processing.
 *
 * Features:
 * - FFT-based sample analysis and grain extraction
 * - Intelligent grain selection (tonal vs. noisy separation)
 * - Spectral morphing between multiple sources
 * - 32 simultaneous grain streams with independent control
 * - Bio-reactive grain density and position
 * - Real-time spectral freezing and manipulation
 * - ML-assisted grain evolution
 * - Polyphonic playback (16 voices)
 *
 * Synthesis Modes:
 * - Classic Granular (time-domain)
 * - Spectral Grains (FFT-based)
 * - Hybrid (best of both)
 * - Neural Grains (AI-selected)
 */
class SpectralGranularSynth : public juce::Synthesiser
{
public:
    //==========================================================================
    // Grain Modes
    //==========================================================================

    enum class GrainMode
    {
        Classic,            // Traditional time-domain granular
        Spectral,           // FFT-based spectral grains
        Hybrid,             // Combination of both
        Neural,             // AI-selected grains
        Texture             // ML-generated textures
    };

    enum class GrainSource
    {
        Buffer,             // Pre-loaded audio buffer
        LiveInput,          // Real-time audio input
        Synthesized,        // Generated grains (oscillators)
        Wavetable          // Wavetable-based grains
    };

    //==========================================================================
    // Grain Parameters
    //==========================================================================

    struct GrainParams
    {
        // Size & Timing
        float sizeMs = 50.0f;           // 1ms - 1000ms
        float densityHz = 20.0f;        // 1 - 256 grains/sec
        float positionMs = 0.0f;        // Position in source buffer

        // Spray (Randomization)
        float positionSpray = 0.0f;     // 0.0 to 1.0
        float pitchSpray = 0.0f;
        float panSpray = 0.0f;
        float sizeSpray = 0.0f;

        // Pitch & Tuning
        float pitchSemitones = 0.0f;    // -24 to +24
        float pitchRandom = 0.0f;       // Random pitch variation

        // Envelope
        enum class EnvelopeShape
        {
            Linear, Exponential, Gaussian, Hann, Hamming, Welch, Triangle, Trapezoid
        };
        EnvelopeShape envelope = EnvelopeShape::Gaussian;
        float attack = 0.1f;            // 0.0 to 1.0 (portion of grain)
        float release = 0.1f;

        // Direction
        enum class Direction
        {
            Forward, Reverse, BiDirectional, Random
        };
        Direction direction = Direction::Forward;

        // Spectral Parameters
        float spectralMaskLow = 20.0f;      // Hz
        float spectralMaskHigh = 20000.0f;  // Hz
        float tonalityThreshold = 0.5f;     // 0.0 = all, 1.0 = only tonal
        float noisiness = 0.0f;             // 0.0 = tonal only, 1.0 = noisy only
    };

    //==========================================================================
    // Grain Stream (32 independent streams)
    //==========================================================================

    struct GrainStream
    {
        bool enabled = true;
        GrainParams params;
        float level = 1.0f;
        float pan = 0.0f;               // -1.0 (L) to +1.0 (R)

        // Modulation (per stream)
        int lfoIndex = -1;              // Which LFO modulates this stream (-1 = none)
        float lfoToPosition = 0.0f;
        float lfoToPitch = 0.0f;
        float lfoToDensity = 0.0f;
    };

    //==========================================================================
    // Special Modes
    //==========================================================================

    struct FreezeModeParams
    {
        bool enabled = false;
        float position = 0.5f;          // Position to freeze
        float windowSize = 100.0f;      // ms
        float spectralBlur = 0.0f;      // Smear frozen spectrum
    };

    struct SwarmModeParams
    {
        bool enabled = false;
        float chaos = 0.5f;             // Amount of chaotic behavior
        float attraction = 0.5f;        // Grains attracted to position
        float repulsion = 0.0f;         // Grains repel each other
    };

    struct TextureModeParams
    {
        bool enabled = false;
        float complexity = 0.5f;        // Texture complexity
        float evolution = 0.0f;         // Auto-evolution speed
        float randomness = 0.3f;        // Amount of randomization
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    SpectralGranularSynth();
    ~SpectralGranularSynth() override = default;

    //==========================================================================
    // Source Management
    //==========================================================================

    /** Load audio buffer as grain source */
    void loadBuffer(const juce::AudioBuffer<float>& buffer);

    /** Load from file */
    bool loadFile(const juce::File& file);

    /** Set grain source type */
    void setGrainSource(GrainSource source);
    GrainSource getGrainSource() const { return grainSource; }

    /** Enable/disable live input */
    void setLiveInputEnabled(bool enabled);

    //==========================================================================
    // Grain Mode
    //==========================================================================

    void setGrainMode(GrainMode mode);
    GrainMode getGrainMode() const { return grainMode; }

    //==========================================================================
    // Grain Streams
    //==========================================================================

    static constexpr int maxGrainStreams = 32;

    GrainStream& getGrainStream(int index);
    const GrainStream& getGrainStream(int index) const;

    void setNumActiveStreams(int num);  // 1-32
    int getNumActiveStreams() const { return numActiveStreams; }

    //==========================================================================
    // Global Grain Parameters
    //==========================================================================

    void setGrainSize(float ms);
    void setGrainDensity(float hz);
    void setGrainPosition(float position);  // 0.0 to 1.0
    void setGrainPitch(float semitones);

    //==========================================================================
    // Special Modes
    //==========================================================================

    FreezeModeParams& getFreezeModeParams() { return freezeParams; }
    SwarmModeParams& getSwarmModeParams() { return swarmParams; }
    TextureModeParams& getTextureModeParams() { return textureParams; }

    /** Capture current grains and freeze */
    void captureAndFreeze();

    //==========================================================================
    // Spectral Processing
    //==========================================================================

    /** Set spectral masking (isolate frequency range) */
    void setSpectralMask(float lowHz, float highHz);

    /** Set tonality filter (0.0 = all, 1.0 = only tonal) */
    void setTonalityFilter(float amount);

    /** Enable/disable formant preservation */
    void setFormantPreservation(bool enabled);

    //==========================================================================
    // Bio-Reactive Control
    //==========================================================================

    void setBioReactiveEnabled(bool enabled);
    void setBioData(float hrv, float coherence, float breath);

    struct BioMapping
    {
        float hrvToDensity = 0.5f;      // HRV modulates grain density
        float hrvToPosition = 0.0f;     // HRV modulates playback position
        float coherenceToSize = 0.0f;   // Coherence modulates grain size
        float breathToPitch = 0.0f;     // Breath modulates pitch
    };

    void setBioMapping(const BioMapping& mapping);

    //==========================================================================
    // Processing
    //==========================================================================

    void prepare(double sampleRate, int maxBlockSize);
    void reset();

    //==========================================================================
    // Visualization
    //==========================================================================

    /** Get grain cloud visualization data */
    struct GrainVisualization
    {
        std::vector<float> grainPositions;  // 0.0 to 1.0
        std::vector<float> grainPitches;    // Semitones
        std::vector<float> grainLevels;     // 0.0 to 1.0
        int activeGrainCount = 0;
    };

    GrainVisualization getGrainVisualization() const;

    /** Get spectral representation of current grains */
    std::vector<float> getGrainSpectrum() const;

private:
    //==========================================================================
    // Grain Engine
    //==========================================================================

    struct Grain
    {
        bool active = false;
        float position = 0.0f;          // Position in buffer (samples)
        float size = 0.0f;              // Size in samples
        float pitch = 1.0f;             // Pitch multiplier
        float pan = 0.0f;
        float phase = 0.0f;             // Current playback phase
        float age = 0.0f;               // Age in samples
        int streamIndex = 0;            // Which stream this grain belongs to

        // Spectral grain data (if using spectral mode)
        SpectralFramework::SpectralData spectralData;
        bool isSpectral = false;
    };

    static constexpr int maxGrainsPerStream = 256;
    std::array<std::array<Grain, maxGrainsPerStream>, maxGrainStreams> grainPools;

    //==========================================================================
    // Voice Class
    //==========================================================================

    class GranularVoice : public juce::SynthesiserVoice
    {
    public:
        GranularVoice(SpectralGranularSynth& parent);

        bool canPlaySound(juce::SynthesiserSound*) override { return true; }

        void startNote(int midiNoteNumber, float velocity,
                      juce::SynthesiserSound*, int currentPitchWheelPosition) override;
        void stopNote(float velocity, bool allowTailOff) override;
        void pitchWheelMoved(int newPitchWheelValue) override;
        void controllerMoved(int controllerNumber, int newControllerValue) override;
        void renderNextBlock(juce::AudioBuffer<float>& outputBuffer,
                            int startSample, int numSamples) override;

    private:
        SpectralGranularSynth& synth;
        int currentNote = 0;
        float baseFrequency = 440.0f;
    };

    //==========================================================================
    // State
    //==========================================================================

    GrainMode grainMode = GrainMode::Hybrid;
    GrainSource grainSource = GrainSource::Buffer;

    std::array<GrainStream, maxGrainStreams> grainStreams;
    int numActiveStreams = 8;

    FreezeModeParams freezeParams;
    SwarmModeParams swarmParams;
    TextureModeParams textureParams;

    bool bioReactiveEnabled = false;
    BioMapping bioMapping;
    float bioHRV = 0.5f, bioCoherence = 0.5f, bioBreath = 0.5f;

    double currentSampleRate = 48000.0;

    //==========================================================================
    // Source Buffer
    //==========================================================================

    juce::AudioBuffer<float> sourceBuffer;
    SpectralFramework spectralEngine;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    void generateGrain(int streamIndex);
    void renderGrain(const Grain& grain, juce::AudioBuffer<float>& output, int startSample, int numSamples);
    float getGrainEnvelope(float phase, GrainParams::EnvelopeShape shape, float attack, float release);

    void analyzeSourceSpectrum();
    void applySpectralMask(SpectralFramework::SpectralData& data);

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (SpectralGranularSynth)
};
