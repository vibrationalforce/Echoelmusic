#pragma once

#include <JuceHeader.h>
#include <vector>
#include <complex>
#include <array>
#include <cmath>

/**
 * SpectralFramework
 *
 * Advanced FFT-based spectral processing utilities for all spectral plugins.
 * Provides optimized spectral analysis, filtering, and manipulation tools.
 *
 * Features:
 * - Efficient FFT processing with configurable sizes
 * - Spectral magnitude/phase extraction
 * - Spectral filtering utilities
 * - Bark/ERB scale conversions
 * - Psychoacoustic weighting
 * - Zero-latency and look-ahead modes
 */
class SpectralFramework
{
public:
    //==========================================================================
    // FFT Configuration
    //==========================================================================

    enum class FFTSize
    {
        Size512 = 9,
        Size1024 = 10,
        Size2048 = 11,
        Size4096 = 12,
        Size8192 = 13,
        Size16384 = 14
    };

    enum class WindowType
    {
        Hann,
        Hamming,
        Blackman,
        BlackmanHarris,
        Rectangular
    };

    //==========================================================================
    // Spectral Data Container
    //==========================================================================

    struct SpectralData
    {
        std::vector<float> magnitude;           // Magnitude spectrum
        std::vector<float> phase;               // Phase spectrum
        std::vector<std::complex<float>> bins;  // Complex frequency bins
        int numBins = 0;

        void resize(int size)
        {
            magnitude.resize(size);
            phase.resize(size);
            bins.resize(size);
            numBins = size;
        }
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    SpectralFramework(FFTSize size = FFTSize::Size2048,
                      WindowType windowType = WindowType::Hann);
    ~SpectralFramework() = default;

    //==========================================================================
    // Configuration
    //==========================================================================

    void setFFTSize(FFTSize size);
    void setWindowType(WindowType type);
    void setOverlapFactor(float factor);  // 0.0-0.9 (0.75 recommended)

    int getFFTSize() const { return fftSize; }
    int getNumBins() const { return fftSize / 2 + 1; }
    int getHopSize() const { return hopSize; }

    //==========================================================================
    // Processing
    //==========================================================================

    /** Prepare for processing */
    void prepare(double sampleRate, int maxBlockSize);

    /** Reset all internal states */
    void reset();

    /** Perform forward FFT on time-domain data */
    void performForwardFFT(const float* timeDomain, SpectralData& output);

    /** Perform inverse FFT from spectral data */
    void performInverseFFT(const SpectralData& input, float* timeDomain);

    /** Extract magnitude and phase from complex spectrum */
    static void extractMagnitudePhase(const std::vector<std::complex<float>>& bins,
                                      std::vector<float>& magnitude,
                                      std::vector<float>& phase);

    /** Reconstruct complex spectrum from magnitude and phase */
    static void reconstructFromMagnitudePhase(const std::vector<float>& magnitude,
                                              const std::vector<float>& phase,
                                              std::vector<std::complex<float>>& bins);

    //==========================================================================
    // Frequency Utilities
    //==========================================================================

    /** Convert bin index to frequency (Hz) */
    float binToFrequency(int bin) const;

    /** Convert frequency (Hz) to bin index */
    int frequencyToBin(float frequency) const;

    /** Convert frequency to Bark scale (0-24) */
    static float frequencyToBark(float frequency);

    /** Convert Bark scale to frequency */
    static float barkToFrequency(float bark);

    /** Convert frequency to ERB (Equivalent Rectangular Bandwidth) */
    static float frequencyToERB(float frequency);

    /** Convert ERB to frequency */
    static float erbToFrequency(float erb);

    /** Get number of ERB bands in frequency range */
    static int getNumERBBands(float minFreq, float maxFreq);

    //==========================================================================
    // Spectral Filtering
    //==========================================================================

    /** Apply spectral gain to a frequency range */
    static void applySpectralGain(SpectralData& data,
                                   int startBin,
                                   int endBin,
                                   float gainDb);

    /** Apply smooth spectral gain curve */
    static void applySpectralGainCurve(SpectralData& data,
                                       const std::vector<float>& gainCurveDb);

    /** Apply spectral gate (frequency-selective) */
    static void applySpectralGate(SpectralData& data,
                                   float thresholdDb,
                                   float ratio);

    /** Smooth spectrum (moving average) */
    static void smoothSpectrum(std::vector<float>& spectrum,
                               int windowSize);

    //==========================================================================
    // Psychoacoustic Utilities
    //==========================================================================

    /** Get A-weighting for frequency (dB) */
    static float getAWeighting(float frequency);

    /** Get critical band number for frequency (0-24 Bark bands) */
    static int getCriticalBand(float frequency);

    /** Calculate masking threshold using psychoacoustic model */
    static std::vector<float> calculateMaskingThreshold(
        const std::vector<float>& magnitude,
        double sampleRate);

    /** Detect tonal vs. noisy components */
    static std::vector<float> detectTonalComponents(
        const std::vector<float>& magnitude,
        float tonalityThreshold = 0.5f);

    //==========================================================================
    // Advanced Analysis
    //==========================================================================

    /** Detect spectral peaks */
    struct SpectralPeak
    {
        int bin;
        float frequency;
        float magnitude;
        float phase;
    };

    std::vector<SpectralPeak> detectPeaks(const SpectralData& data,
                                          float minMagnitude = 0.01f,
                                          int minDistance = 3);

    /** Calculate spectral centroid (brightness) */
    static float calculateSpectralCentroid(const SpectralData& data,
                                           double sampleRate);

    /** Calculate spectral flatness (tonality measure) */
    static float calculateSpectralFlatness(const std::vector<float>& magnitude);

    /** Calculate spectral crest factor */
    static float calculateSpectralCrest(const std::vector<float>& magnitude);

    /** Calculate spectral rolloff (frequency below which X% of energy is) */
    static float calculateSpectralRolloff(const SpectralData& data,
                                          double sampleRate,
                                          float percentage = 0.85f);

private:
    //==========================================================================
    // FFT Engine
    //==========================================================================

    int fftOrder = 11;
    int fftSize = 2048;
    int hopSize = 512;
    float overlapFactor = 0.75f;

    std::unique_ptr<juce::dsp::FFT> forwardFFT;
    std::unique_ptr<juce::dsp::FFT> inverseFFT;
    std::unique_ptr<juce::dsp::WindowingFunction<float>> window;

    WindowType currentWindowType = WindowType::Hann;
    double currentSampleRate = 48000.0;

    //==========================================================================
    // Internal Buffers
    //==========================================================================

    std::vector<float> fftBuffer;
    std::vector<float> windowBuffer;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    void updateFFTEngine();
    void updateWindow();
    void applyWindow(float* data);

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (SpectralFramework)
};
