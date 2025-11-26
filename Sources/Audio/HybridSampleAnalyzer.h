#pragma once

#include <JuceHeader.h>
#include <vector>
#include <complex>
#include <map>

/**
 * HYBRID SAMPLE ANALYSIS ENGINE
 *
 * Analysiert echte Samples und erstellt synthetische Models davon!
 *
 * WORKFLOW:
 * 1. Load Sample (WAV file)
 * 2. Analyze:
 *    - Spectral Analysis (FFT)
 *    - Pitch Detection
 *    - Harmonic Content
 *    - Envelope (ADSR)
 *    - Timbre Characteristics
 * 3. Create Synthesis Model:
 *    - Wavetable from harmonics
 *    - Envelope parameters
 *    - Filter characteristics
 * 4. Apply Analog Behavior:
 *    - Tape saturation
 *    - Tube warmth
 *    - Vintage character
 * 5. Integrate with Producer Styles
 *
 * RESULT:
 * - Kleiner als Original (synthesis model vs. full sample)
 * - Vollständig parametrisch
 * - Analog behavior included
 * - Producer-style processing ready
 *
 * Example:
 * ```cpp
 * HybridSampleAnalyzer analyzer;
 * analyzer.initialize(44100.0);
 *
 * // Analyze real 808 sample
 * auto sample = loadWAV("808_sample.wav");
 * auto model = analyzer.analyzeSample(sample);
 *
 * // Generate from model (with analog behavior!)
 * auto synth808 = model.synthesize();
 *
 * // Apply producer style
 * synth808.applyProducerStyle(ProducerStyle::Metro Boomin);
 * ```
 */

//==============================================================================
// Analysis Results
//==============================================================================

struct SpectralAnalysis
{
    std::vector<float> frequencies;     // Detected frequencies
    std::vector<float> amplitudes;      // Amplitudes per frequency
    std::vector<float> phases;          // Phases per frequency

    float fundamentalFreq = 0.0f;       // Main pitch
    std::vector<float> harmonics;       // Harmonic frequencies
    std::vector<float> harmonicAmps;    // Harmonic amplitudes

    float brightness = 0.0f;            // Spectral centroid
    float richness = 0.0f;              // Harmonic richness
    float inharmonicity = 0.0f;         // Inharmonic content
};

struct EnvelopeAnalysis
{
    float attack = 0.0f;                // Attack time (seconds)
    float decay = 0.0f;                 // Decay time
    float sustain = 1.0f;               // Sustain level (0-1)
    float release = 0.0f;               // Release time

    float peakAmplitude = 0.0f;         // Peak level
    float sustainAmplitude = 0.0f;      // Sustain level

    std::vector<float> envelope;        // Full envelope curve
};

struct TimbreAnalysis
{
    float warmth = 0.0f;                // Low-frequency content
    float brightness = 0.0f;            // High-frequency content
    float presence = 0.0f;              // Mid-frequency content

    float attack = 0.0f;                // Attack character
    float body = 0.0f;                  // Body fullness
    float tail = 0.0f;                  // Tail/decay character

    float analogCharacter = 0.0f;       // Analog-like qualities
    float digitalCharacter = 0.0f;      // Digital-like qualities
};

//==============================================================================
// Synthesis Model (created from analysis)
//==============================================================================

struct SynthesisModel
{
    juce::String name;
    juce::String category;              // "kick", "snare", "808", etc.

    // Spectral model
    SpectralAnalysis spectral;

    // Envelope model
    EnvelopeAnalysis envelope;

    // Timbre model
    TimbreAnalysis timbre;

    // Wavetable (generated from harmonics)
    std::vector<float> wavetable;       // 2048 samples

    // Original sample reference (optional)
    juce::AudioBuffer<float> originalSample;
    bool keepOriginal = false;

    // Metadata
    float originalPitch = 440.0f;
    double sampleRate = 44100.0;
    float duration = 1.0f;

    // Quality metrics
    float analysisQuality = 0.0f;       // 0-1 (how well we captured it)
    float compressionRatio = 0.0f;      // Size reduction vs. original
};

//==============================================================================
// Analog Behavior Parameters
//==============================================================================

struct AnalogBehavior
{
    // Tape Saturation
    struct Tape {
        float saturation = 0.5f;        // 0-1
        float warmth = 0.5f;            // Low-freq boost
        float hfRolloff = 0.3f;         // High-freq rolloff
        float flutter = 0.1f;           // Wow/flutter
        bool enabled = true;
    } tape;

    // Tube Warmth
    struct Tube {
        float drive = 0.5f;             // 0-1
        float bias = 0.5f;              // 0-1
        float asymmetry = 0.3f;         // Even/odd harmonics
        bool enabled = true;
    } tube;

    // Vintage Character
    struct Vintage {
        float noise = 0.1f;             // Background noise
        float drift = 0.05f;            // Pitch/timing drift
        float aging = 0.3f;             // Component aging
        bool enabled = true;
    } vintage;

    // Overall analog amount
    float analogAmount = 0.7f;          // 0=digital, 1=full analog
};

//==============================================================================
// Hybrid Sample Analyzer
//==============================================================================

class HybridSampleAnalyzer
{
public:
    HybridSampleAnalyzer();
    ~HybridSampleAnalyzer();

    //==============================================================================
    // Initialization
    //==============================================================================

    void initialize(double sampleRate);
    void setSampleRate(double sampleRate);

    //==============================================================================
    // Sample Analysis
    //==============================================================================

    /** Analyze a sample and create synthesis model */
    SynthesisModel analyzeSample(
        const juce::AudioBuffer<float>& sample,
        const juce::String& name = "Sample",
        bool keepOriginal = false
    );

    /** Analyze spectral content (FFT) */
    SpectralAnalysis analyzeSpectrum(const juce::AudioBuffer<float>& sample);

    /** Analyze envelope (ADSR) */
    EnvelopeAnalysis analyzeEnvelope(const juce::AudioBuffer<float>& sample);

    /** Analyze timbre characteristics */
    TimbreAnalysis analyzeTimbre(const juce::AudioBuffer<float>& sample);

    /** Detect fundamental pitch */
    float detectPitch(const juce::AudioBuffer<float>& sample);

    /** Extract harmonics */
    void extractHarmonics(
        const juce::AudioBuffer<float>& sample,
        float fundamentalFreq,
        std::vector<float>& harmonics,
        std::vector<float>& amplitudes
    );

    //==============================================================================
    // Model Creation
    //==============================================================================

    /** Create wavetable from harmonic analysis */
    std::vector<float> createWavetable(
        const SpectralAnalysis& spectral,
        int tableSize = 2048
    );

    /** Evaluate synthesis quality */
    float evaluateSynthesisQuality(
        const SynthesisModel& model,
        const juce::AudioBuffer<float>& original
    );

    //==============================================================================
    // Synthesis from Model
    //==============================================================================

    /** Synthesize audio from model */
    juce::AudioBuffer<float> synthesizeFromModel(
        const SynthesisModel& model,
        float pitch = 0.0f,                 // 0 = original pitch
        float duration = 0.0f,              // 0 = original duration
        const AnalogBehavior& analog = AnalogBehavior()
    );

    //==============================================================================
    // Batch Processing
    //==============================================================================

    /** Analyze multiple samples (e.g., from Google Drive folder) */
    std::vector<SynthesisModel> analyzeSampleLibrary(
        const juce::Array<juce::File>& sampleFiles,
        std::function<void(int, int)> progressCallback = nullptr
    );

    /** Select best samples based on quality metrics */
    std::vector<SynthesisModel> selectBestSamples(
        const std::vector<SynthesisModel>& models,
        int maxCount = 70
    );

    //==============================================================================
    // I/O
    //==============================================================================

    /** Save synthesis model to file */
    bool saveModel(const SynthesisModel& model, const juce::File& file);

    /** Load synthesis model from file */
    SynthesisModel loadModel(const juce::File& file);

    /** Save entire library */
    bool saveLibrary(
        const std::vector<SynthesisModel>& models,
        const juce::File& directory
    );

    //==============================================================================
    // Utilities
    //==============================================================================

    /** Get total size of synthesis model in bytes */
    size_t getModelSize(const SynthesisModel& model) const;

    /** Get compression ratio (model size vs. original sample) */
    float getCompressionRatio(const SynthesisModel& model) const;

private:
    //==============================================================================
    // DSP Helpers
    //==============================================================================

    // FFT
    void performFFT(
        const std::vector<float>& input,
        std::vector<std::complex<float>>& output
    );

    void performIFFT(
        const std::vector<std::complex<float>>& input,
        std::vector<float>& output
    );

    // Pitch detection (YIN algorithm)
    float detectPitchYIN(const std::vector<float>& samples);

    // Envelope followers
    std::vector<float> extractEnvelope(const juce::AudioBuffer<float>& sample);

    // Spectral features
    float computeSpectralCentroid(
        const std::vector<float>& spectrum,
        const std::vector<float>& frequencies
    );

    float computeSpectralRolloff(
        const std::vector<float>& spectrum,
        float threshold = 0.85f
    );

    // Harmonic analysis
    bool isHarmonic(float freq, float fundamental, float tolerance = 0.05f);

    //==============================================================================
    // State
    //==============================================================================

    double currentSampleRate = 44100.0;

    // FFT size
    static constexpr int fftSize = 4096;

    // Quality thresholds
    float minQualityThreshold = 0.6f;       // Minimum quality to keep

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(HybridSampleAnalyzer)
};

//==============================================================================
// Hybrid Synthesis Engine (uses models to generate audio)
//==============================================================================

class HybridSynthesisEngine
{
public:
    HybridSynthesisEngine();
    ~HybridSynthesisEngine();

    void initialize(double sampleRate);

    /** Load synthesis model library */
    void loadLibrary(const std::vector<SynthesisModel>& models);

    /** Get model by name */
    const SynthesisModel* getModel(const juce::String& name) const;

    /** Synthesize from model with analog behavior */
    juce::AudioBuffer<float> synthesize(
        const juce::String& modelName,
        float pitch = 440.0f,
        const AnalogBehavior& analog = AnalogBehavior()
    );

    /** Apply analog behavior to existing audio */
    void applyAnalogBehavior(
        juce::AudioBuffer<float>& audio,
        const AnalogBehavior& analog
    );

private:
    double currentSampleRate = 44100.0;
    std::map<juce::String, SynthesisModel> modelLibrary;

    // Analog behavior processors
    void applyTapeSaturation(
        juce::AudioBuffer<float>& audio,
        const AnalogBehavior::Tape& tape
    );

    void applyTubeWarmth(
        juce::AudioBuffer<float>& audio,
        const AnalogBehavior::Tube& tube
    );

    void applyVintageCharacter(
        juce::AudioBuffer<float>& audio,
        const AnalogBehavior::Vintage& vintage
    );

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(HybridSynthesisEngine)
};
