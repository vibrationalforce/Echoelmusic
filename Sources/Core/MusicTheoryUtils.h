/*
  ==============================================================================

    MusicTheoryUtils.h
    Shared Music Theory Utilities

    Consolidates common music theory functions used across Ralph Wiggum systems.
    Eliminates code duplication and provides a single source of truth for:
    - Scale/mode generation
    - Chord voicing
    - Progression patterns
    - Interval calculations

    Design: Stateless utility functions for thread safety.

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include <vector>
#include <array>
#include <string>
#include <random>
#include <cmath>

namespace Echoelmusic {
namespace MusicTheory {

//==============================================================================
// Interval Constants (semitones from root)
//==============================================================================

namespace Intervals
{
    constexpr int UNISON = 0;
    constexpr int MINOR_2ND = 1;
    constexpr int MAJOR_2ND = 2;
    constexpr int MINOR_3RD = 3;
    constexpr int MAJOR_3RD = 4;
    constexpr int PERFECT_4TH = 5;
    constexpr int TRITONE = 6;
    constexpr int PERFECT_5TH = 7;
    constexpr int MINOR_6TH = 8;
    constexpr int MAJOR_6TH = 9;
    constexpr int MINOR_7TH = 10;
    constexpr int MAJOR_7TH = 11;
    constexpr int OCTAVE = 12;
}

//==============================================================================
// Scale Patterns (semitone intervals from root)
//==============================================================================

namespace Scales
{
    // Major modes
    constexpr std::array<int, 7> IONIAN     = {0, 2, 4, 5, 7, 9, 11};      // Major
    constexpr std::array<int, 7> DORIAN     = {0, 2, 3, 5, 7, 9, 10};
    constexpr std::array<int, 7> PHRYGIAN   = {0, 1, 3, 5, 7, 8, 10};
    constexpr std::array<int, 7> LYDIAN     = {0, 2, 4, 6, 7, 9, 11};
    constexpr std::array<int, 7> MIXOLYDIAN = {0, 2, 4, 5, 7, 9, 10};
    constexpr std::array<int, 7> AEOLIAN    = {0, 2, 3, 5, 7, 8, 10};      // Natural minor
    constexpr std::array<int, 7> LOCRIAN    = {0, 1, 3, 5, 6, 8, 10};

    // Other common scales
    constexpr std::array<int, 7> HARMONIC_MINOR = {0, 2, 3, 5, 7, 8, 11};
    constexpr std::array<int, 7> MELODIC_MINOR  = {0, 2, 3, 5, 7, 9, 11};
    constexpr std::array<int, 5> PENTATONIC_MAJOR = {0, 2, 4, 7, 9};
    constexpr std::array<int, 5> PENTATONIC_MINOR = {0, 3, 5, 7, 10};
    constexpr std::array<int, 6> BLUES = {0, 3, 5, 6, 7, 10};
}

//==============================================================================
// Common Chord Progressions (scale degrees, 0-indexed)
//==============================================================================

namespace Progressions
{
    // Pop/Rock progressions
    constexpr std::array<int, 4> I_V_vi_IV     = {0, 4, 5, 3};    // Most common pop
    constexpr std::array<int, 4> I_vi_IV_V     = {0, 5, 3, 4};    // 50s progression
    constexpr std::array<int, 4> I_IV_V_V      = {0, 3, 4, 4};    // Blues-rock
    constexpr std::array<int, 4> vi_IV_I_V     = {5, 3, 0, 4};    // Minor start

    // Jazz progressions
    constexpr std::array<int, 4> ii_V_I_vi     = {1, 4, 0, 5};    // Jazz turnaround
    constexpr std::array<int, 4> I_VI_ii_V     = {0, 5, 1, 4};    // Rhythm changes
    constexpr std::array<int, 3> ii_V_I        = {1, 4, 0};       // Classic jazz

    // Melancholic/Cinematic
    constexpr std::array<int, 4> i_VI_III_VII  = {0, 5, 2, 6};    // Epic minor
    constexpr std::array<int, 4> i_iv_VII_III  = {0, 3, 6, 2};    // Emotional minor
}

//==============================================================================
// Chord Quality Intervals
//==============================================================================

namespace ChordQualities
{
    // Triads (from root)
    constexpr std::array<int, 3> MAJOR = {0, 4, 7};
    constexpr std::array<int, 3> MINOR = {0, 3, 7};
    constexpr std::array<int, 3> DIMINISHED = {0, 3, 6};
    constexpr std::array<int, 3> AUGMENTED = {0, 4, 8};

    // Seventh chords
    constexpr std::array<int, 4> MAJOR_7TH = {0, 4, 7, 11};
    constexpr std::array<int, 4> MINOR_7TH = {0, 3, 7, 10};
    constexpr std::array<int, 4> DOMINANT_7TH = {0, 4, 7, 10};
    constexpr std::array<int, 4> HALF_DIM_7TH = {0, 3, 6, 10};
    constexpr std::array<int, 4> FULL_DIM_7TH = {0, 3, 6, 9};

    // Extended chords (9ths)
    constexpr std::array<int, 5> MAJOR_9TH = {0, 4, 7, 11, 14};
    constexpr std::array<int, 5> MINOR_9TH = {0, 3, 7, 10, 14};
    constexpr std::array<int, 5> DOMINANT_9TH = {0, 4, 7, 10, 14};

    // Sus chords
    constexpr std::array<int, 3> SUS2 = {0, 2, 7};
    constexpr std::array<int, 3> SUS4 = {0, 5, 7};
    constexpr std::array<int, 4> ADD9 = {0, 4, 7, 14};
}

//==============================================================================
// Note Name Utilities
//==============================================================================

/**
 * Convert MIDI note number to note name.
 *
 * @param midiNote MIDI note number (0-127)
 * @param useSharps If true, use sharps; otherwise use flats
 * @return Note name string (e.g., "C4", "F#3", "Bb5")
 */
inline std::string midiToNoteName(int midiNote, bool useSharps = true)
{
    static const std::array<const char*, 12> sharpNames =
        {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"};
    static const std::array<const char*, 12> flatNames =
        {"C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"};

    if (midiNote < 0 || midiNote > 127)
        return "?";

    int noteIndex = midiNote % 12;
    int octave = (midiNote / 12) - 1;

    const auto& names = useSharps ? sharpNames : flatNames;
    return std::string(names[noteIndex]) + std::to_string(octave);
}

/**
 * Convert note name to MIDI note number.
 *
 * @param noteName Note name (e.g., "C4", "F#3", "Bb5")
 * @return MIDI note number, or -1 if invalid
 */
inline int noteNameToMidi(const std::string& noteName)
{
    if (noteName.empty())
        return -1;

    static const std::map<char, int> noteValues = {
        {'C', 0}, {'D', 2}, {'E', 4}, {'F', 5}, {'G', 7}, {'A', 9}, {'B', 11}
    };

    char note = std::toupper(noteName[0]);
    if (noteValues.find(note) == noteValues.end())
        return -1;

    int value = noteValues.at(note);
    size_t idx = 1;

    // Check for accidentals
    if (idx < noteName.size())
    {
        if (noteName[idx] == '#')
        {
            value++;
            idx++;
        }
        else if (noteName[idx] == 'b')
        {
            value--;
            idx++;
        }
    }

    // Parse octave
    int octave = 4;  // Default middle octave
    if (idx < noteName.size())
    {
        try
        {
            octave = std::stoi(noteName.substr(idx));
        }
        catch (...)
        {
            return -1;
        }
    }

    // MIDI note: (octave + 1) * 12 + value
    return (octave + 1) * 12 + value;
}

//==============================================================================
// Chord Voicing Utilities
//==============================================================================

/**
 * Generate MIDI notes for a chord.
 *
 * @param rootNote MIDI note for chord root
 * @param intervals Semitone intervals from root
 * @param inversion 0 = root, 1 = first inversion, etc.
 * @return Vector of MIDI notes for the chord
 */
template<size_t N>
inline std::vector<int> generateChordVoicing(
    int rootNote,
    const std::array<int, N>& intervals,
    int inversion = 0)
{
    std::vector<int> notes;
    notes.reserve(N);

    for (size_t i = 0; i < N; ++i)
    {
        int note = rootNote + intervals[i];

        // Handle inversions by moving lower notes up an octave
        if (static_cast<int>(i) < inversion)
            note += 12;

        notes.push_back(note);
    }

    return notes;
}

/**
 * Generate a chord based on scale degree.
 *
 * For diatonic harmony, determines chord quality from scale position:
 * - Major scale: I=maj, ii=min, iii=min, IV=maj, V=maj, vi=min, vii=dim
 *
 * @param root Scale root MIDI note (e.g., 60 for C4)
 * @param degree Scale degree (0-6)
 * @param isMinorKey If true, use minor key chord qualities
 * @return Vector of MIDI notes for the chord
 */
inline std::vector<int> generateDiatonicChord(int root, int degree, bool isMinorKey = false)
{
    // Scale degree to semitone offset (major scale)
    static const std::array<int, 7> majorOffsets = {0, 2, 4, 5, 7, 9, 11};
    // Chord quality for each degree in major key (0=maj, 1=min, 2=dim)
    static const std::array<int, 7> majorQualities = {0, 1, 1, 0, 0, 1, 2};
    // Chord quality for each degree in minor key
    static const std::array<int, 7> minorQualities = {1, 2, 0, 1, 0, 0, 0};

    int normalizedDegree = ((degree % 7) + 7) % 7;
    int chordRoot = root + majorOffsets[normalizedDegree];
    int quality = isMinorKey ? minorQualities[normalizedDegree] : majorQualities[normalizedDegree];

    switch (quality)
    {
        case 0:  // Major
            return generateChordVoicing(chordRoot, ChordQualities::MAJOR);
        case 1:  // Minor
            return generateChordVoicing(chordRoot, ChordQualities::MINOR);
        case 2:  // Diminished
            return generateChordVoicing(chordRoot, ChordQualities::DIMINISHED);
        default:
            return generateChordVoicing(chordRoot, ChordQualities::MAJOR);
    }
}

//==============================================================================
// Melody Generation Utilities
//==============================================================================

/**
 * Generate scale notes for a given root and scale type.
 *
 * @param root Root MIDI note
 * @param scaleIntervals Scale intervals
 * @param octaves Number of octaves to generate
 * @return Vector of MIDI notes in the scale
 */
template<size_t N>
inline std::vector<int> generateScaleNotes(
    int root,
    const std::array<int, N>& scaleIntervals,
    int octaves = 2)
{
    std::vector<int> notes;
    notes.reserve(N * octaves + 1);

    for (int oct = 0; oct < octaves; ++oct)
    {
        for (size_t i = 0; i < N; ++i)
        {
            notes.push_back(root + oct * 12 + scaleIntervals[i]);
        }
    }
    notes.push_back(root + octaves * 12);  // Add final root

    return notes;
}

/**
 * Quantize a MIDI note to the nearest scale note.
 *
 * @param midiNote Input MIDI note
 * @param scaleNotes Available scale notes
 * @return Nearest scale note
 */
inline int quantizeToScale(int midiNote, const std::vector<int>& scaleNotes)
{
    if (scaleNotes.empty())
        return midiNote;

    int nearest = scaleNotes[0];
    int minDist = std::abs(midiNote - nearest);

    for (int note : scaleNotes)
    {
        int dist = std::abs(midiNote - note);
        if (dist < minDist)
        {
            minDist = dist;
            nearest = note;
        }
    }

    return nearest;
}

//==============================================================================
// Rhythm Utilities
//==============================================================================

/**
 * Convert BPM to milliseconds per beat.
 *
 * @param bpm Beats per minute
 * @return Milliseconds per beat
 */
inline double bpmToMs(double bpm)
{
    return 60000.0 / bpm;
}

/**
 * Convert beat divisions to milliseconds.
 *
 * @param bpm Current tempo
 * @param division Beat division (1 = quarter, 2 = eighth, 4 = sixteenth)
 * @return Duration in milliseconds
 */
inline double divisionToMs(double bpm, double division)
{
    return bpmToMs(bpm) / division;
}

/**
 * Apply swing to a straight timing.
 *
 * @param position Original position (0.0 to 1.0 within beat)
 * @param swingAmount Swing amount (0.0 = straight, 0.5 = triplet, 1.0 = dotted)
 * @return Swung position
 */
inline double applySwing(double position, double swingAmount)
{
    // Swing affects odd eighth notes
    double beatFraction = std::fmod(position * 2.0, 1.0);

    if (beatFraction > 0.4 && beatFraction < 0.6)
    {
        // This is an upbeat - apply swing
        double swingOffset = swingAmount * 0.16667;  // Max swing = triplet
        return position + swingOffset;
    }

    return position;
}

//==============================================================================
// Frequency/MIDI Conversion
//==============================================================================

/**
 * Convert MIDI note to frequency in Hz.
 *
 * Uses standard A4 = 440 Hz tuning.
 *
 * @param midiNote MIDI note number
 * @param tuningHz Optional tuning reference (default 440 Hz)
 * @return Frequency in Hz
 */
inline double midiToFrequency(int midiNote, double tuningHz = 440.0)
{
    // A4 (MIDI 69) = 440 Hz
    // f = 440 * 2^((n - 69) / 12)
    return tuningHz * std::pow(2.0, (midiNote - 69) / 12.0);
}

/**
 * Convert frequency to nearest MIDI note.
 *
 * @param frequency Frequency in Hz
 * @param tuningHz Optional tuning reference (default 440 Hz)
 * @return Nearest MIDI note number
 */
inline int frequencyToMidi(double frequency, double tuningHz = 440.0)
{
    // n = 12 * log2(f / 440) + 69
    return static_cast<int>(std::round(12.0 * std::log2(frequency / tuningHz) + 69.0));
}

//==============================================================================
// Chord Symbol Generation
//==============================================================================

/**
 * Generate chord symbol from intervals.
 *
 * @param rootNote Root note name (e.g., "C", "F#")
 * @param intervals Chord intervals
 * @return Chord symbol (e.g., "Cmaj7", "F#m", "Bdim")
 */
inline std::string generateChordSymbol(const std::string& rootNote, const std::vector<int>& intervals)
{
    std::string symbol = rootNote;

    if (intervals.size() < 3)
        return symbol;

    int third = intervals[1] - intervals[0];
    int fifth = intervals[2] - intervals[0];

    // Determine quality
    if (third == 4 && fifth == 7)
    {
        // Major triad - implicit, no suffix for basic major
        if (intervals.size() >= 4)
        {
            int seventh = intervals[3] - intervals[0];
            if (seventh == 11)
                symbol += "maj7";
            else if (seventh == 10)
                symbol += "7";  // Dominant 7
        }
    }
    else if (third == 3 && fifth == 7)
    {
        // Minor
        symbol += "m";
        if (intervals.size() >= 4)
        {
            int seventh = intervals[3] - intervals[0];
            if (seventh == 10)
                symbol += "7";
        }
    }
    else if (third == 3 && fifth == 6)
    {
        symbol += "dim";
    }
    else if (third == 4 && fifth == 8)
    {
        symbol += "aug";
    }
    else if (third == 5)
    {
        symbol += "sus4";
    }
    else if (third == 2)
    {
        symbol += "sus2";
    }

    return symbol;
}

} // namespace MusicTheory
} // namespace Echoelmusic
