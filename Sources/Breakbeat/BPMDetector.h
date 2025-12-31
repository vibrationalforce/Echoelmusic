#pragma once

#include <JuceHeader.h>
#include <vector>
#include <array>
#include <complex>

/**
 * BPMDetector - Professional Beat Detection & Analysis
 *
 * Multi-algorithm BPM detection with high accuracy for various music genres.
 * Optimized for breakbeats, jungle, DnB, and electronic music.
 *
 * Features:
 * - Multi-band onset detection
 * - Autocorrelation BPM estimation
 * - Beat tracking with phase alignment
 * - Downbeat detection (bar alignment)
 * - Real-time and offline analysis
 * - Confidence scoring
 * - Tempo range constraints
 * - Double/half tempo resolution
 *
 * Inspired by: Ableton Warp, Serato BPM, Zplane Elastique
 */
class BPMDetector
{
public:
    //==========================================================================
    // Detection Result
    //==========================================================================

    struct BPMResult
    {
        float bpm = 0.0f;               // Detected BPM
        float confidence = 0.0f;        // 0.0 to 1.0 (detection confidence)
        float offset = 0.0f;            // Beat offset in samples (phase)
        int downbeatPosition = 0;       // Sample position of first downbeat
        float timeSignature = 4.0f;     // Detected time signature (4 = 4/4)

        // Alternative tempos (for double/half resolution)
        float halfTempo = 0.0f;
        float doubleTempo = 0.0f;

        // Beat grid
        std::vector<int> beatPositions;  // Sample positions of detected beats
        std::vector<float> beatStrengths; // Strength of each beat (for visualization)
    };

    //==========================================================================
    // Detection Mode
    //==========================================================================

    enum class DetectionMode
    {
        Fast,              // Quick detection (lower accuracy)
        Normal,            // Balanced speed/accuracy
        Accurate,          // High accuracy (slower)
        Realtime           // For live input
    };

    //==========================================================================
    // Genre Hint
    //==========================================================================

    enum class GenreHint
    {
        Auto,              // Automatic detection
        DnB,               // Drum & Bass (160-180 BPM typical)
        Jungle,            // Jungle (150-170 BPM typical)
        House,             // House (120-130 BPM typical)
        Techno,            // Techno (130-150 BPM typical)
        HipHop,            // Hip-Hop (85-115 BPM typical)
        Dubstep,           // Dubstep (70-75 / 140-150 BPM half-time)
        Breakbeat,         // Breakbeat (120-140 BPM typical)
        Ambient            // Ambient (variable, often slow)
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    BPMDetector();
    ~BPMDetector() = default;

    //==========================================================================
    // Offline Detection
    //==========================================================================

    /** Analyze audio buffer and detect BPM */
    BPMResult analyze(const juce::AudioBuffer<float>& buffer, double sampleRate);

    /** Analyze audio file */
    BPMResult analyzeFile(const juce::File& audioFile);

    //==========================================================================
    // Real-time Detection
    //==========================================================================

    /** Prepare for real-time detection */
    void prepare(double sampleRate, int blockSize);

    /** Process audio block (real-time) */
    void processBlock(const juce::AudioBuffer<float>& buffer);

    /** Get current BPM estimate (real-time) */
    float getCurrentBPM() const { return currentBPM; }

    /** Get current beat phase (0.0 to 1.0, for visualization) */
    float getBeatPhase() const { return beatPhase; }

    /** Check if currently on beat */
    bool isOnBeat() const { return onBeat; }

    /** Reset real-time state */
    void reset();

    //==========================================================================
    // Settings
    //==========================================================================

    /** Set detection mode */
    void setDetectionMode(DetectionMode mode);

    /** Set BPM range (for constrained detection) */
    void setBPMRange(float minBPM, float maxBPM);

    /** Set genre hint (improves accuracy) */
    void setGenreHint(GenreHint genre);

    /** Set analysis window size (samples) */
    void setWindowSize(int samples);

    /** Set onset detection sensitivity */
    void setSensitivity(float sensitivity);

    /** Enable/disable downbeat detection */
    void setDownbeatDetection(bool enabled);

    //==========================================================================
    // Beat Grid
    //==========================================================================

    /** Generate beat grid from BPM and offset */
    std::vector<int> generateBeatGrid(float bpm, int offsetSamples,
                                       int totalSamples, double sampleRate);

    /** Adjust beat grid phase */
    void adjustBeatGridPhase(BPMResult& result, int phaseSamples);

    /** Quantize position to beat grid */
    int quantizeToBeat(int samplePosition, const BPMResult& result);

    //==========================================================================
    // Tap Tempo
    //==========================================================================

    /** Record tap tempo input */
    void tap();

    /** Get tap tempo BPM */
    float getTapTempoBPM() const;

    /** Reset tap tempo */
    void resetTapTempo();

    //==========================================================================
    // Visualization Data
    //==========================================================================

    /** Get onset detection function */
    const std::vector<float>& getOnsetFunction() const { return onsetFunction; }

    /** Get tempo likelihood function */
    const std::vector<float>& getTempoLikelihood() const { return tempoLikelihood; }

    /** Get beat strength over time */
    const std::vector<float>& getBeatStrength() const { return beatStrength; }

private:
    //==========================================================================
    // Settings
    //==========================================================================

    DetectionMode detectionMode = DetectionMode::Normal;
    float minBPM = 60.0f;
    float maxBPM = 200.0f;
    GenreHint genreHint = GenreHint::Auto;
    int windowSize = 2048;
    float sensitivity = 0.5f;
    bool downbeatDetectionEnabled = true;

    double currentSampleRate = 48000.0;

    //==========================================================================
    // Real-time State
    //==========================================================================

    float currentBPM = 0.0f;
    float beatPhase = 0.0f;
    bool onBeat = false;

    // Onset detection state
    std::vector<float> previousSpectrum;
    float previousEnergy = 0.0f;

    // Beat tracking state
    std::vector<float> onsetBuffer;
    int onsetBufferPos = 0;
    static constexpr int onsetBufferSize = 8192;

    // Tempo estimation state
    float tempoEstimate = 0.0f;
    float tempoConfidence = 0.0f;

    //==========================================================================
    // Analysis Results (for visualization)
    //==========================================================================

    std::vector<float> onsetFunction;
    std::vector<float> tempoLikelihood;
    std::vector<float> beatStrength;

    //==========================================================================
    // Tap Tempo
    //==========================================================================

    std::vector<double> tapTimes;
    static constexpr int maxTaps = 8;

    //==========================================================================
    // FFT
    //==========================================================================

    static constexpr int fftOrder = 11;  // 2048 samples
    static constexpr int fftSize = 1 << fftOrder;
    juce::dsp::FFT fft{fftOrder};
    std::array<float, fftSize * 2> fftData;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    void computeOnsetFunction(const juce::AudioBuffer<float>& buffer, double sampleRate);
    float computeSpectralFlux(const float* spectrum);
    void computeAutocorrelation(const std::vector<float>& onsets,
                                 std::vector<float>& autocorr);
    void findTempoCandidates(const std::vector<float>& autocorr,
                              std::vector<std::pair<float, float>>& candidates,
                              double sampleRate);
    float selectBestTempo(const std::vector<std::pair<float, float>>& candidates);
    void detectBeats(const std::vector<float>& onsets, float bpm,
                     std::vector<int>& beats, double sampleRate);
    int detectDownbeat(const std::vector<int>& beats,
                       const juce::AudioBuffer<float>& buffer);
    float calculateConfidence(const std::vector<float>& onsets,
                               const std::vector<int>& beats);
    void applyGenreConstraints(float& bpm);

    // Band-pass filter for onset detection
    float bandPassFilter(float input, float lowCut, float highCut);

    // Filter state
    float bpZ1 = 0.0f, bpZ2 = 0.0f;

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(BPMDetector)
};
