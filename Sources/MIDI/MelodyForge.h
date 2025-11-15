#pragma once

#include <JuceHeader.h>
#include "ChordGenius.h"
#include <vector>
#include <random>

/**
 * MelodyForge - AI Melody Generation Engine
 *
 * Professional melody creation inspired by Captain Melody, Orb Composer:
 * - AI melody generation based on chord progressions
 * - Scale-aware note generation (never hits wrong notes)
 * - Rhythm pattern library (swing, triplets, syncopation, straight)
 * - Humanization (velocity, timing, note length variation)
 * - Melodic contour control (ascending, descending, arch, valley)
 * - Motif development (repetition, sequence, inversion, retrograde)
 * - Genre-specific patterns (Pop, Jazz, Classical, EDM, Hip-Hop)
 * - MIDI drag & drop export
 *
 * Used by: Producers, songwriters, beat makers, film composers
 */
class MelodyForge
{
public:
    MelodyForge();
    ~MelodyForge();

    //==============================================================================
    // Melody Note

    struct MelodyNote
    {
        int pitch;              // MIDI note number
        double startTime;       // Seconds
        double duration;        // Seconds
        uint8 velocity;         // 0-127
        bool isRest;            // True if rest

        MelodyNote() : pitch(60), startTime(0.0), duration(0.5), velocity(100), isRest(false) {}
    };

    //==============================================================================
    // Melody Structure

    struct Melody
    {
        std::vector<MelodyNote> notes;
        int key;                        // Root note (0-11)
        ChordGenius::Scale scale;
        std::string genre;
        double bpm;

        Melody() : key(0), scale(ChordGenius::Scale::Major), genre("Pop"), bpm(120.0) {}
    };

    //==============================================================================
    // Rhythm Patterns

    enum class RhythmPattern
    {
        Straight,           // Quarter notes
        EighthNotes,        // Eighth notes
        Sixteenths,         // Sixteenth notes
        Triplets,           // Eighth note triplets
        SwingEighths,       // Swing feel
        Syncopated,         // Off-beat accents
        Dotted,             // Dotted rhythms
        Mixed,              // Combination
        Custom              // User-defined
    };

    //==============================================================================
    // Melodic Contour

    enum class MelodicContour
    {
        Ascending,          // Upward motion
        Descending,         // Downward motion
        Arch,               // Up then down
        Valley,             // Down then up
        Zigzag,             // Alternating up/down
        Plateau,            // Mostly horizontal
        Random,             // No pattern
        Stepwise,           // Small intervals
        LeapFriendly        // Larger intervals
    };

    //==============================================================================
    // Melody Generation

    /** Generate melody over chord progression */
    Melody generateMelody(const ChordGenius::Progression& progression,
                         int numBars = 4,
                         double bpm = 120.0);

    /** Generate melody with specific rhythm pattern */
    Melody generateMelodyWithRhythm(const ChordGenius::Progression& progression,
                                    RhythmPattern rhythm,
                                    int numBars = 4,
                                    double bpm = 120.0);

    /** Generate melody with contour control */
    Melody generateMelodyWithContour(const ChordGenius::Progression& progression,
                                     MelodicContour contour,
                                     int numBars = 4,
                                     double bpm = 120.0);

    /** Generate melody for specific genre */
    Melody generateGenreMelody(const ChordGenius::Progression& progression,
                               const std::string& genre,
                               int numBars = 4,
                               double bpm = 120.0);

    //==============================================================================
    // Melody Transformation

    /** Transpose melody by semitones */
    Melody transposeMelody(const Melody& melody, int semitones);

    /** Invert melody (upside down) */
    Melody invertMelody(const Melody& melody);

    /** Retrograde (play backwards) */
    Melody retrogradeMelody(const Melody& melody);

    /** Apply sequence (repeat motif at different pitches) */
    Melody sequenceMelody(const Melody& melody, int repetitions, int intervalStep);

    /** Augmentation (make notes longer) */
    Melody augmentMelody(const Melody& melody, double factor = 2.0);

    /** Diminution (make notes shorter) */
    Melody diminuteMelody(const Melody& melody, double factor = 0.5);

    //==============================================================================
    // Humanization

    /** Apply humanization (timing, velocity, duration variation) */
    void humanizeMelody(Melody& melody, float amount = 0.5f);

    /** Apply swing feel */
    void applySwing(Melody& melody, float swingAmount = 0.5f);

    /** Quantize to grid */
    void quantizeMelody(Melody& melody, double gridSize = 0.25);  // 16th notes

    //==============================================================================
    // MIDI Export

    /** Convert melody to MIDI buffer */
    void melodyToMidiBuffer(const Melody& melody, juce::MidiBuffer& buffer);

    /** Export melody as MIDI file */
    bool exportMelodyToMidi(const Melody& melody, const juce::File& outputFile);

    //==============================================================================
    // Parameters

    /** Set note density (0-1): 0=sparse, 1=dense */
    void setNoteDensity(float density);

    /** Set rest probability (0-1) */
    void setRestProbability(float probability);

    /** Set interval range (0=small steps, 12=wide leaps) */
    void setIntervalRange(int maxInterval);

    /** Set repetition amount (0-1): motif development */
    void setRepetitionAmount(float amount);

private:
    //==============================================================================
    // AI Generation Engine

    /** Generate single note based on context */
    MelodyNote generateNote(const ChordGenius::Chord& currentChord,
                           const std::vector<int>& scaleNotes,
                           const MelodyNote& previousNote,
                           MelodicContour contour);

    /** Get rhythm pattern durations */
    std::vector<double> getRhythmDurations(RhythmPattern pattern, double bpm);

    /** Get scale notes in range */
    std::vector<int> getScaleNotes(int rootNote, ChordGenius::Scale scale, int octaveMin, int octaveMax);

    /** Calculate next note based on contour */
    int getNextPitchFromContour(int currentPitch, MelodicContour contour,
                               const std::vector<int>& scaleNotes, int& contourPosition);

    /** Get chord tones from chord */
    std::vector<int> getChordTones(const ChordGenius::Chord& chord, int octaveMin, int octaveMax);

    /** Check if note is chord tone */
    bool isChordTone(int pitch, const ChordGenius::Chord& chord);

    /** Get genre-specific parameters */
    void applyGenreStyle(const std::string& genre);

    //==============================================================================
    // Parameters
    float noteDensity = 0.7f;           // Note density
    float restProbability = 0.15f;      // Probability of rests
    int maxInterval = 7;                // Max melodic interval (semitones)
    float repetitionAmount = 0.3f;      // Motif repetition
    float humanizationAmount = 0.5f;    // Timing/velocity variation

    // Random generator
    std::mt19937 randomEngine;
    std::uniform_real_distribution<float> uniformDist;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (MelodyForge)
};
