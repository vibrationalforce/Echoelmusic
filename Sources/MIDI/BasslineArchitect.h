#pragma once

#include <JuceHeader.h>
#include "ChordGenius.h"
#include <vector>
#include <random>

/**
 * BasslineArchitect - Intelligent Bassline Generation Engine
 *
 * Professional bassline creation inspired by Captain Deep, Bassist:
 * - AI bassline generation based on chord progressions
 * - Root/fifth/octave pattern generation
 * - Groove templates (funk, rock, EDM, reggae, latin, walking bass)
 * - Rhythmic variation (straight, syncopated, swung)
 * - Slide/glide between notes
 * - Ghost notes & articulation
 * - Genre-specific patterns
 * - MIDI drag & drop export
 *
 * Used by: Producers, beat makers, composers without bass players
 */
class BasslineArchitect
{
public:
    BasslineArchitect();
    ~BasslineArchitect();

    //==============================================================================
    // Bass Note

    struct BassNote
    {
        int pitch;              // MIDI note number
        double startTime;       // Seconds
        double duration;        // Seconds
        uint8 velocity;         // 0-127
        bool isRest;            // True if rest
        bool isGhost;           // Ghost note (low velocity)
        bool hasSlide;          // Slide to next note

        BassNote() : pitch(36), startTime(0.0), duration(0.5), velocity(100),
                    isRest(false), isGhost(false), hasSlide(false) {}
    };

    //==============================================================================
    // Bassline Structure

    struct Bassline
    {
        std::vector<BassNote> notes;
        int key;                        // Root note (0-11)
        ChordGenius::Scale scale;
        std::string groove;
        double bpm;

        Bassline() : key(0), scale(ChordGenius::Scale::Major), groove("Straight"), bpm(120.0) {}
    };

    //==============================================================================
    // Groove Templates

    enum class GrooveStyle
    {
        Straight,           // Four-on-the-floor
        Syncopated,         // Off-beat accents
        Funk,               // 16th note funk patterns
        Disco,              // Four-on-the-floor with octaves
        Reggae,             // One-drop, off-beat emphasis
        DubStep,            // Half-time wobble bass
        DnB,                // Fast 2-step patterns
        House,              // 4/4 kick-based
        Techno,             // Driving 16ths
        Rock,               // Root-fifth patterns
        WalkingBass,        // Jazz walking bass
        Latin,              // Tumbao/Montuno patterns
        Motown,             // Classic R&B grooves
        SlowJam,            // Slow R&B/Soul
        Custom              // User-defined
    };

    //==============================================================================
    // Pattern Type

    enum class PatternType
    {
        RootOnly,           // Just root notes
        RootFifth,          // Root and fifth
        RootOctave,         // Root and octave
        Arpeggio,           // Full chord tones
        WalkingChromatic,   // Chromatic approach
        Pedal,              // Sustained note
        Ostinato,           // Repeated riff
        Melodic             // More melodic movement
    };

    //==============================================================================
    // Bassline Generation

    /** Generate bassline from chord progression */
    Bassline generateBassline(const ChordGenius::Progression& progression,
                             GrooveStyle groove = GrooveStyle::Straight,
                             int numBars = 4,
                             double bpm = 120.0);

    /** Generate bassline with specific pattern */
    Bassline generateBasslineWithPattern(const ChordGenius::Progression& progression,
                                        PatternType pattern,
                                        GrooveStyle groove,
                                        int numBars = 4,
                                        double bpm = 120.0);

    /** Generate walking bass (jazz style) */
    Bassline generateWalkingBass(const ChordGenius::Progression& progression,
                                 int numBars = 4,
                                 double bpm = 120.0);

    /** Generate funk bassline (16th note patterns) */
    Bassline generateFunkBass(const ChordGenius::Progression& progression,
                              int numBars = 4,
                              double bpm = 120.0);

    /** Generate EDM bassline (house/techno/dubstep) */
    Bassline generateEDMBass(const ChordGenius::Progression& progression,
                             const std::string& edmStyle,
                             int numBars = 4,
                             double bpm = 120.0);

    //==============================================================================
    // Bassline Transformation

    /** Transpose bassline */
    Bassline transposeBassline(const Bassline& bassline, int semitones);

    /** Add slides between notes */
    void addSlides(Bassline& bassline, float probability = 0.2f);

    /** Add ghost notes */
    void addGhostNotes(Bassline& bassline, float probability = 0.15f);

    /** Apply swing feel */
    void applySwing(Bassline& bassline, float swingAmount = 0.5f);

    /** Humanize timing & velocity */
    void humanizeBassline(Bassline& bassline, float amount = 0.5f);

    //==============================================================================
    // MIDI Export

    /** Convert bassline to MIDI buffer */
    void basslineToMidiBuffer(const Bassline& bassline, juce::MidiBuffer& buffer);

    /** Export bassline as MIDI file */
    bool exportBasslineToMidi(const Bassline& bassline, const juce::File& outputFile);

    //==============================================================================
    // Parameters

    /** Set octave range (1-4, default 2) */
    void setOctaveRange(int octave);

    /** Set note density (0-1) */
    void setNoteDensity(float density);

    /** Set rest probability (0-1) */
    void setRestProbability(float probability);

private:
    //==============================================================================
    // Generation Helpers

    /** Get groove rhythm pattern */
    std::vector<double> getGrooveRhythm(GrooveStyle groove, double bpm);

    /** Get bass notes for chord (root, fifth, etc.) */
    std::vector<int> getBassNotesForChord(const ChordGenius::Chord& chord, PatternType pattern);

    /** Generate bass note based on groove & pattern */
    BassNote generateBassNote(const ChordGenius::Chord& currentChord,
                             PatternType pattern,
                             double startTime,
                             double duration,
                             const BassNote* previousNote);

    /** Get chromatic approach note */
    int getChromaticApproach(int targetNote, bool fromBelow);

    /** Apply groove articulation */
    void applyGrooveArticulation(Bassline& bassline, GrooveStyle groove);

    //==============================================================================
    // Parameters
    int bassOctave = 2;             // Default octave (E1 = 40)
    float noteDensity = 0.7f;
    float restProbability = 0.1f;

    // Random generator
    std::mt19937 randomEngine;
    std::uniform_real_distribution<float> uniformDist;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (BasslineArchitect)
};
