#pragma once

#include "QuantumFrequencyScience.h"
#include <JuceHeader.h>
#include <array>
#include <vector>
#include <complex>
#include <memory>

/**
 * PhysicallyCorrectAnalyzer - Scientific Spectrum Analysis
 *
 * Features:
 * - Multiple tuning reference options (432 Hz, 440 Hz, Scientific C=256 Hz)
 * - Cousto planetary frequency detection
 * - Solfeggio frequency detection
 * - Brainwave band analysis
 * - Schumann resonance correlation
 * - Harmonic series analysis
 * - Cymatics pattern generation
 * - Just intonation vs equal temperament display
 * - Golden ratio point detection
 * - Chakra frequency mapping
 */
namespace Echoel::DSP
{

//==============================================================================
// Spectrum Analyzer Core
//==============================================================================

class PhysicallyCorrectAnalyzer
{
public:
    static constexpr int fftSize = 8192;
    static constexpr int numBins = fftSize / 2 + 1;

    PhysicallyCorrectAnalyzer();
    ~PhysicallyCorrectAnalyzer();

    void prepare(double sampleRate, int samplesPerBlock);
    void reset();

    /** Process audio and update analysis */
    void processBlock(const float* samples, int numSamples);

    //==========================================================================
    // Reference Pitch Configuration
    //==========================================================================

    enum class ReferencePitch
    {
        A440,           // Modern standard (A4 = 440 Hz)
        A432,           // Natural/Verdi tuning (A4 = 432 Hz)
        Scientific,     // C4 = 256 Hz (2⁸ Hz)
        A415Baroque,    // Baroque pitch
        A435French      // 1859 French standard
    };

    void setReferencePitch(ReferencePitch pitch);
    ReferencePitch getReferencePitch() const { return refPitch; }
    double getReferenceA4() const;

    //==========================================================================
    // Tuning System Display
    //==========================================================================

    void setTuningSystem(TuningSystem::Type tuning);
    TuningSystem::Type getTuningSystem() const { return tuningSystem; }

    //==========================================================================
    // Spectrum Data Access
    //==========================================================================

    /** Get raw magnitude spectrum (linear) */
    const std::array<float, numBins>& getMagnitudeSpectrum() const { return magnitude; }

    /** Get dB spectrum (-infinity to 0 dB) */
    const std::array<float, numBins>& getDBSpectrum() const { return magnitudeDB; }

    /** Get phase spectrum */
    const std::array<float, numBins>& getPhaseSpectrum() const { return phase; }

    /** Convert bin index to frequency */
    double binToFrequency(int bin) const;

    /** Convert frequency to bin index */
    int frequencyToBin(double freq) const;

    //==========================================================================
    // Pitch Detection
    //==========================================================================

    struct PitchInfo
    {
        double frequencyHz = 0.0;
        double confidence = 0.0;        // 0-1

        // Equal temperament mapping
        int midiNote = 0;
        juce::String noteName;
        int octave = 0;
        double centsDeviation = 0.0;    // Cents from ET

        // Alternative tunings
        double pythagoreanCents = 0.0;
        double justIntonationCents = 0.0;

        // Nearest special frequencies
        bool nearSolfeggio = false;
        SolfeggioFrequencies::SolfeggioTone nearestSolfeggio;

        bool nearPlanetary = false;
        juce::String nearestPlanet;

        bool nearSchumann = false;
        int schumannHarmonic = 0;
    };

    PitchInfo getPitchInfo() const { return pitchInfo; }

    //==========================================================================
    // Harmonic Analysis
    //==========================================================================

    struct HarmonicAnalysis
    {
        double fundamental = 0.0;
        std::vector<HarmonicSeries::Harmonic> harmonics;

        // Harmonic content ratios
        double oddHarmonicRatio = 0.0;   // Square wave characteristic
        double evenHarmonicRatio = 0.0;  // Sawtooth characteristic

        // Inharmonicity measure (deviation from integer ratios)
        double inharmonicity = 0.0;

        // Spectral centroid
        double spectralCentroid = 0.0;
    };

    HarmonicAnalysis getHarmonicAnalysis() const { return harmonicAnalysis; }

    //==========================================================================
    // Brainwave Band Energy
    //==========================================================================

    struct BrainwaveBands
    {
        float delta = 0.0f;     // 0.5-4 Hz
        float theta = 0.0f;     // 4-8 Hz
        float alpha = 0.0f;     // 8-13 Hz
        float beta = 0.0f;      // 13-30 Hz
        float gamma = 0.0f;     // 30-100 Hz

        // Dominant band
        BrainwaveFrequencies::Band dominant = BrainwaveFrequencies::Band::Alpha;

        // Schumann resonance correlation
        float schumannCorrelation = 0.0f;
    };

    BrainwaveBands getBrainwaveBands() const { return brainwaveBands; }

    //==========================================================================
    // Planetary Frequency Detection
    //==========================================================================

    struct PlanetaryResonance
    {
        struct Detection
        {
            juce::String planet;
            double frequency = 0.0;
            double magnitude = 0.0;       // 0-1
            double deviation = 0.0;       // Hz from exact
            bool present = false;
        };

        std::vector<Detection> detections;
        juce::String dominantPlanet;
        double dominantMagnitude = 0.0;
    };

    PlanetaryResonance getPlanetaryResonance() const { return planetaryResonance; }

    //==========================================================================
    // Solfeggio Detection
    //==========================================================================

    struct SolfeggioDetection
    {
        struct TonePresence
        {
            SolfeggioFrequencies::SolfeggioTone tone;
            float magnitude = 0.0f;
            bool present = false;
        };

        std::array<TonePresence, 9> tones;
        int dominantToneIndex = -1;
    };

    SolfeggioDetection getSolfeggioDetection() const { return solfeggioDetection; }

    //==========================================================================
    // Chakra Frequency Mapping
    //==========================================================================

    struct ChakraAnalysis
    {
        struct Chakra
        {
            juce::String name;
            juce::String sanskritName;
            double frequencyHz;
            juce::Colour colour;
            float energy = 0.0f;        // 0-1 magnitude at frequency
        };

        std::array<Chakra, 7> chakras;
        int dominantChakra = -1;
        float overallBalance = 0.0f;    // How balanced across all chakras
    };

    ChakraAnalysis getChakraAnalysis() const { return chakraAnalysis; }

    //==========================================================================
    // Golden Ratio Analysis
    //==========================================================================

    struct GoldenRatioAnalysis
    {
        // Frequencies at golden ratio intervals from detected fundamental
        std::vector<double> goldenFrequencies;

        // Energy at golden ratio points
        std::vector<float> goldenMagnitudes;

        // Overall "golden harmony" score
        float goldenHarmonyScore = 0.0f;
    };

    GoldenRatioAnalysis getGoldenRatioAnalysis() const { return goldenRatioAnalysis; }

    //==========================================================================
    // Cymatics Pattern Visualization
    //==========================================================================

    /**
     * Generate Chladni pattern for detected frequency
     * Returns normalized pattern values (0-1) on a 2D grid
     */
    struct CymaticsPattern
    {
        double frequencyHz = 0.0;
        int resolution = 64;
        std::vector<float> pattern;     // resolution × resolution grid

        // Chladni parameters
        float m = 1.0f, n = 2.0f;       // Mode numbers
    };

    CymaticsPattern generateCymaticsPattern(int resolution = 64) const;

    //==========================================================================
    // Tuning Comparison Display
    //==========================================================================

    struct TuningComparison
    {
        int midiNote = 0;
        juce::String noteName;

        double equalTemperament = 0.0;
        double pythagorean = 0.0;
        double justIntonation = 0.0;
        double scientific = 0.0;

        double etCents = 0.0;           // Reference
        double pythCents = 0.0;         // Difference from ET
        double jiCents = 0.0;
        double sciCents = 0.0;
    };

    TuningComparison getTuningComparison(int midiNote) const;

    //==========================================================================
    // Scientific Metering
    //==========================================================================

    struct ScientificMeters
    {
        // Energy in different frequency regions
        float infrasonicEnergy = 0.0f;  // < 20 Hz
        float subBassEnergy = 0.0f;     // 20-60 Hz
        float bassEnergy = 0.0f;        // 60-250 Hz
        float lowMidEnergy = 0.0f;      // 250-500 Hz
        float midEnergy = 0.0f;         // 500-2000 Hz
        float highMidEnergy = 0.0f;     // 2000-4000 Hz
        float presenceEnergy = 0.0f;    // 4000-6000 Hz
        float brillianceEnergy = 0.0f;  // 6000-20000 Hz
        float ultrasonicEnergy = 0.0f;  // > 20000 Hz

        // Spectral characteristics
        float spectralCentroid = 0.0f;  // Hz - brightness indicator
        float spectralSpread = 0.0f;    // Bandwidth
        float spectralRolloff = 0.0f;   // 85% energy point
        float spectralFlux = 0.0f;      // Rate of change
        float spectralFlatness = 0.0f;  // Tonality (0=tonal, 1=noise)

        // Crest factor
        float peakToDB = 0.0f;
        float rmsToDB = 0.0f;
        float crestFactor = 0.0f;       // dB (peak - RMS)
    };

    ScientificMeters getScientificMeters() const { return scientificMeters; }

private:
    double sampleRate = 48000.0;
    ReferencePitch refPitch = ReferencePitch::A440;
    TuningSystem::Type tuningSystem = TuningSystem::Type::EqualTemperament;

    // FFT
    std::unique_ptr<juce::dsp::FFT> fft;
    std::array<float, fftSize> window;
    std::array<float, fftSize * 2> fftBuffer;

    // Spectrum data
    std::array<float, numBins> magnitude;
    std::array<float, numBins> magnitudeDB;
    std::array<float, numBins> phase;
    std::array<float, numBins> prevMagnitude;

    // Input buffer
    std::array<float, fftSize> inputBuffer;
    int inputWritePos = 0;

    // Analysis results
    PitchInfo pitchInfo;
    HarmonicAnalysis harmonicAnalysis;
    BrainwaveBands brainwaveBands;
    PlanetaryResonance planetaryResonance;
    SolfeggioDetection solfeggioDetection;
    ChakraAnalysis chakraAnalysis;
    GoldenRatioAnalysis goldenRatioAnalysis;
    ScientificMeters scientificMeters;

    // Internal methods
    void performFFT();
    void calculateMagnitudeSpectrum();
    void detectPitch();
    void analyzeHarmonics();
    void analyzeBrainwaveBands();
    void detectPlanetaryResonance();
    void detectSolfeggio();
    void analyzeChakras();
    void analyzeGoldenRatio();
    void calculateScientificMeters();

    void initializeChakras();

    // Peak picking
    std::vector<std::pair<int, float>> findPeaks(int minDistance = 10, float threshold = 0.01f);

    // Interpolated peak frequency (parabolic interpolation)
    double interpolatePeakFrequency(int peakBin);

    // Get energy in frequency range
    float getEnergyInRange(double lowHz, double highHz);
};

//==============================================================================
// Multi-Band Scientific Analyzer (for visualization)
//==============================================================================

class MultiBandScientificAnalyzer
{
public:
    static constexpr int numOctaveBands = 10;
    static constexpr int numThirdOctaveBands = 31;

    MultiBandScientificAnalyzer();

    void prepare(double sampleRate, int samplesPerBlock);
    void processBlock(const float* samples, int numSamples);

    //==========================================================================
    // Octave Band Analysis (ISO 266)
    //==========================================================================

    struct OctaveBand
    {
        double centerFreq;
        double lowFreq;
        double highFreq;
        float energy = 0.0f;
        float energyDB = -100.0f;
    };

    const std::array<OctaveBand, numOctaveBands>& getOctaveBands() const { return octaveBands; }

    //==========================================================================
    // 1/3 Octave Band Analysis
    //==========================================================================

    const std::array<OctaveBand, numThirdOctaveBands>& getThirdOctaveBands() const { return thirdOctaveBands; }

    //==========================================================================
    // Bark Scale Analysis (Psychoacoustic)
    //==========================================================================

    static constexpr int numBarkBands = 24;

    struct BarkBand
    {
        int bandNumber;
        double centerFreq;
        double bandwidth;
        float specificLoudness = 0.0f;  // Sones
        float maskedThreshold = 0.0f;   // dB
    };

    const std::array<BarkBand, numBarkBands>& getBarkBands() const { return barkBands; }

    /** Get total loudness in sones */
    float getTotalLoudness() const { return totalLoudness; }

    //==========================================================================
    // Mel Scale Analysis (for voice/music perception)
    //==========================================================================

    static constexpr int numMelBands = 40;

    const std::array<float, numMelBands>& getMelSpectrum() const { return melSpectrum; }

    /** Convert Hz to Mel */
    static double hzToMel(double hz) { return 2595.0 * std::log10(1.0 + hz / 700.0); }

    /** Convert Mel to Hz */
    static double melToHz(double mel) { return 700.0 * (std::pow(10.0, mel / 2595.0) - 1.0); }

    //==========================================================================
    // ERB Scale (Equivalent Rectangular Bandwidth)
    //==========================================================================

    static constexpr int numERBands = 32;

    struct ERBBand
    {
        double centerFreq;
        double erb;                     // Equivalent rectangular bandwidth
        float energy = 0.0f;
    };

    const std::array<ERBBand, numERBands>& getERBBands() const { return erbBands; }

    /** Calculate ERB at given frequency */
    static double calculateERB(double hz) { return 24.7 * (4.37 * hz / 1000.0 + 1.0); }

private:
    double sampleRate = 48000.0;
    PhysicallyCorrectAnalyzer coreAnalyzer;

    std::array<OctaveBand, numOctaveBands> octaveBands;
    std::array<OctaveBand, numThirdOctaveBands> thirdOctaveBands;
    std::array<BarkBand, numBarkBands> barkBands;
    std::array<float, numMelBands> melSpectrum;
    std::array<ERBBand, numERBands> erbBands;

    float totalLoudness = 0.0f;

    void initializeOctaveBands();
    void initializeBarkBands();
    void initializeMelFilterbank();
    void initializeERBBands();

    void calculateOctaveBands();
    void calculateBarkBands();
    void calculateMelSpectrum();
    void calculateERBBands();
    void calculateLoudness();
};

//==============================================================================
// Real-Time Tuner with Scientific Reference
//==============================================================================

class ScientificTuner
{
public:
    ScientificTuner();

    void prepare(double sampleRate, int samplesPerBlock);
    void processBlock(const float* samples, int numSamples);

    //==========================================================================
    // Tuning Result
    //==========================================================================

    struct TuningResult
    {
        bool noteDetected = false;

        double frequencyHz = 0.0;
        double confidence = 0.0;

        // Note info
        juce::String noteName;
        int octave = 0;
        int midiNote = 0;

        // Cents from target (for needle display)
        double centsFromTarget = 0.0;   // -50 to +50

        // Comparison to different tuning systems
        double centsFromET = 0.0;       // Equal temperament
        double centsFromPyth = 0.0;     // Pythagorean
        double centsFromJI = 0.0;       // Just intonation
        double centsFromScientific = 0.0; // Scientific pitch

        // Target frequencies for each system
        double targetET = 0.0;
        double targetPyth = 0.0;
        double targetJI = 0.0;
        double targetScientific = 0.0;

        // Special frequency info
        bool nearSolfeggio = false;
        double nearestSolfeggioHz = 0.0;

        bool nearPlanetary = false;
        juce::String nearestPlanet;
        double nearestPlanetaryHz = 0.0;
    };

    TuningResult getTuningResult() const { return result; }

    //==========================================================================
    // Configuration
    //==========================================================================

    void setReferenceA4(double hz) { referenceA4 = hz; }
    double getReferenceA4() const { return referenceA4; }

    void setTargetTuningSystem(TuningSystem::Type system) { targetSystem = system; }

    /** Set transposition (semitones) */
    void setTransposition(int semitones) { transposition = semitones; }

private:
    double sampleRate = 48000.0;
    double referenceA4 = 440.0;
    TuningSystem::Type targetSystem = TuningSystem::Type::EqualTemperament;
    int transposition = 0;

    // Pitch detection using autocorrelation
    std::vector<float> inputBuffer;
    std::vector<float> correlationBuffer;
    int inputWritePos = 0;
    int bufferSize = 4096;

    TuningResult result;

    void detectPitch();
    double autocorrelationPitchDetection();
    void calculateTuningOffsets();
    void checkSpecialFrequencies();
};

}  // namespace Echoel::DSP
