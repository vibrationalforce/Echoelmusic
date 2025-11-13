#pragma once

#include <JuceHeader.h>
#include "ChordGenius.h"
#include <vector>
#include <random>

/**
 * ArpWeaver - Advanced Arpeggiator & Sequencer
 *
 * Professional arpeggiator inspired by Cthulhu, Riffer, Instachord:
 * - 20+ arpeggio patterns (up, down, up/down, random, played, etc.)
 * - Rhythm patterns & gate control
 * - Octave range (1-4 octaves)
 * - Swing & humanization
 * - Latch mode & hold
 * - Pattern sequencer (up to 32 steps)
 * - Velocity control & accent patterns
 * - MIDI learn & drag/drop export
 *
 * Used by: EDM producers, trance/synthwave artists, live performers
 */
class ArpWeaver
{
public:
    ArpWeaver();
    ~ArpWeaver();

    //==============================================================================
    // Arp Note

    struct ArpNote
    {
        int pitch;              // MIDI note number
        double startTime;       // Seconds
        double duration;        // Seconds (gate applied)
        uint8 velocity;         // 0-127
        bool isAccent;          // Accent (louder)

        ArpNote() : pitch(60), startTime(0.0), duration(0.25), velocity(100), isAccent(false) {}
    };

    //==============================================================================
    // Arpeggio Pattern

    enum class ArpPattern
    {
        Up,                 // Ascending
        Down,               // Descending
        UpDown,             // Up then down (inclusive)
        UpDownExclusive,    // Up then down (exclusive)
        DownUp,             // Down then up
        Random,             // Random order
        Played,             // Order played
        Chord,              // All notes together
        UpDown2,            // Up/Down, 2 octaves
        Octaves,            // Root repeated across octaves
        Fifths,             // Perfect fifths
        ThirdsUp,           // Ascending thirds
        ThirdsDown,         // Descending thirds
        Penta Up,           // Pentatonic scale up
        PentaDown,          // Pentatonic down
        Sequence,           // Repeating sequence
        Ping Pong,          // Bounce back & forth
        Converge,           // From edges to center
        Diverge,            // From center to edges
        Random Walk         // Constrained random
    };

    //==============================================================================
    // Time Division

    enum class TimeDivision
    {
        Whole,              // 1/1
        Half,               // 1/2
        Quarter,            // 1/4
        Eighth,             // 1/8
        Sixteenth,          // 1/16
        ThirtySecond,       // 1/32
        DottedHalf,         // 1/2.
        DottedQuarter,      // 1/4.
        DottedEighth,       // 1/8.
        TripletQuarter,     // 1/4T
        TripletEighth,      // 1/8T
        TripletSixteenth    // 1/16T
    };

    //==============================================================================
    // Arpeggiator

    struct Arpeggio
    {
        std::vector<ArpNote> notes;
        ArpPattern pattern;
        double bpm;

        Arpeggio() : pattern(ArpPattern::Up), bpm(120.0) {}
    };

    //==============================================================================
    // Arpeggio Generation

    /** Generate arpeggio from chord */
    Arpeggio generateArpeggio(const ChordGenius::Chord& chord,
                             ArpPattern pattern = ArpPattern::Up,
                             int numBars = 1,
                             double bpm = 120.0);

    /** Generate arpeggio with time division */
    Arpeggio generateArpeggioWithDivision(const ChordGenius::Chord& chord,
                                          ArpPattern pattern,
                                          TimeDivision division,
                                          int numBars = 1,
                                          double bpm = 120.0);

    /** Generate arpeggio from progression (sequenced) */
    Arpeggio generateArpeggioSequence(const ChordGenius::Progression& progression,
                                      ArpPattern pattern,
                                      double bpm = 120.0);

    //==============================================================================
    // Parameters

    /** Set octave range (1-4) */
    void setOctaveRange(int octaves);

    /** Set gate (0-1): 0=staccato, 1=legato */
    void setGate(float gate);

    /** Set swing amount (0-1) */
    void setSwing(float swing);

    /** Set velocity (0-127) */
    void setVelocity(uint8 velocity);

    /** Set velocity range for humanization (0-127) */
    void setVelocityRange(uint8 range);

    /** Set accent pattern (e.g., [1,0,0,0] = accent every 4th note) */
    void setAccentPattern(const std::vector<bool>& pattern);

    /** Enable latch mode (hold notes) */
    void setLatchMode(bool enabled);

    //==============================================================================
    // Transformation

    /** Apply swing to arpeggio */
    void applySwing(Arpeggio& arpeggio, float swingAmount);

    /** Humanize timing & velocity */
    void humanizeArpeggio(Arpeggio& arpeggio, float amount);

    /** Transpose arpeggio */
    Arpeggio transposeArpeggio(const Arpeggio& arpeggio, int semitones);

    //==============================================================================
    // MIDI Export

    /** Convert arpeggio to MIDI buffer */
    void arpeggioToMidiBuffer(const Arpeggio& arpeggio, juce::MidiBuffer& buffer);

    /** Export arpeggio as MIDI file */
    bool exportArpeggioToMidi(const Arpeggio& arpeggio, const juce::File& outputFile);

private:
    //==============================================================================
    // Generation Helpers

    /** Get time division duration in seconds */
    double getTimeDivisionDuration(TimeDivision division, double bpm);

    /** Get arpeggio note sequence based on pattern */
    std::vector<int> getPatternSequence(const std::vector<int>& chordNotes, ArpPattern pattern);

    /** Generate arpeggio notes for range */
    std::vector<int> generateNotesForOctaveRange(const ChordGenius::Chord& chord);

    /** Apply accent pattern */
    void applyAccents(Arpeggio& arpeggio);

    //==============================================================================
    // Parameters
    int octaveRange = 1;
    float gate = 0.8f;                      // 80% note length
    float swingAmount = 0.0f;
    uint8 baseVelocity = 100;
    uint8 velocityRange = 20;
    std::vector<bool> accentPattern = {true, false, false, false};  // Accent every 4th
    bool latchMode = false;

    // Random generator
    std::mt19937 randomEngine;
    std::uniform_real_distribution<float> uniformDist;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (ArpWeaver)
};
