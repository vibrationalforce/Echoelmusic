#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>
#include <complex>

/**
 * SpectralSculptor
 *
 * Professional spectral processing suite for audio repair and creative sound design.
 * Inspired by iZotope RX but evolved with AI-powered features and bio-reactive control.
 *
 * Features:
 * - Real-time spectral editing (FFT-based)
 * - AI-powered spectral denoiser
 * - Spectral gate (frequency-selective gating)
 * - Harmonic enhancer/suppressor
 * - Spectral morph (bio-reactive)
 * - De-click/de-crackle
 * - Spectral freeze
 * - Time-frequency domain filtering
 * - Zero-latency mode (optional)
 */
class SpectralSculptor
{
public:
    //==========================================================================
    // Processing Mode
    //==========================================================================

    enum class ProcessingMode
    {
        Denoise,            // AI-powered noise reduction
        SpectralGate,       // Frequency-selective gating
        HarmonicEnhance,    // Enhance harmonics
        HarmonicSuppress,   // Suppress harmonics
        DeClick,            // Remove clicks/pops
        SpectralFreeze,     // Freeze spectral content
        SpectralMorph,      // Bio-reactive morphing
        Restore             // Intelligent audio restoration
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    SpectralSculptor();
    ~SpectralSculptor() = default;

    //==========================================================================
    // Processing Mode
    //==========================================================================

    /** Set processing mode */
    void setProcessingMode(ProcessingMode mode);
    ProcessingMode getProcessingMode() const { return currentMode; }

    //==========================================================================
    // Parameters - Denoise
    //==========================================================================

    /** Set noise threshold (0.0 to 1.0) */
    void setNoiseThreshold(float threshold);

    /** Set noise reduction amount (0.0 to 1.0) */
    void setNoiseReduction(float amount);

    /** Learn noise profile from current audio */
    void learnNoiseProfile(const juce::AudioBuffer<float>& buffer);

    /** Clear learned noise profile */
    void clearNoiseProfile();

    //==========================================================================
    // Parameters - Spectral Gate
    //==========================================================================

    /** Set gate threshold in dB (-60 to 0) */
    void setGateThreshold(float thresholdDb);

    /** Set gate attack in ms (0.1 to 100) */
    void setGateAttack(float attackMs);

    /** Set gate release in ms (10 to 1000) */
    void setGateRelease(float releaseMs);

    //==========================================================================
    // Parameters - Harmonic Processing
    //==========================================================================

    /** Set harmonic amount (0.0 to 1.0) */
    void setHarmonicAmount(float amount);

    /** Set fundamental frequency in Hz (20 to 2000) */
    void setFundamentalFrequency(float freq);

    /** Set number of harmonics to process (1 to 16) */
    void setNumHarmonics(int num);

    //==========================================================================
    // Parameters - De-Click
    //==========================================================================

    /** Set de-click sensitivity (0.0 to 1.0) */
    void setDeClickSensitivity(float sensitivity);

    //==========================================================================
    // Parameters - Spectral Freeze
    //==========================================================================

    /** Enable/disable spectral freeze */
    void setFreezeEnabled(bool enabled);

    /** Capture current spectrum for freeze */
    void captureSpectrum();

    //==========================================================================
    // Parameters - Spectral Morph (Bio-Reactive)
    //==========================================================================

    /** Set morph amount (0.0 to 1.0) */
    void setMorphAmount(float amount);

    /** Set bio-data for reactive morphing (HRV: 0.0-1.0, Coherence: 0.0-1.0) */
    void setBioData(float hrv, float coherence);

    //==========================================================================
    // Common Parameters
    //==========================================================================

    /** Set dry/wet mix (0.0 to 1.0) */
    void setMix(float mixAmount);

    /** Set FFT size (512, 1024, 2048, 4096, 8192) */
    void setFFTSize(int size);

    /** Enable/disable zero-latency mode (disables look-ahead) */
    void setZeroLatencyMode(bool enabled);

    //==========================================================================
    // Processing
    //==========================================================================

    /** Prepare for processing */
    void prepare(double sampleRate, int maxBlockSize);

    /** Reset all states */
    void reset();

    /** Process audio buffer */
    void process(juce::AudioBuffer<float>& buffer);

    //==========================================================================
    // Visualization
    //==========================================================================

    /** Get spectral data for visualization (1024 bins, normalized 0.0-1.0) */
    std::vector<float> getSpectrumData() const;

    /** Get noise profile data (1024 bins, normalized 0.0-1.0) */
    std::vector<float> getNoiseProfileData() const;

private:
    //==========================================================================
    // FFT Configuration
    //==========================================================================

    static constexpr int defaultFFTOrder = 11;  // 2048 samples
    int fftOrder = defaultFFTOrder;
    int fftSize = 1 << fftOrder;
    int hopSize = fftSize / 4;  // 75% overlap

    juce::dsp::FFT forwardFFT {fftOrder};
    juce::dsp::FFT inverseFFT {fftOrder};
    juce::dsp::WindowingFunction<float> window {fftSize, juce::dsp::WindowingFunction<float>::hann};

    //==============================================================================
    // Processing Buffers
    //==============================================================================

    struct ChannelState
    {
        std::vector<float> inputFIFO;
        std::vector<float> outputFIFO;
        std::vector<float> fftData;            // Time domain
        std::vector<std::complex<float>> freqData;  // Frequency domain
        std::vector<std::complex<float>> frozenSpectrum;  // For spectral freeze
        int inputFIFOIndex = 0;
        int outputFIFOIndex = 0;
    };

    std::array<ChannelState, 2> channelStates;

    // ✅ Pre-allocated dry buffer (no allocation in audio thread)
    juce::AudioBuffer<float> dryBuffer;

    //==========================================================================
    // Noise Profile (for denoising)
    //==========================================================================

    std::vector<float> noiseProfile;  // Magnitude spectrum of noise
    bool noiseProfileLearned = false;
    int noiseLearnFrames = 0;
    static constexpr int numNoiseLearnFrames = 10;

    //==========================================================================
    // Parameters
    //==========================================================================

    ProcessingMode currentMode = ProcessingMode::Denoise;
    double currentSampleRate = 48000.0;

    // Denoise
    float noiseThreshold = 0.5f;
    float noiseReduction = 0.8f;

    // Spectral Gate
    float gateThresholdDb = -40.0f;
    float gateAttackMs = 10.0f;
    float gateReleaseMs = 100.0f;
    std::vector<float> gateEnvelopes;  // Per frequency bin

    // Harmonic Processing
    float harmonicAmount = 0.5f;
    float fundamentalFreq = 100.0f;
    int numHarmonics = 8;

    // De-Click
    float deClickSensitivity = 0.5f;
    std::array<float, 2> previousSamples {{0.0f, 0.0f}};

    // Spectral Freeze
    bool freezeEnabled = false;

    // Spectral Morph (Bio-Reactive)
    float morphAmount = 0.5f;
    float bioHRV = 0.5f;
    float bioCoherence = 0.5f;

    // Common
    float mix = 1.0f;
    bool zeroLatency = false;

    // Visualization (lock-free communication between audio and UI threads)
    static constexpr int visualFifoSize = 2;
    juce::AbstractFifo visualSpectrumFifo { visualFifoSize };
    juce::AbstractFifo visualNoiseProfileFifo { visualFifoSize };

    // Double-buffered visualization data
    std::array<std::vector<float>, visualFifoSize> visualSpectrumBuffers;
    std::array<std::vector<float>, visualFifoSize> visualNoiseProfileBuffers;

    // UI thread reads from these (no locks needed)
    std::vector<float> visualSpectrum;
    std::vector<float> visualNoiseProfile;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    void processFrame(ChannelState& state);

    // Processing modes
    void processDenoise(std::vector<std::complex<float>>& freqData);
    void processSpectralGate(std::vector<std::complex<float>>& freqData);
    void processHarmonicEnhance(std::vector<std::complex<float>>& freqData);
    void processHarmonicSuppress(std::vector<std::complex<float>>& freqData);
    void processDeClick(juce::AudioBuffer<float>& buffer);
    void processSpectralFreeze(std::vector<std::complex<float>>& freqData);
    void processSpectralMorph(std::vector<std::complex<float>>& freqData);
    void processRestore(std::vector<std::complex<float>>& freqData);

    // Utilities
    void updateFFTSize();
    void updateGateEnvelopes();
    float binToFrequency(int bin) const;
    int frequencyToBin(float freq) const;
    void updateVisualization(const std::vector<std::complex<float>>& freqData);

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (SpectralSculptor)
};
