#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>
#include <string>
#include <map>

/**
 * ChordSense - Real-Time Chord Detection
 *
 * AI-powered chord recognition that analyzes audio and detects:
 * - Major, minor, diminished, augmented chords
 * - Extended chords (7th, 9th, 11th, 13th)
 * - Suspended and altered chords
 * - Chord inversions
 * - Voicing analysis
 * - Key detection
 * - Chord progression suggestions
 *
 * Inspired by: Mixed In Key, Hooktheory, Chordify
 */
class ChordSense
{
public:
    ChordSense();
    ~ChordSense();

    //==============================================================================
    // Processing

    void prepare(double sampleRate, int samplesPerBlock, int numChannels);
    void reset();

    void process(const juce::AudioBuffer<float>& buffer);

    //==============================================================================
    // Chord Detection

    struct Chord
    {
        std::string root;                  // "C", "C#", "D", etc.
        std::string quality;               // "major", "minor", "dim", "aug", "sus4", etc.
        std::vector<std::string> extensions; // "7", "9", "11", "13", "b5", etc.
        int inversion;                     // 0 = root position, 1 = first inversion, etc.
        float confidence;                  // 0.0 to 1.0
        std::vector<int> notes;            // MIDI note numbers in the chord
        std::string fullName;              // "Cmaj7", "Dm7b5", "G7sus4", etc.
        std::string notation;              // "C∆7", "Dm7♭5", "G7sus4", etc.

        // Voicing info
        int lowestNote;
        int highestNote;
        float spread;                      // Octaves between lowest and highest
    };

    Chord getCurrentChord() const;
    std::vector<Chord> getChordHistory(int count = 8) const;

    //==============================================================================
    // Key Detection

    struct Key
    {
        std::string tonic;                 // "C", "D", "E", etc.
        std::string mode;                  // "major", "minor", "dorian", etc.
        float confidence;                  // 0.0 to 1.0
        std::string fullName;              // "C major", "A minor", etc.
    };

    Key getDetectedKey() const;
    void setKey(const std::string& tonic, const std::string& mode);  // Manual override
    void clearKey();

    //==============================================================================
    // Analysis Settings

    void setSensitivity(float sensitivity);      // 0.0 to 1.0 (how quickly chords are detected)
    void setMinimumConfidence(float confidence); // 0.0 to 1.0 (minimum confidence to report chord)
    void setDetectInversions(bool detect);       // Enable/disable inversion detection
    void setDetectExtensions(bool detect);       // Enable/disable 7th, 9th, etc.

    //==============================================================================
    // Chord Progressions

    struct Progression
    {
        std::vector<Chord> chords;
        std::string romanNumerals;         // "I-V-vi-IV" (relative to key)
        std::string description;           // "Pop progression", "Jazz ii-V-I", etc.
        float popularity;                  // 0.0 to 1.0
    };

    std::vector<Progression> getSuggestedProgressions(int count = 5) const;
    std::string getRomanNumeral(const Chord& chord) const;

    //==============================================================================
    // Pitch Class Profile (Chromagram)

    std::array<float, 12> getPitchClassProfile() const;  // C, C#, D, D#, E, F, F#, G, G#, A, A#, B
    std::array<float, 12> getChordTemplate(const std::string& chordType) const;

    //==============================================================================
    // Export

    struct ChordEvent
    {
        double timeSeconds;
        Chord chord;
    };

    std::vector<ChordEvent> getChordTimeline() const;  // Full chord timeline

private:
    //==============================================================================
    // DSP State

    double currentSampleRate = 48000.0;
    int currentNumChannels = 2;

    // FFT for pitch detection
    static constexpr int fftOrder = 13;             // 8192 samples
    static constexpr int fftSize = 1 << fftOrder;
    juce::dsp::FFT forwardFFT;
    juce::dsp::WindowingFunction<float> window;

    std::array<float, fftSize * 2> fftData;
    std::array<float, fftSize> magnitudes;

    // Pitch class profile (chromagram)
    std::array<float, 12> pitchClassProfile;
    std::array<float, 12> smoothedPitchClassProfile;

    // Chord detection
    Chord currentChord;
    std::vector<Chord> chordHistory;
    Key detectedKey;

    // Settings
    float sensitivity = 0.7f;
    float minimumConfidence = 0.6f;
    bool detectInversions = true;
    bool detectExtensions = true;

    // Timeline
    std::vector<ChordEvent> chordTimeline;
    double currentTimeSeconds = 0.0;

    //==============================================================================
    // Internal Algorithms

    void performFFTAnalysis(const juce::AudioBuffer<float>& buffer);
    void calculatePitchClassProfile();
    void detectChord();
    void detectKey();

    // Chord templates
    void initializeChordTemplates();
    std::map<std::string, std::array<float, 12>> chordTemplates;

    // Chord matching
    float matchChordTemplate(const std::array<float, 12>& profile,
                            const std::array<float, 12>& template_,
                            int rootNote) const;
    std::string noteNumberToName(int noteNumber) const;
    int noteNameToNumber(const std::string& name) const;

    // Progression database
    void initializeProgressionDatabase();
    std::vector<Progression> progressionDatabase;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ChordSense)
};
