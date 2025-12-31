#pragma once

#include <JuceHeader.h>
#include <vector>
#include <array>
#include <random>

/**
 * JunglePatternGenerator - Authentic Jungle/DnB Drum Pattern Generator
 *
 * Generates authentic jungle and drum & bass breakbeat patterns using
 * classic programming techniques and genre-specific rhythm rules.
 *
 * Features:
 * - Classic jungle patterns (Amen, Think-based)
 * - DnB two-step and half-time patterns
 * - Ragga jungle patterns
 * - Liquid DnB grooves
 * - Neurofunk patterns
 * - Ghost note generation
 * - Fill generation
 * - Variation and humanization
 * - Time signature support (4/4, 6/8)
 *
 * Inspired by: classic jungle producers (Goldie, LTJ Bukem, Shy FX)
 */
class JunglePatternGenerator
{
public:
    //==========================================================================
    // Pattern Style
    //==========================================================================

    enum class Style
    {
        ClassicJungle,     // 1993-1996 jungle style (Amen-based)
        Ragga,             // Ragga jungle (reggae influenced)
        Darkside,          // Dark jungle / darkcore
        Liquid,            // Liquid DnB (smooth, rolling)
        Neurofunk,         // Technical, aggressive patterns
        TwoStep,           // Classic DnB two-step
        HalfTime,          // Half-time DnB
        Breakcore,         // Chaotic, fast patterns
        Atmospheric,       // Ambient jungle
        Jump,              // Jump-up DnB
        Rollers            // Rolling DnB patterns
    };

    //==========================================================================
    // Drum Element
    //==========================================================================

    enum class DrumElement
    {
        Kick,
        Snare,
        HiHatClosed,
        HiHatOpen,
        Ghost,             // Ghost snare
        Ride,
        Crash,
        TomHigh,
        TomMid,
        TomLow,
        Percussion,
        Shaker,
        NumElements
    };

    //==========================================================================
    // Pattern Step
    //==========================================================================

    struct Step
    {
        std::array<bool, static_cast<int>(DrumElement::NumElements)> hits;
        std::array<float, static_cast<int>(DrumElement::NumElements)> velocities;
        std::array<float, static_cast<int>(DrumElement::NumElements)> timingOffset; // -1.0 to +1.0
        bool accent = false;
        bool fill = false;

        Step() {
            hits.fill(false);
            velocities.fill(0.8f);
            timingOffset.fill(0.0f);
        }
    };

    //==========================================================================
    // Pattern
    //==========================================================================

    struct Pattern
    {
        std::vector<Step> steps;
        int stepsPerBar = 16;
        int numBars = 1;
        Style style = Style::ClassicJungle;
        juce::String name;

        int totalSteps() const { return stepsPerBar * numBars; }
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    JunglePatternGenerator();
    ~JunglePatternGenerator() = default;

    //==========================================================================
    // Pattern Generation
    //==========================================================================

    /** Generate new pattern */
    Pattern generate(Style style, int bars = 1);

    /** Generate fill pattern (for transitions) */
    Pattern generateFill(Style style, int steps = 4);

    /** Generate intro pattern (sparse) */
    Pattern generateIntro(Style style, int bars = 2);

    /** Generate breakdown pattern */
    Pattern generateBreakdown(Style style, int bars = 4);

    /** Generate buildup pattern */
    Pattern generateBuildup(Style style, int bars = 2);

    //==========================================================================
    // Pattern Parameters
    //==========================================================================

    /** Set pattern density (0.0 sparse to 1.0 busy) */
    void setDensity(float density);

    /** Set ghost note amount (0.0 to 1.0) */
    void setGhostAmount(float amount);

    /** Set hi-hat activity (0.0 to 1.0) */
    void setHiHatActivity(float activity);

    /** Set kick complexity (0.0 simple to 1.0 complex) */
    void setKickComplexity(float complexity);

    /** Set snare variation (0.0 to 1.0) */
    void setSnareVariation(float variation);

    /** Set swing amount (0.0 to 1.0) */
    void setSwing(float swing);

    /** Set humanization (timing randomness) */
    void setHumanize(float amount);

    /** Set fill probability (0.0 to 1.0) */
    void setFillProbability(float probability);

    //==========================================================================
    // Amen-Specific Controls
    //==========================================================================

    /** Set Amen chop style */
    enum class AmenChopStyle
    {
        Original,          // Original Amen pattern
        Chopped,          // Classic chop pattern
        Reversed,         // Reversed sections
        Timestretched,    // Stretched feel
        Rearranged        // Heavily rearranged
    };

    void setAmenChopStyle(AmenChopStyle style);

    //==========================================================================
    // Pattern Manipulation
    //==========================================================================

    /** Create variation of pattern */
    Pattern createVariation(const Pattern& source, float variationAmount);

    /** Merge two patterns */
    Pattern mergePatterns(const Pattern& a, const Pattern& b, float mixRatio = 0.5f);

    /** Apply fill to pattern */
    void applyFill(Pattern& pattern, int startStep, const Pattern& fill);

    /** Double-time pattern */
    Pattern doubleTime(const Pattern& source);

    /** Half-time pattern */
    Pattern halfTime(const Pattern& source);

    //==========================================================================
    // MIDI Export
    //==========================================================================

    /** Convert pattern to MIDI */
    juce::MidiMessageSequence patternToMidi(const Pattern& pattern,
                                            float bpm,
                                            int baseNote = 36);

    /** Get default drum map */
    struct DrumMap
    {
        std::array<int, static_cast<int>(DrumElement::NumElements)> midiNotes;
        DrumMap() {
            midiNotes[static_cast<int>(DrumElement::Kick)] = 36;
            midiNotes[static_cast<int>(DrumElement::Snare)] = 38;
            midiNotes[static_cast<int>(DrumElement::HiHatClosed)] = 42;
            midiNotes[static_cast<int>(DrumElement::HiHatOpen)] = 46;
            midiNotes[static_cast<int>(DrumElement::Ghost)] = 37;
            midiNotes[static_cast<int>(DrumElement::Ride)] = 51;
            midiNotes[static_cast<int>(DrumElement::Crash)] = 49;
            midiNotes[static_cast<int>(DrumElement::TomHigh)] = 50;
            midiNotes[static_cast<int>(DrumElement::TomMid)] = 47;
            midiNotes[static_cast<int>(DrumElement::TomLow)] = 45;
            midiNotes[static_cast<int>(DrumElement::Percussion)] = 39;
            midiNotes[static_cast<int>(DrumElement::Shaker)] = 70;
        }
    };

    void setDrumMap(const DrumMap& map);
    const DrumMap& getDrumMap() const { return drumMap; }

    //==========================================================================
    // Presets
    //==========================================================================

    enum class Preset
    {
        AmenClassic,       // Original Amen pattern
        AmenChopped,       // Classic jungle chops
        ThinkBased,        // Think break style
        TwoStepClassic,    // Standard two-step
        RollingLiquid,     // Smooth rolling pattern
        NeuroAggressive,   // Intense neurofunk
        HalfTimeMinimal,   // Minimal half-time
        RaggaRiddim,       // Ragga jungle
        BreakcoreChaos,    // Chaotic patterns
        AtmosphericSparse  // Sparse ambient
    };

    void loadPreset(Preset preset);

private:
    //==========================================================================
    // Parameters
    //==========================================================================

    float density = 0.6f;
    float ghostAmount = 0.4f;
    float hiHatActivity = 0.7f;
    float kickComplexity = 0.5f;
    float snareVariation = 0.3f;
    float swing = 0.0f;
    float humanize = 0.1f;
    float fillProbability = 0.1f;

    AmenChopStyle amenChopStyle = AmenChopStyle::Chopped;
    DrumMap drumMap;

    // Random generator
    std::mt19937 rng;

    //==========================================================================
    // Internal Pattern Templates
    //==========================================================================

    void generateClassicJungle(Pattern& pattern);
    void generateRagga(Pattern& pattern);
    void generateDarkside(Pattern& pattern);
    void generateLiquid(Pattern& pattern);
    void generateNeurofunk(Pattern& pattern);
    void generateTwoStep(Pattern& pattern);
    void generateHalfTime(Pattern& pattern);
    void generateBreakcore(Pattern& pattern);
    void generateAtmospheric(Pattern& pattern);
    void generateJump(Pattern& pattern);
    void generateRollers(Pattern& pattern);

    void addGhostNotes(Pattern& pattern);
    void applySwing(Pattern& pattern);
    void applyHumanization(Pattern& pattern);

    bool shouldPlay(float probability);
    float randomVelocity(float base, float variation);
    float randomTiming(float amount);

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(JunglePatternGenerator)
};
