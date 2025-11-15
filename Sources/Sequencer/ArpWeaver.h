#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>
#include <memory>

/**
 * ArpWeaver
 *
 * Intelligent arpeggiator with scale and music style awareness.
 * Inspired by Ableton Note Echo, Cthulhu, Instachord, but evolved
 * with AI-powered pattern generation and bio-reactive control.
 *
 * Features:
 * - Scale-aware arpeggiation (40+ scales)
 * - Music style patterns (House, Trance, Hip-Hop, etc.)
 * - Intelligent note selection (tension/resolution)
 * - Chord detection and progression
 * - Octave range (1-4 octaves)
 * - Multiple arp modes (Up, Down, UpDown, Random, As Played, etc.)
 * - Rhythm patterns (16-step with swing)
 * - Velocity patterns
 * - Gate length control
 * - Latch mode
 * - Bio-reactive pattern morphing
 */
class ArpWeaver
{
public:
    //==========================================================================
    // Scale System
    //==========================================================================

    enum class Scale
    {
        Chromatic,
        Major, Minor, HarmonicMinor, MelodicMinor,
        Dorian, Phrygian, Lydian, Mixolydian, Aeolian, Locrian,
        MajorPentatonic, MinorPentatonic,
        Blues, JapaneseInsen, HirajoshiJapanese,
        WholeTone, Diminished, Augmented,
        Spanish, Gypsy, Arabic, Persian,
        // Add more scales...
        NumScales
    };

    //==========================================================================
    // Arp Mode
    //==========================================================================

    enum class ArpMode
    {
        Up,              // Ascending
        Down,            // Descending
        UpDown,          // Up then down (bounce)
        DownUp,          // Down then up
        UpAndDown,       // Up then down (repeat top/bottom)
        AsPlayed,        // Order notes were played
        Random,          // Random note selection
        Chord,           // Play all notes as chord
        Intelligent,     // AI-powered intelligent selection
        TensionRelease   // Build tension then resolve
    };

    //==========================================================================
    // Music Style
    //==========================================================================

    enum class MusicStyle
    {
        None,            // No style influence
        House,           // House music patterns
        Trance,          // Trance arpeggios
        HipHop,          // Hip-hop syncopation
        DnB,             // Drum & Bass
        Techno,          // Techno sequences
        Ambient,         // Ambient textures
        Jazz,            // Jazz improvisation
        Classical        // Classical arpeggios
    };

    //==========================================================================
    // Pattern Configuration
    //==========================================================================

    struct RhythmPattern
    {
        std::array<bool, 16> steps;       // 16-step pattern
        std::array<float, 16> velocities; // Per-step velocity (0.0-1.0)
        std::array<float, 16> gateLengths; // Per-step gate (0.0-1.0)

        RhythmPattern()
        {
            steps.fill(true);
            velocities.fill(1.0f);
            gateLengths.fill(0.8f);
        }
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    ArpWeaver();
    ~ArpWeaver() = default;

    //==========================================================================
    // Mode & Scale
    //==========================================================================

    void setArpMode(ArpMode mode);
    ArpMode getArpMode() const { return arpMode; }

    void setScale(Scale scale);
    Scale getScale() const { return currentScale; }

    void setRootNote(int rootMIDI);  // 0-11 (C-B)
    int getRootNote() const { return rootNote; }

    void setMusicStyle(MusicStyle style);
    MusicStyle getMusicStyle() const { return musicStyle; }

    //==========================================================================
    // Range & Pattern
    //==========================================================================

    void setOctaveRange(int octaves);  // 1-4
    int getOctaveRange() const { return octaveRange; }

    void setRate(float rate);          // Note division (1/4, 1/8, 1/16, etc.)
    float getRate() const { return arpRate; }

    void setSwing(float swing);        // 0.0 (straight) to 1.0 (full swing)
    float getSwing() const { return arpSwing; }

    void setGateLength(float gate);    // 0.0 to 1.0
    float getGateLength() const { return gateLength; }

    //==========================================================================
    // Rhythm Pattern
    //==========================================================================

    void setRhythmPattern(const RhythmPattern& pattern);
    const RhythmPattern& getRhythmPattern() const { return rhythmPattern; }

    void generateRhythmPattern(MusicStyle style);  // Auto-generate pattern

    //==========================================================================
    // Latch & Hold
    //==========================================================================

    void setLatchEnabled(bool enabled);
    bool isLatchEnabled() const { return latchEnabled; }

    void clearLatch();

    //==========================================================================
    // Bio-Reactive Control
    //==========================================================================

    void setBioData(float hrv, float coherence);
    void setBioReactiveEnabled(bool enabled);

    //==========================================================================
    // MIDI Input/Output
    //==========================================================================

    /** Process incoming MIDI note (call from MIDI input) */
    void processNoteOn(int midiNote, float velocity);
    void processNoteOff(int midiNote);

    /** Get arpeggiated notes for current position */
    struct ArpNote
    {
        int midiNote = 0;
        float velocity = 1.0f;
        float gateLength = 0.8f;
        bool noteOn = false;
    };

    std::vector<ArpNote> getArpNotes(double sampleRate, int numSamples,
                                     double& currentPhase, double tempo);

    //==========================================================================
    // Chord Detection
    //==========================================================================

    /** Get detected chord from held notes */
    juce::String getDetectedChord() const;

    /** Get chord progression suggestion */
    std::vector<juce::String> suggestProgression() const;

    //==========================================================================
    // Reset
    //==========================================================================

    void reset();

private:
    //==========================================================================
    // Scale Data
    //==========================================================================

    struct ScaleData
    {
        Scale type;
        juce::String name;
        std::vector<int> intervals;  // Semitone intervals from root

        ScaleData() = default;
        ScaleData(Scale t, const juce::String& n, const std::vector<int>& i)
            : type(t), name(n), intervals(i) {}
    };

    std::array<ScaleData, static_cast<size_t>(Scale::NumScales)> scales;

    //==========================================================================
    // Parameters
    //==========================================================================

    ArpMode arpMode = ArpMode::Up;
    Scale currentScale = Scale::Major;
    int rootNote = 0;  // C
    MusicStyle musicStyle = MusicStyle::None;

    int octaveRange = 1;
    float arpRate = 0.125f;  // 1/8 note
    float arpSwing = 0.0f;
    float gateLength = 0.8f;

    RhythmPattern rhythmPattern;
    bool latchEnabled = false;

    // Bio-reactive
    float bioHRV = 0.5f;
    float bioCoherence = 0.5f;
    bool bioReactiveEnabled = false;

    //==========================================================================
    // State
    //==========================================================================

    std::vector<int> heldNotes;      // Currently held MIDI notes
    std::vector<int> latchedNotes;   // Latched notes
    std::vector<int> arpNotes;       // Arpeggiated note sequence
    int currentArpIndex = 0;
    int currentStep = 0;              // For rhythm pattern

    //==========================================================================
    // Internal Methods
    //==========================================================================

    void initializeScales();
    void updateArpSequence();
    std::vector<int> quantizeToScale(const std::vector<int>& notes);

    // Arp mode generators
    std::vector<int> generateUp(const std::vector<int>& notes);
    std::vector<int> generateDown(const std::vector<int>& notes);
    std::vector<int> generateUpDown(const std::vector<int>& notes);
    std::vector<int> generateDownUp(const std::vector<int>& notes);
    std::vector<int> generateAsPlayed(const std::vector<int>& notes);
    std::vector<int> generateRandom(const std::vector<int>& notes);
    std::vector<int> generateIntelligent(const std::vector<int>& notes);
    std::vector<int> generateTensionRelease(const std::vector<int>& notes);

    // Music style modifiers
    void applyMusicStyle(std::vector<int>& notes);

    // Chord detection
    juce::String detectChord(const std::vector<int>& notes) const;
    std::vector<int> getChordNotes(const juce::String& chordName) const;

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (ArpWeaver)
};
