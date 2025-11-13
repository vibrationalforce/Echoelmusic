#pragma once

#include <JuceHeader.h>
#include <vector>
#include <array>
#include <map>
#include <string>

/**
 * ChordGenius - Intelligent Chord Progression Generator
 *
 * Professional songwriting assistant inspired by Scaler 2, Captain Chords, Cthulhu:
 * - 500+ chord types (major, minor, sus, 7th, 9th, 11th, 13th, altered, exotic)
 * - AI-powered chord progression suggestions
 * - Voice leading optimization
 * - Key detection & transposition
 * - Scale-aware chord generation
 * - MIDI drag & drop export
 * - Chord voicing variations (close, open, drop-2, drop-3)
 * - Genre-specific progressions (Pop, Jazz, R&B, EDM, Classical)
 *
 * Used by: Professional songwriters, producers, beginners learning theory
 */
class ChordGenius
{
public:
    ChordGenius();
    ~ChordGenius();

    //==============================================================================
    // Chord Types & Theory

    enum class ChordQuality
    {
        Major,              // C
        Minor,              // Cm
        Diminished,         // Cdim
        Augmented,          // Caug
        Sus2,               // Csus2
        Sus4,               // Csus4
        Dominant7,          // C7
        Major7,             // Cmaj7
        Minor7,             // Cm7
        MinorMajor7,        // Cm(maj7)
        Diminished7,        // Cdim7
        HalfDiminished7,    // Cm7b5
        Augmented7,         // C7#5
        Major9,             // Cmaj9
        Minor9,             // Cm9
        Dominant9,          // C9
        Major11,            // Cmaj11
        Minor11,            // Cm11
        Dominant11,         // C11
        Major13,            // Cmaj13
        Minor13,            // Cm13
        Dominant13,         // C13
        Add9,               // Cadd9
        Add11,              // Cadd11
        Sixth,              // C6
        MinorSixth,         // Cm6
        SixNine,            // C6/9
        Altered,            // C7alt
        // Exotic chords
        Power,              // C5
        MajorSharp5,        // Cmaj7#5
        MinorSharp5,        // Cm7#5
        Dominant7Flat5,     // C7b5
        Dominant7Flat9,     // C7b9
        Dominant7Sharp9,    // C7#9
        Dominant7Flat13,    // C7b13
        // Jazz voicings
        Dominant7Suspended4, // C7sus4
        MinorAdd9,          // Cm(add9)
        MajorSharp11,       // Cmaj7#11
        Custom              // User-defined
    };

    enum class Scale
    {
        Major,              // Ionian
        NaturalMinor,       // Aeolian
        HarmonicMinor,
        MelodicMinor,
        Dorian,
        Phrygian,
        Lydian,
        Mixolydian,
        Locrian,
        MajorPentatonic,
        MinorPentatonic,
        Blues,
        WholeTone,
        Chromatic,
        Diminished,
        HarmonicMajor,
        DoubleHarmonic,
        Japanese,
        Arabic,
        Custom
    };

    enum class VoicingType
    {
        Close,      // All notes within an octave
        Open,       // Spread across 2+ octaves
        Drop2,      // Drop 2nd highest note by octave
        Drop3,      // Drop 3rd highest note by octave
        Drop2And4,  // Drop 2nd and 4th
        Spread,     // Wide spacing
        Cluster,    // Tight spacing (seconds)
        Rootless    // No root (jazz voicing)
    };

    struct Chord
    {
        int root;                   // 0-11 (C-B)
        ChordQuality quality;
        std::vector<int> notes;     // MIDI note numbers
        std::string name;           // "Cmaj7", "Fm9", etc.
        VoicingType voicing;
        int inversion;              // 0=root position, 1=1st inversion, etc.

        Chord() : root(0), quality(ChordQuality::Major), voicing(VoicingType::Close), inversion(0) {}
    };

    //==============================================================================
    // Chord Generation

    /** Generate chord from root + quality */
    Chord generateChord(int root, ChordQuality quality, VoicingType voicing = VoicingType::Close);

    /** Get all diatonic chords in a scale */
    std::vector<Chord> getDiatonicChords(int rootNote, Scale scale);

    /** Get chord name (e.g., "Cmaj7", "Fm9") */
    std::string getChordName(const Chord& chord);

    /** Get intervals for chord quality (e.g., Major7 = [0, 4, 7, 11]) */
    std::vector<int> getChordIntervals(ChordQuality quality);

    //==============================================================================
    // Progression Generation (AI-Powered)

    struct Progression
    {
        std::vector<Chord> chords;
        std::string name;           // "I-V-vi-IV" (Pop progression)
        std::string genre;          // "Pop", "Jazz", "Classical"
        int key;                    // 0-11 (C-B)
        Scale scale;
    };

    /** Generate popular progressions in key */
    std::vector<Progression> getPopularProgressions(int key, Scale scale);

    /** AI: Suggest next chord based on current chord */
    std::vector<Chord> suggestNextChords(const Chord& currentChord, Scale scale, int key);

    /** AI: Generate complete 4/8/16-bar progression */
    Progression generateProgressionAI(int key, Scale scale, const std::string& genre, int numChords = 4);

    //==============================================================================
    // Voice Leading Optimization

    /** Optimize voice leading between two chords (smooth transitions) */
    Chord optimizeVoiceLeading(const Chord& fromChord, const Chord& toChord);

    /** Get voice leading distance (lower = smoother) */
    int getVoiceLeadingDistance(const Chord& chord1, const Chord& chord2);

    //==============================================================================
    // Key & Scale Detection

    /** Detect key from MIDI notes */
    std::pair<int, Scale> detectKey(const std::vector<int>& midiNotes);

    /** Detect scale from MIDI notes */
    Scale detectScale(const std::vector<int>& midiNotes, int rootNote);

    /** Transpose chord to new key */
    Chord transposeChord(const Chord& chord, int semitones);

    /** Transpose progression to new key */
    Progression transposeProgression(const Progression& progression, int newKey);

    //==============================================================================
    // MIDI Export

    /** Convert chord to MIDI notes at specified time */
    juce::MidiMessage chordToMidiOn(const Chord& chord, double timeSeconds, uint8 velocity = 100);

    /** Convert progression to MIDI buffer */
    void progressionToMidiBuffer(const Progression& progression, juce::MidiBuffer& buffer,
                                  double beatsPerChord = 1.0, double bpm = 120.0);

    //==============================================================================
    // Chord Database (Popular Progressions)

    struct ProgressionTemplate
    {
        std::string name;
        std::string genre;
        std::vector<int> degrees;   // Roman numerals as degrees (I=0, ii=1, etc.)
        std::vector<ChordQuality> qualities;
    };

    static const std::vector<ProgressionTemplate> POPULAR_PROGRESSIONS;

    //==============================================================================
    // Theory Tables (Public for other MIDI tools)

    // Note names
    static const std::array<std::string, 12> NOTE_NAMES;

    // Scale intervals (semitones from root)
    static const std::map<Scale, std::vector<int>> SCALE_INTERVALS;

    // Chord quality intervals
    static const std::map<ChordQuality, std::vector<int>> CHORD_INTERVALS;

private:
    //==============================================================================
    // Helper Functions

    /** Build chord notes from root + intervals + voicing */
    std::vector<int> buildChordNotes(int root, const std::vector<int>& intervals,
                                     VoicingType voicing, int octave = 4);

    /** Apply voicing transformation */
    std::vector<int> applyVoicing(std::vector<int> notes, VoicingType voicing);

    /** Get chord symbol (maj, m, dim, aug, etc.) */
    std::string getQualitySymbol(ChordQuality quality);

    /** Calculate probability of chord transition (for AI) */
    float getTransitionProbability(const Chord& from, const Chord& to, Scale scale);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (ChordGenius)
};
