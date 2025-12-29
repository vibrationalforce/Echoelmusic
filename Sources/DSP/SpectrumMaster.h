#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>
#include <map>

/**
 * SpectrumMaster - Intelligent Spectrum Analyzer & Visual Learning Tool
 *
 * FabFilter Pro-Q 4 evolution with AI-powered learning features:
 * - Color-coded frequency analysis (like Pro-Q 4)
 * - Reference track overlay comparison
 * - Problem frequency detection (masking, resonances, phase issues)
 * - Multi-track spectrum visualization
 * - Real-time phase correlation
 * - Stereo imaging analysis
 * - LUFS/loudness metering
 *
 * LEARNING PHILOSOPHY:
 * - Shows WHAT is wrong (visual)
 * - Explains WHY it's wrong (analysis)
 * - Suggests HOW to fix (guidance)
 * - USER makes the changes (learn-by-doing)
 */
class SpectrumMaster
{
public:
    SpectrumMaster();
    ~SpectrumMaster();

    void prepare(double sampleRate, int samplesPerBlock, int numChannels);
    void reset();
    void process(const juce::AudioBuffer<float>& buffer);

    //==============================================================================
    // Spectrum Analysis

    struct FrequencyBand
    {
        float frequency = 1000.0f;
        float magnitude = 0.0f;           // Current level
        float referenceMagnitude = 0.0f;  // Reference track level
        float idealMagnitude = 0.0f;      // Genre-ideal level

        enum class Status
        {
            Good,        // Green - perfect range
            Warning,     // Yellow - slight issue
            Problem      // Red - needs attention
        };
        Status status = Status::Good;

        std::string problemDescription;  // "Too much energy", "Masking detected", etc.
        std::string suggestion;          // "Reduce by 2-3dB", "Apply high-pass at 80Hz", etc.
    };

    std::vector<FrequencyBand> getSpectrumData() const;

    //==============================================================================
    // Reference Track Comparison

    void loadReferenceTrack(const juce::File& audioFile);
    void clearReferenceTrack();
    bool hasReferenceTrack() const { return referenceLoaded; }

    void setReferenceOverlayEnabled(bool enabled) { referenceOverlayEnabled = enabled; }
    void setReferenceOpacity(float opacity);  // 0.0-1.0

    //==============================================================================
    // Problem Detection

    enum class ProblemType
    {
        None,               // No problem detected
        TooMuchLowEnd,      // <100Hz overload
        MuddyMidrange,      // 200-500Hz buildup
        HarshMidrange,      // 2-5kHz too aggressive
        LackOfHighEnd,      // <8kHz missing air
        Resonance,          // Narrow peak
        PhaseIssue,         // Phase cancellation
        MonoIncompatible,   // Stereo spread problems
        Masking             // Frequency collision between instruments
    };

    struct Problem
    {
        ProblemType type = ProblemType::None;
        float frequencyHz = 0.0f;
        float severity = 0.0f;    // 0.0-1.0
        std::string description;
        std::string solution;
        juce::Colour displayColor { 0xff888888 };
    };

    std::vector<Problem> detectProblems() const;

    //==============================================================================
    // Stereo Analysis

    struct StereoInfo
    {
        float width = 0.5f;            // 0.0-1.0 (mono to full stereo)
        float correlation = 1.0f;      // -1.0 to 1.0
        float leftRightBalance = 0.0f; // -1.0 (left) to 1.0 (right)
        bool monoCompatible = true;
        std::vector<float> stereoFieldPerBand;  // Stereo width per frequency
    };

    StereoInfo getStereoAnalysis() const;

    //==============================================================================
    // Loudness Metering

    struct LoudnessInfo
    {
        float integrated;         // LUFS (integrated)
        float shortTerm;          // LUFS (3 seconds)
        float momentary;          // LUFS (400ms)
        float truePeak;           // dBTP
        float dynamicRange;       // LU (loudness units)

        std::string genreRecommendation;  // "Aim for -10 LUFS for Pop"
        float distanceFromTarget;         // +/- dB from genre ideal
    };

    LoudnessInfo getLoudnessAnalysis() const;

    //==============================================================================
    // Genre-Aware Analysis

    void setGenre(const std::string& genre);  // Uses WorldMusicDatabase
    std::string getDetectedGenre() const;     // Auto-detect from spectrum

    struct GenreProfile
    {
        std::string name;
        std::map<float, float> idealSpectrum;  // Frequency -> ideal dB
        float targetLUFS;
        float targetDynamicRange;
        std::vector<std::string> tips;
    };

    GenreProfile getGenreProfile() const;

    //==============================================================================
    // Multi-Track Analysis

    void addTrack(const std::string& trackName, const juce::AudioBuffer<float>& buffer);
    void clearTracks();

    struct TrackSpectrum
    {
        std::string name;
        std::vector<FrequencyBand> spectrum;
        juce::Colour displayColor;
    };

    std::vector<TrackSpectrum> getAllTrackSpectra() const;
    std::vector<Problem> detectInterTrackMasking() const;  // Find frequency collisions

    //==============================================================================
    // Visualization Settings

    void setResolution(int numBands);      // 32, 64, 128, 256
    void setFrequencyRange(float minHz, float maxHz);
    void setDisplayMode(bool logarithmic);
    void setSmoothingFactor(float factor);  // 0.0-1.0

    //==============================================================================
    // Export Analysis

    struct AnalysisReport
    {
        std::string genre;
        std::vector<Problem> problems;
        LoudnessInfo loudness;
        StereoInfo stereo;
        std::vector<std::string> recommendations;
        float overallScore;  // 0-100 (mastering quality)
    };

    AnalysisReport generateReport() const;
    void exportReportToFile(const juce::File& outputFile) const;

private:
    //==============================================================================
    // DSP State

    double currentSampleRate = 48000.0;
    int fftOrder = 13;  // 8192 samples
    int fftSize = 8192;

    juce::dsp::FFT forwardFFT;
    juce::dsp::WindowingFunction<float> window;

    std::array<float, 16384> fftData;
    std::vector<float> spectrumMagnitudes;
    std::vector<float> spectrumSmoothed;

    // Reference track
    bool referenceLoaded = false;
    bool referenceOverlayEnabled = true;
    float referenceOpacity = 0.7f;
    std::vector<float> referenceMagnitudes;

    // Multi-track
    std::map<std::string, std::vector<float>> trackSpectra;

    // Genre
    std::string currentGenre = "Unknown";
    GenreProfile currentGenreProfile;

    // Settings
    int numBands = 128;
    float minFreq = 20.0f;
    float maxFreq = 20000.0f;
    bool logarithmicDisplay = true;
    float smoothingFactor = 0.7f;

    // Analysis cache
    mutable std::vector<Problem> cachedProblems;
    mutable LoudnessInfo cachedLoudness;
    mutable StereoInfo cachedStereo;
    mutable bool analysisCacheDirty = true;

    //==============================================================================
    // Internal Analysis

    void performFFTAnalysis(const juce::AudioBuffer<float>& buffer);
    void smoothSpectrum();
    void detectProblemsInternal() const;
    void analyzeLoudness(const juce::AudioBuffer<float>& buffer);
    void analyzeStereo(const juce::AudioBuffer<float>& buffer);
    std::string autoDetectGenre() const;

    float getMagnitudeAtFrequency(float frequency, const std::vector<float>& spectrum) const;
    juce::Colour getProblemColor(ProblemType type) const;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SpectrumMaster)
};
