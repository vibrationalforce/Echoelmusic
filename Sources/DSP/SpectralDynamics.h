#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>
#include <complex>
#include <memory>

/**
 * SpectralDynamics - Frequency-Selective Dynamic Processing
 *
 * Inspired by: FabFilter Pro-Q 4, Oeksound Soothe2, Sonible smart:EQ
 *
 * Features:
 * - Per-band dynamic EQ with compression/expansion
 * - Spectral compression (multiband in frequency domain)
 * - Resonance suppression (de-essing, harsh frequency taming)
 * - Spectral gate (remove background noise per frequency)
 * - Dynamic matching EQ (match spectral profile dynamically)
 * - Full linear-phase option
 * - Mid/Side spectral processing
 */
namespace Echoel::DSP
{

//==============================================================================
// FFT Processing Core
//==============================================================================

class SpectralProcessor
{
public:
    static constexpr int fftSize = 4096;
    static constexpr int hopSize = fftSize / 4;  // 75% overlap
    static constexpr int numBins = fftSize / 2 + 1;

    SpectralProcessor();
    ~SpectralProcessor();

    void prepare(double sampleRate, int samplesPerBlock);
    void reset();

    /** Process audio through spectral domain */
    void process(float* leftChannel, float* rightChannel, int numSamples);

    /** Set processing callback for frequency domain manipulation */
    using SpectralCallback = std::function<void(
        std::array<std::complex<float>, numBins>& spectrumL,
        std::array<std::complex<float>, numBins>& spectrumR,
        double sampleRate
    )>;

    void setSpectralCallback(SpectralCallback callback) { spectralProcess = callback; }

    /** Enable linear phase mode (adds latency) */
    void setLinearPhase(bool enabled) { linearPhase = enabled; }

    /** Get current latency in samples */
    int getLatency() const { return linearPhase ? fftSize : hopSize; }

protected:
    double sampleRate = 48000.0;
    bool linearPhase = false;

    // FFT
    std::unique_ptr<juce::dsp::FFT> fft;

    // Analysis window (Hann)
    std::array<float, fftSize> window;
    std::array<float, fftSize> synthesisWindow;

    // Input/output buffers with overlap-add
    std::array<float, fftSize * 2> inputBufferL, inputBufferR;
    std::array<float, fftSize * 2> outputBufferL, outputBufferR;
    int inputWritePos = 0;
    int outputReadPos = 0;
    int samplesUntilNextFFT = 0;

    // FFT work buffers
    std::array<float, fftSize * 2> fftBufferL, fftBufferR;
    std::array<std::complex<float>, numBins> spectrumL, spectrumR;

    SpectralCallback spectralProcess;

    void performFFT();
    void performIFFT();
    void applyWindow(float* buffer);
    void applySynthesisWindow(float* buffer);
};

//==============================================================================
// Dynamic EQ Band
//==============================================================================

struct DynamicEQBand
{
    enum class Type
    {
        Bell,           // Parametric peak
        LowShelf,       // Low shelf
        HighShelf,      // High shelf
        LowPass,        // Low pass filter
        HighPass,       // High pass filter
        Notch,          // Notch/band reject
        BandPass        // Band pass
    };

    Type type = Type::Bell;
    float frequency = 1000.0f;       // Hz
    float gain = 0.0f;               // Static gain in dB
    float q = 1.0f;                  // Q factor (0.1 to 30)

    // Dynamic processing
    bool dynamicEnabled = false;
    float threshold = -30.0f;        // dB (level where dynamics start)
    float range = 12.0f;             // dB (maximum dynamic gain change)
    float attack = 10.0f;            // ms
    float release = 100.0f;          // ms
    float ratio = 2.0f;              // Compression ratio (1:1 to infinity)
    bool expand = false;             // true = expand below threshold

    // Sidechain
    bool sidechainExternal = false;
    bool sidechainMidSide = false;   // true = mid, false = side (when M/S mode)
    float sidechainHPF = 20.0f;      // Sidechain high pass filter
    float sidechainLPF = 20000.0f;   // Sidechain low pass filter

    bool enabled = true;
    bool solo = false;

    // Runtime state
    float currentGain = 0.0f;
    float envelope = 0.0f;
};

//==============================================================================
// Dynamic EQ Processor
//==============================================================================

class DynamicEQ
{
public:
    static constexpr int maxBands = 24;

    DynamicEQ();
    ~DynamicEQ();

    void prepare(double sampleRate, int samplesPerBlock);
    void reset();

    /** Process stereo audio */
    void process(float* leftChannel, float* rightChannel, int numSamples);

    /** Band management */
    int addBand(const DynamicEQBand& band);
    void removeBand(int index);
    void setBand(int index, const DynamicEQBand& band);
    DynamicEQBand& getBand(int index) { return bands[index]; }
    int getNumBands() const { return numBands; }

    /** Global settings */
    void setMidSideMode(bool enabled) { midSideMode = enabled; }
    void setAutoGain(bool enabled) { autoGain = enabled; }
    void setLinearPhase(bool enabled) { linearPhase = enabled; }

    /** Get EQ curve for visualization (dB at each frequency) */
    void getFrequencyResponse(float* magnitudes, const float* frequencies, int numPoints);

    /** Get dynamic gain reduction per band (for metering) */
    std::array<float, maxBands> getGainReduction() const;

private:
    double sampleRate = 48000.0;
    int numBands = 0;
    std::array<DynamicEQBand, maxBands> bands;

    bool midSideMode = false;
    bool autoGain = false;
    bool linearPhase = false;

    // Biquad filter states per band (2 stages for steeper response)
    struct FilterState
    {
        std::array<float, 2> z1L = {0.0f, 0.0f};
        std::array<float, 2> z2L = {0.0f, 0.0f};
        std::array<float, 2> z1R = {0.0f, 0.0f};
        std::array<float, 2> z2R = {0.0f, 0.0f};
    };
    std::array<FilterState, maxBands> filterStates;

    // Filter coefficients (b0, b1, b2, a1, a2) per band
    std::array<std::array<float, 5>, maxBands> filterCoeffs;

    // Sidechain filter states
    std::array<FilterState, maxBands> sidechainFilters;

    // Envelope followers
    std::array<float, maxBands> envelopes;

    void updateFilterCoefficients(int bandIndex);
    float processBand(int bandIndex, float sample, FilterState& state);
    float computeDynamicGain(int bandIndex, float sidechain);
};

//==============================================================================
// Spectral Dynamics (Per-Bin Processing)
//==============================================================================

class SpectralDynamicsProcessor : public SpectralProcessor
{
public:
    SpectralDynamicsProcessor();

    void prepare(double sampleRate, int samplesPerBlock);

    //==========================================================================
    // Spectral Compression
    //==========================================================================

    struct SpectralCompression
    {
        bool enabled = false;
        float threshold = -40.0f;     // dB per bin
        float ratio = 4.0f;           // Compression ratio
        float attack = 5.0f;          // ms (per-bin envelope)
        float release = 50.0f;        // ms
        float depth = 1.0f;           // 0-1 processing amount

        // Frequency range
        float lowFreq = 20.0f;
        float highFreq = 20000.0f;

        // Selectivity
        float selectivity = 0.5f;     // 0 = uniform, 1 = only peaks
        bool adaptiveThreshold = true; // Threshold follows overall level
    };

    void setSpectralCompression(const SpectralCompression& comp);
    SpectralCompression& getSpectralCompression() { return spectralComp; }

    //==========================================================================
    // Resonance Suppression (Soothe-style)
    //==========================================================================

    struct ResonanceSuppression
    {
        bool enabled = false;
        float depth = 3.0f;           // dB maximum reduction
        float sharpness = 0.5f;       // 0 = wide bands, 1 = narrow surgical
        float speed = 0.5f;           // Attack/release speed (0=slow, 1=fast)

        // Focus regions
        bool suppressSibilance = true;   // 4-10kHz
        bool suppressHarshness = true;   // 2-6kHz
        bool suppressMuddiness = false;  // 200-500Hz
        bool suppressRumble = false;     // 20-80Hz

        // Delta (difference) mode for subtle adjustment
        bool deltaMode = false;
        float mix = 1.0f;             // Wet/dry
    };

    void setResonanceSuppression(const ResonanceSuppression& supp);
    ResonanceSuppression& getResonanceSuppression() { return resonanceSupp; }

    //==========================================================================
    // Spectral Gate
    //==========================================================================

    struct SpectralGate
    {
        bool enabled = false;
        float threshold = -60.0f;     // dB (bins below this are attenuated)
        float range = 40.0f;          // dB reduction when gated
        float attack = 1.0f;          // ms
        float release = 20.0f;        // ms

        // Frequency-dependent threshold
        bool adaptiveThreshold = true;
        float lowFreqOffset = 6.0f;   // dB (bass needs higher threshold)
        float highFreqOffset = 0.0f;  // dB

        // Smoothing
        float smoothing = 0.5f;       // Spectral smoothing amount
    };

    void setSpectralGate(const SpectralGate& gate);
    SpectralGate& getSpectralGate() { return spectralGate; }

    //==========================================================================
    // Spectral Matching
    //==========================================================================

    struct SpectralMatching
    {
        bool enabled = false;
        float strength = 0.5f;        // 0-1 matching intensity
        float smoothing = 0.3f;       // Curve smoothing

        // Dynamic matching
        bool dynamic = true;          // Match dynamically vs static
        float dynamicSpeed = 0.5f;    // How fast to adapt
    };

    /** Set target spectrum for matching */
    void setTargetSpectrum(const std::array<float, numBins>& target);

    void setSpectralMatching(const SpectralMatching& match);
    SpectralMatching& getSpectralMatching() { return spectralMatch; }

    //==========================================================================
    // Mid/Side Processing
    //==========================================================================

    void setMidSideMode(bool enabled) { midSideMode = enabled; }

    /** Process only mid or side */
    enum class MSProcessing { Both, MidOnly, SideOnly };
    void setMSProcessing(MSProcessing mode) { msProcessing = mode; }

    //==========================================================================
    // Visualization
    //==========================================================================

    /** Get current spectrum for display (magnitude per bin) */
    const std::array<float, numBins>& getInputSpectrum() const { return inputMagnitudes; }

    /** Get gain reduction per bin */
    const std::array<float, numBins>& getGainReduction() const { return gainReductionPerBin; }

    /** Get delta (difference) spectrum */
    const std::array<float, numBins>& getDeltaSpectrum() const { return deltaMagnitudes; }

private:
    // Processing modules
    SpectralCompression spectralComp;
    ResonanceSuppression resonanceSupp;
    SpectralGate spectralGate;
    SpectralMatching spectralMatch;

    bool midSideMode = false;
    MSProcessing msProcessing = MSProcessing::Both;

    // Target spectrum for matching
    std::array<float, numBins> targetSpectrum;
    bool hasTarget = false;

    // Per-bin envelope followers
    std::array<float, numBins> binEnvelopes;
    std::array<float, numBins> gateEnvelopes;

    // Visualization data
    std::array<float, numBins> inputMagnitudes;
    std::array<float, numBins> gainReductionPerBin;
    std::array<float, numBins> deltaMagnitudes;

    // Smoothed gains for gentle processing
    std::array<float, numBins> smoothedGains;

    // Internal processing
    void processSpectrum(std::array<std::complex<float>, numBins>& spectrumL,
                         std::array<std::complex<float>, numBins>& spectrumR);

    void applySpectralCompression(std::array<float, numBins>& magnitudes);
    void applyResonanceSuppression(std::array<float, numBins>& magnitudes);
    void applySpectralGate(std::array<float, numBins>& magnitudes);
    void applySpectralMatching(std::array<float, numBins>& magnitudes);

    float binToFrequency(int bin) const;
    int frequencyToBin(float freq) const;
};

//==============================================================================
// EQ Sketch (Draw EQ curve with gesture)
//==============================================================================

class EQSketch
{
public:
    EQSketch();

    /** Convert drawn path to parametric EQ bands */
    std::vector<DynamicEQBand> sketchToEQ(const juce::Path& drawnPath,
                                           juce::Rectangle<float> bounds,
                                           float minFreq = 20.0f,
                                           float maxFreq = 20000.0f,
                                           float minDB = -24.0f,
                                           float maxDB = 24.0f);

    /** Simplify path to minimal number of bands */
    std::vector<DynamicEQBand> optimizeBands(const std::vector<DynamicEQBand>& bands,
                                              int maxBands = 8,
                                              float tolerance = 0.5f);

    /** Smooth the drawn curve */
    juce::Path smoothPath(const juce::Path& roughPath, float smoothing = 0.5f);

private:
    struct CurvePoint
    {
        float frequency;
        float gainDB;
    };

    std::vector<CurvePoint> pathToPoints(const juce::Path& path,
                                          juce::Rectangle<float> bounds,
                                          float minFreq, float maxFreq,
                                          float minDB, float maxDB);

    DynamicEQBand fitBandToSegment(const std::vector<CurvePoint>& points,
                                    int startIdx, int endIdx);
};

//==============================================================================
// Spectral Analyzer with Psychoacoustic Weighting
//==============================================================================

class PsychoacousticAnalyzer
{
public:
    static constexpr int numBands = 32;  // Bark scale bands

    PsychoacousticAnalyzer();

    void prepare(double sampleRate, int samplesPerBlock);

    /** Process and get perceptual loudness per Bark band */
    void process(const float* samples, int numSamples);

    /** Get loudness in sones per band */
    const std::array<float, numBands>& getLoudness() const { return loudnessPerBand; }

    /** Get sharpness (Zwicker) */
    float getSharpness() const { return sharpness; }

    /** Get roughness */
    float getRoughness() const { return roughness; }

    /** Get fluctuation strength */
    float getFluctuationStrength() const { return fluctuationStrength; }

    /** Get overall perceived loudness (sones) */
    float getTotalLoudness() const { return totalLoudness; }

private:
    double sampleRate = 48000.0;

    std::array<float, numBands> loudnessPerBand;
    float sharpness = 0.0f;
    float roughness = 0.0f;
    float fluctuationStrength = 0.0f;
    float totalLoudness = 0.0f;

    // Bark band edges (in Hz)
    static const std::array<float, numBands + 1> barkEdges;

    // Critical band filters
    struct BarkBandFilter
    {
        std::array<float, 4> state = {0.0f, 0.0f, 0.0f, 0.0f};
        std::array<float, 5> coeffs = {0.0f, 0.0f, 0.0f, 0.0f, 0.0f};
    };
    std::array<BarkBandFilter, numBands> barkFilters;

    // Equal loudness contour (ISO 226:2003)
    std::array<float, numBands> equalLoudnessWeights;

    void initializeBarkFilters();
    void calculateEqualLoudnessWeights();
    float excitationToLoudness(float excitation, int band);
};

}  // namespace Echoel::DSP
