#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>
#include <memory>
#include <complex>

/**
 * AIMastering - Intelligent Mastering Engine
 *
 * Inspired by: iZotope Ozone 11, FabFilter Pro-L 2, Waves L3, Sonnox Oxford
 *
 * Features:
 * - AI-driven Master Assistant (target matching)
 * - Multiband dynamics with intelligent linking
 * - Spectral shaping with reference matching
 * - True peak limiting with lookahead
 * - Stereo imaging with frequency-dependent width
 * - Loudness metering (LUFS/True Peak)
 * - Dithering with noise shaping
 * - Mid/Side processing
 */
namespace Echoel::DSP
{

//==============================================================================
// Loudness Metering (EBU R128 / ITU-R BS.1770)
//==============================================================================

struct LoudnessMetrics
{
    float momentaryLUFS = -100.0f;      // 400ms window
    float shortTermLUFS = -100.0f;      // 3s window
    float integratedLUFS = -100.0f;     // Entire program
    float loudnessRange = 0.0f;         // LRA (dynamic range)
    float truePeakL = -100.0f;          // True peak (dBTP)
    float truePeakR = -100.0f;
    float maxTruePeak = -100.0f;
    float psr = 0.0f;                   // Peak-to-short-term ratio (crest factor)

    // Target compliance
    bool meetsStreamingTarget = false;  // -14 LUFS typical
    float targetDifference = 0.0f;      // dB from target
};

class LoudnessMeter
{
public:
    LoudnessMeter();

    void prepare(double sampleRate, int samplesPerBlock);
    void reset();

    /** Process stereo audio and update metrics */
    void process(const float* leftChannel, const float* rightChannel, int numSamples);

    /** Get current loudness metrics */
    LoudnessMetrics getMetrics() const { return metrics; }

    /** Set target loudness for compliance checking */
    void setTargetLUFS(float targetLUFS) { this->targetLUFS = targetLUFS; }

private:
    LoudnessMetrics metrics;
    double sampleRate = 48000.0;
    float targetLUFS = -14.0f;  // Spotify/YouTube standard

    // K-weighting filter state (high shelf + high pass)
    struct KWeightingFilter
    {
        std::array<double, 3> b1 = {0.0, 0.0, 0.0};  // Shelf coefficients
        std::array<double, 3> a1 = {0.0, 0.0, 0.0};
        std::array<double, 3> b2 = {0.0, 0.0, 0.0};  // HPF coefficients
        std::array<double, 3> a2 = {0.0, 0.0, 0.0};
        std::array<double, 2> z1L = {0.0, 0.0}, z1R = {0.0, 0.0};
        std::array<double, 2> z2L = {0.0, 0.0}, z2R = {0.0, 0.0};
    } kFilter;

    // Gated loudness integration
    std::vector<float> momentaryBuffer;
    std::vector<float> shortTermBuffer;
    std::vector<float> integratedBlocks;
    int momentaryWritePos = 0;
    int shortTermWritePos = 0;

    // True peak detection (4x oversampling)
    std::array<float, 4> oversampleBuffer;
    float truePeakMaxL = 0.0f, truePeakMaxR = 0.0f;

    void calculateKWeightingCoefficients();
    float applyKWeighting(float sampleL, float sampleR);
    float calculateTruePeak(const float* samples, int numSamples);
};

//==============================================================================
// Spectral Analysis
//==============================================================================

class SpectralAnalyzer
{
public:
    static constexpr int fftSize = 4096;
    static constexpr int numBands = 512;

    SpectralAnalyzer();

    void prepare(double sampleRate);
    void process(const float* samples, int numSamples);

    /** Get magnitude spectrum (0-1 normalized per band) */
    const std::array<float, numBands>& getMagnitudes() const { return magnitudes; }

    /** Get spectral centroid (brightness indicator) */
    float getSpectralCentroid() const { return spectralCentroid; }

    /** Get spectral flux (change rate) */
    float getSpectralFlux() const { return spectralFlux; }

    /** Get spectral rolloff (frequency below which X% energy) */
    float getSpectralRolloff(float percentage = 0.85f) const;

private:
    double sampleRate = 48000.0;
    std::array<float, fftSize> fftBuffer;
    std::array<float, fftSize> window;
    std::array<float, numBands> magnitudes;
    std::array<float, numBands> prevMagnitudes;

    float spectralCentroid = 0.0f;
    float spectralFlux = 0.0f;

    int writePos = 0;

    std::unique_ptr<juce::dsp::FFT> fft;

    void performFFT();
    void calculateFeatures();
};

//==============================================================================
// Reference Matching (AI Master Assistant)
//==============================================================================

struct ReferenceProfile
{
    juce::String name;

    // Spectral envelope (averaged frequency response)
    std::array<float, SpectralAnalyzer::numBands> spectralEnvelope;

    // Dynamics characteristics
    float averageLUFS = -14.0f;
    float dynamicRange = 8.0f;       // LRA
    float crestFactor = 12.0f;       // Peak to RMS ratio in dB

    // Stereo characteristics
    float stereoWidth = 0.7f;        // 0 = mono, 1 = full stereo
    float midSideBalance = 0.5f;     // 0 = all mid, 1 = all side

    // Frequency balance
    float lowEndWeight = 0.0f;       // dB relative to neutral
    float highEndWeight = 0.0f;
    float midRangeClarity = 0.0f;

    // Genre-based presets
    static ReferenceProfile createEDM();
    static ReferenceProfile createHipHop();
    static ReferenceProfile createPop();
    static ReferenceProfile createRock();
    static ReferenceProfile createClassical();
    static ReferenceProfile createVaporwave();
    static ReferenceProfile createLoFi();
};

class ReferenceAnalyzer
{
public:
    ReferenceAnalyzer();

    /** Analyze reference track and create profile */
    ReferenceProfile analyzeReference(const juce::AudioBuffer<float>& referenceAudio,
                                       double sampleRate);

    /** Learn from multiple references */
    ReferenceProfile learnFromReferences(const std::vector<juce::AudioBuffer<float>>& references,
                                          double sampleRate);

    /** Calculate difference between current mix and reference */
    struct MatchingCurve
    {
        std::array<float, SpectralAnalyzer::numBands> eqCurve;  // dB adjustment per band
        float gainAdjustment = 0.0f;                             // Overall gain change
        float widthAdjustment = 0.0f;                            // Stereo width change
        float compressionSuggestion = 0.0f;                      // Suggested compression ratio
    };

    MatchingCurve calculateMatchingCurve(const ReferenceProfile& reference,
                                          const ReferenceProfile& current);

private:
    SpectralAnalyzer analyzer;
    LoudnessMeter loudnessMeter;
};

//==============================================================================
// Multiband Dynamics
//==============================================================================

class MultibandDynamics
{
public:
    static constexpr int maxBands = 6;

    struct Band
    {
        float crossoverFreq = 1000.0f;  // Upper crossover frequency
        float threshold = -20.0f;        // dB
        float ratio = 4.0f;              // Compression ratio
        float attack = 10.0f;            // ms
        float release = 100.0f;          // ms
        float makeupGain = 0.0f;         // dB
        float knee = 6.0f;               // Soft knee width in dB
        bool enabled = true;
        bool solo = false;
        bool bypass = false;

        // Intelligent linking
        float sidechain = 0.0f;          // 0 = self, 1 = full-band
        float adaptiveRelease = 0.5f;    // 0 = fixed, 1 = fully adaptive
    };

    MultibandDynamics();

    void prepare(double sampleRate, int samplesPerBlock);
    void reset();

    void setNumBands(int numBands);
    void setBand(int bandIndex, const Band& band);
    Band& getBand(int bandIndex) { return bands[bandIndex]; }

    /** Process stereo audio with multiband compression */
    void process(float* leftChannel, float* rightChannel, int numSamples);

    /** Get current gain reduction per band (for metering) */
    std::array<float, maxBands> getGainReduction() const { return gainReduction; }

    /** Auto-threshold based on input level */
    void autoThreshold(float targetReduction = 6.0f);

private:
    int numBands = 4;
    std::array<Band, maxBands> bands;
    std::array<float, maxBands> gainReduction;

    double sampleRate = 48000.0;

    // Linkwitz-Riley crossover filters
    struct CrossoverFilter
    {
        std::array<float, 2> lpState = {0.0f, 0.0f};
        std::array<float, 2> hpState = {0.0f, 0.0f};
    };
    std::array<CrossoverFilter, maxBands - 1> crossoversL;
    std::array<CrossoverFilter, maxBands - 1> crossoversR;

    // Envelope followers per band
    std::array<float, maxBands> envelopeL;
    std::array<float, maxBands> envelopeR;

    // Adaptive release state
    std::array<float, maxBands> adaptiveReleaseState;

    void updateCrossoverCoefficients(int filterIndex, float frequency);
    float computeGain(float envelope, const Band& band);
};

//==============================================================================
// True Peak Limiter
//==============================================================================

class TruePeakLimiter
{
public:
    TruePeakLimiter();

    void prepare(double sampleRate, int samplesPerBlock);
    void reset();

    /** Set ceiling in dBTP */
    void setCeiling(float ceilingDbTP) { ceiling = ceilingDbTP; }

    /** Set release time in ms */
    void setRelease(float releaseMs) { release = releaseMs; }

    /** Set lookahead in ms (0-10ms) */
    void setLookahead(float lookaheadMs) { lookahead = juce::jlimit(0.0f, 10.0f, lookaheadMs); }

    /** Enable/disable true peak detection (vs sample peak) */
    void setTruePeakMode(bool enabled) { truePeakMode = enabled; }

    /** Process stereo audio with brick-wall limiting */
    void process(float* leftChannel, float* rightChannel, int numSamples);

    /** Get current gain reduction in dB */
    float getGainReduction() const { return currentGainReduction; }

    /** Get true peak value */
    float getTruePeak() const { return truePeak; }

private:
    double sampleRate = 48000.0;
    float ceiling = -0.3f;       // dBTP
    float release = 100.0f;      // ms
    float lookahead = 1.5f;      // ms
    bool truePeakMode = true;

    float currentGainReduction = 0.0f;
    float truePeak = -100.0f;

    // Lookahead delay buffer
    std::vector<float> delayBufferL, delayBufferR;
    int delayWritePos = 0;
    int delaySamples = 0;

    // Gain smoothing
    float targetGain = 1.0f;
    float currentGain = 1.0f;
    float attackCoeff = 0.0f;
    float releaseCoeff = 0.0f;

    // 4x oversampling for true peak
    static constexpr int oversampleFactor = 4;
    std::array<float, 4> oversampleCoeffs;

    float detectTruePeak(float s0, float s1);
};

//==============================================================================
// Stereo Imager
//==============================================================================

class StereoImager
{
public:
    struct Band
    {
        float lowFreq = 0.0f;
        float highFreq = 20000.0f;
        float width = 1.0f;       // 0 = mono, 1 = normal, 2 = extra wide
        float pan = 0.0f;         // -1 (left) to +1 (right)
        bool enabled = true;
    };

    static constexpr int maxBands = 4;

    StereoImager();

    void prepare(double sampleRate, int samplesPerBlock);
    void reset();

    void setNumBands(int numBands);
    void setBand(int bandIndex, const Band& band);

    /** Enable mid/side mode */
    void setMidSideMode(bool enabled) { midSideMode = enabled; }

    /** Set global stereo width */
    void setGlobalWidth(float width) { globalWidth = width; }

    /** Process stereo audio */
    void process(float* leftChannel, float* rightChannel, int numSamples);

    /** Get correlation coefficient (-1 to +1) */
    float getCorrelation() const { return correlation; }

    /** Get stereo balance */
    float getBalance() const { return balance; }

private:
    int numBands = 1;
    std::array<Band, maxBands> bands;

    double sampleRate = 48000.0;
    bool midSideMode = false;
    float globalWidth = 1.0f;

    float correlation = 1.0f;
    float balance = 0.0f;

    // Band-splitting filters
    struct BandFilter
    {
        std::array<float, 4> stateL = {0.0f, 0.0f, 0.0f, 0.0f};
        std::array<float, 4> stateR = {0.0f, 0.0f, 0.0f, 0.0f};
    };
    std::array<BandFilter, maxBands> bandFilters;

    // Correlation metering
    float correlationSum = 0.0f;
    float leftPowerSum = 0.0f;
    float rightPowerSum = 0.0f;
    int correlationSamples = 0;

    void updateCorrelation(float left, float right);
};

//==============================================================================
// Dithering & Noise Shaping
//==============================================================================

class Dithering
{
public:
    enum class Type
    {
        None,
        TPDF,              // Triangular probability density function
        HPF_TPDF,          // High-pass filtered TPDF
        NoiseShaping       // Shaped noise for psychoacoustic masking
    };

    enum class BitDepth
    {
        Bit16,
        Bit20,
        Bit24
    };

    Dithering();

    void prepare(double sampleRate);

    void setType(Type type) { this->type = type; }
    void setBitDepth(BitDepth depth) { this->bitDepth = depth; }

    /** Apply dithering to audio */
    void process(float* leftChannel, float* rightChannel, int numSamples);

private:
    Type type = Type::TPDF;
    BitDepth bitDepth = BitDepth::Bit16;
    double sampleRate = 48000.0;

    // TPDF random state
    uint32_t randomState = 12345;

    // Noise shaping filter state
    std::array<float, 9> errorBufferL = {};
    std::array<float, 9> errorBufferR = {};
    int errorPos = 0;

    // Noise shaping coefficients (POW-R style)
    static constexpr std::array<float, 9> noiseShapeCoeffs = {
        2.033f, -2.165f, 1.959f, -1.590f, 0.6149f,
        -0.2614f, 0.1473f, -0.0558f, 0.0168f
    };

    float generateTPDF();
    float applyNoiseShaping(float error, std::array<float, 9>& errorBuffer);
    float quantize(float sample, float ditherNoise);
};

//==============================================================================
// AI Mastering Engine (Main Class)
//==============================================================================

class AIMasteringEngine
{
public:
    AIMasteringEngine();
    ~AIMasteringEngine();

    void prepare(double sampleRate, int samplesPerBlock);
    void reset();

    //==========================================================================
    // Processing Chain
    //==========================================================================

    /** Process stereo audio through full mastering chain */
    void process(juce::AudioBuffer<float>& buffer);

    /** Set processing order */
    enum class Module { EQ, Dynamics, Imager, Limiter, Dither };
    void setProcessingOrder(const std::array<Module, 5>& order);

    //==========================================================================
    // Master Assistant (AI)
    //==========================================================================

    /** Analyze input and suggest mastering settings */
    struct MasteringSuggestions
    {
        // EQ suggestions
        std::array<float, SpectralAnalyzer::numBands> eqCurve;

        // Dynamics suggestions
        float compressionThreshold = -20.0f;
        float compressionRatio = 2.0f;
        float targetLoudness = -14.0f;

        // Imaging suggestions
        float stereoWidth = 1.0f;
        float lowEndMono = true;

        // Limiting
        float limiterCeiling = -1.0f;

        // Quality assessment
        float clarityScore = 0.0f;      // 0-100
        float balanceScore = 0.0f;
        float dynamicsScore = 0.0f;
        float overallScore = 0.0f;
    };

    /** Analyze and get AI suggestions */
    MasteringSuggestions analyzeAndSuggest(const juce::AudioBuffer<float>& inputAudio);

    /** Apply AI suggestions */
    void applySuggestions(const MasteringSuggestions& suggestions);

    /** Set reference profile for matching */
    void setReferenceProfile(const ReferenceProfile& profile);

    /** Learn from reference track */
    void learnFromReference(const juce::AudioBuffer<float>& referenceAudio);

    //==========================================================================
    // Individual Module Access
    //==========================================================================

    MultibandDynamics& getDynamics() { return dynamics; }
    TruePeakLimiter& getLimiter() { return limiter; }
    StereoImager& getImager() { return imager; }
    Dithering& getDithering() { return dithering; }
    LoudnessMeter& getLoudnessMeter() { return loudnessMeter; }
    SpectralAnalyzer& getAnalyzer() { return analyzer; }

    //==========================================================================
    // Metering
    //==========================================================================

    LoudnessMetrics getLoudnessMetrics() const { return loudnessMeter.getMetrics(); }

    /** Get spectral data for visualization */
    const std::array<float, SpectralAnalyzer::numBands>& getSpectrum() const
    {
        return analyzer.getMagnitudes();
    }

    //==========================================================================
    // EQ (Spectral Shaping)
    //==========================================================================

    struct EQBand
    {
        enum class Type { LowShelf, HighShelf, Peak, LowPass, HighPass };
        Type type = Type::Peak;
        float frequency = 1000.0f;
        float gain = 0.0f;           // dB
        float q = 1.0f;
        bool enabled = true;
    };

    static constexpr int maxEQBands = 8;
    void setEQBand(int index, const EQBand& band);
    EQBand& getEQBand(int index) { return eqBands[index]; }

    /** Apply matching EQ curve from reference analysis */
    void applyMatchingEQ(const std::array<float, SpectralAnalyzer::numBands>& curve);

    //==========================================================================
    // Presets
    //==========================================================================

    enum class Preset
    {
        Bypass,
        Transparent,        // Subtle enhancement
        Streaming,          // Optimized for -14 LUFS
        Loud,               // Maximum loudness
        Warm,               // Analog warmth
        Bright,             // Enhanced clarity
        Wide,               // Maximum stereo width
        Vaporwave,          // Lo-fi aesthetic
        EDM,                // Electronic dance music
        HipHop,             // Urban bass-heavy
        Podcast             // Voice-optimized
    };

    void loadPreset(Preset preset);

private:
    double sampleRate = 48000.0;
    int samplesPerBlock = 512;

    // Processing modules
    MultibandDynamics dynamics;
    TruePeakLimiter limiter;
    StereoImager imager;
    Dithering dithering;
    LoudnessMeter loudnessMeter;
    SpectralAnalyzer analyzer;
    ReferenceAnalyzer referenceAnalyzer;

    // EQ
    std::array<EQBand, maxEQBands> eqBands;
    struct EQFilterState
    {
        std::array<float, 2> stateL = {0.0f, 0.0f};
        std::array<float, 2> stateR = {0.0f, 0.0f};
        std::array<float, 5> coeffs = {0.0f, 0.0f, 0.0f, 0.0f, 0.0f};  // b0, b1, b2, a1, a2
    };
    std::array<EQFilterState, maxEQBands> eqFilters;

    // Reference matching
    ReferenceProfile currentReference;
    bool hasReference = false;

    // Processing order
    std::array<Module, 5> processingOrder = {
        Module::EQ, Module::Dynamics, Module::Imager, Module::Limiter, Module::Dither
    };

    // Internal methods
    void processEQ(float* leftChannel, float* rightChannel, int numSamples);
    void updateEQCoefficients(int bandIndex);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(AIMasteringEngine)
};

}  // namespace Echoel::DSP
